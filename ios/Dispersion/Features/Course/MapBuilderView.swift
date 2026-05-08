// Course map builder. Satellite imagery + crosshair placement for tees, pins,
// and polygon tracing of fairways, greens, bunkers, water.
// Supports multiple tee boxes (color-based with rename) and front/middle/back
// pin positions per hole.

import MapKit
import SwiftData
import SwiftUI

struct MapBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeAccent) private var accent

    var courseId: String
    var course: Course
    var onDone: () -> Void

    enum BuildStep: Equatable {
        case placeTee
        case placePin
        case draw
    }

    @State private var currentHole: Int = 1
    @State private var step: BuildStep = .placeTee
    @State private var activeTool: SurfaceType = .fairway
    @State private var currentPoints: [Coord] = []
    @State private var crosshairCoord: Coord?
    @State private var position: MapCameraPosition = .automatic
    @State private var is3D = false

    // Tee/pin editing
    @State private var selectedTeeColor: String = "white"
    @State private var selectedPinZone: PinZone = .middle

    @State private var holeInfos: [Int: HoleInfo] = [:]
    @State private var holePolygons: [CoursePolygon] = []
    @State private var showScorecard = false

    private var holeInfo: HoleInfo? { holeInfos[currentHole] }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                mapContent
                crosshairOverlay
                bottomToolbar
                mapControls
            }
        }
        .background(DesignTokens.backgroundDeep.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            loadAllHoleInfos()
            loadHolePolygons()
            flyToHole()
        }
        .onChange(of: currentHole) { _, _ in
            loadHolePolygons()
            updateStep()
            flyToHole()
        }
        .dispersionSheet(isPresented: $showScorecard, detents: [.large]) {
            ScorecardEditorSheet(courseId: courseId, holeCount: course.holeCount) {
                loadAllHoleInfos()
                showScorecard = false
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 4) {
            HStack {
                Button { onDone() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark").font(.system(size: 12))
                        Text("Done")
                    }
                    .font(DispersionType.mono(12))
                    .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(course.name)
                    .font(DispersionType.ui(13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Button { showScorecard = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.number").font(.system(size: 11))
                        Text("Card")
                    }
                    .font(DispersionType.mono(12))
                    .foregroundStyle(DesignTokens.mutedForeground)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                Text("Hole \(currentHole)")
                    .font(DispersionType.display(22, weight: .regular))
                if let info = holeInfo, info.par > 0 {
                    Text("Par \(info.par)")
                        .font(DispersionType.mono(12, weight: .medium))
                        .foregroundStyle(DesignTokens.mutedForeground)
                }
                Spacer()
                if currentHole > 1 {
                    Button { prevHole() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(DesignTokens.surface))
                    }
                    .buttonStyle(.plain)
                }
                if currentHole < course.holeCount {
                    Button { nextHole() } label: {
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(DesignTokens.surface))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            // Step indicator
            HStack(spacing: 12) {
                stepPill("Tees", active: step == .placeTee, done: !(holeInfo?.teeBoxes.isEmpty ?? true))
                stepPill("Pins", active: step == .placePin, done: holeInfo?.defaultPinCoord != nil)
                stepPill("Draw", active: step == .draw, done: !holePolygons.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .padding(.top, 4)
        .background(DesignTokens.background)
    }

    private func stepPill(_ label: String, active: Bool, done: Bool) -> some View {
        HStack(spacing: 4) {
            if done && !active {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(DesignTokens.primary)
            }
            Text(label)
                .font(DispersionType.mono(10, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(active ? accent : DesignTokens.surface))
        .foregroundStyle(active ? DesignTokens.primaryForeground : DesignTokens.foreground)
        .onTapGesture {
            switch label {
            case "Tees": step = .placeTee
            case "Pins": step = .placePin
            default: step = .draw
            }
            Haptics.light()
        }
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $position) {
            // Completed polygons for this hole
            ForEach(holePolygons, id: \.id) { polygon in
                if polygon.coordinates.count >= 3 {
                    MapPolygon(coordinates: polygon.coordinates.map {
                        CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                    })
                    .foregroundStyle(fillColor(polygon.surface).opacity(0.45))
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                }
            }

            // In-progress polygon preview
            if currentPoints.count >= 2 {
                MapPolyline(coordinates: closedPreviewCoords)
                    .stroke(fillColor(activeTool), lineWidth: 2)
            }

            // In-progress points
            ForEach(currentPoints.indices, id: \.self) { i in
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: currentPoints[i].lat, longitude: currentPoints[i].lng
                )) {
                    Circle().fill(.white).frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(fillColor(activeTool), lineWidth: 2))
                }
            }

            // Tee box markers
            if let info = holeInfo {
                ForEach(info.teeBoxes) { tee in
                    if let coord = tee.coord {
                        Annotation(tee.name, coordinate: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng)) {
                            ZStack {
                                Circle().fill(.white).frame(width: 20, height: 20)
                                Circle().fill(teeDisplayColor(tee.color)).frame(width: 14, height: 14)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                    }
                }

                // Pin markers
                ForEach(info.pinPositions.filter { $0.coord != nil }, id: \.zone) { pin in
                    if let coord = pin.coord {
                        Annotation(pin.zone.label, coordinate: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng)) {
                            VStack(spacing: 0) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(pinZoneColor(pin.zone))
                                Text(pin.zone.label.prefix(1).uppercased())
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                    }
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .onMapCameraChange(frequency: .continuous) { context in
            crosshairCoord = Coord(
                lat: context.camera.centerCoordinate.latitude,
                lng: context.camera.centerCoordinate.longitude
            )
        }
    }

    private var closedPreviewCoords: [CLLocationCoordinate2D] {
        var coords = currentPoints.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        if let ch = crosshairCoord {
            coords.append(CLLocationCoordinate2D(latitude: ch.lat, longitude: ch.lng))
        }
        if currentPoints.count >= 3 {
            coords.append(coords[0])
        }
        return coords
    }

    private var crosshairOverlay: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.6)).frame(width: 24, height: 1)
            Rectangle().fill(Color.white.opacity(0.6)).frame(width: 1, height: 24)
            Circle().fill(stepColor).frame(width: 6, height: 6)
            Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1).frame(width: 20, height: 20)
        }
        .allowsHitTesting(false)
    }

    private var stepColor: Color {
        switch step {
        case .placeTee: return teeDisplayColor(selectedTeeColor)
        case .placePin: return pinZoneColor(selectedPinZone)
        case .draw: return fillColor(activeTool)
        }
    }

    // MARK: - Map controls (3D toggle)

    private var mapControls: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    is3D.toggle()
                    if is3D { flyToHole3D() } else { flyToHoleOverhead() }
                    Haptics.light()
                } label: {
                    Image(systemName: is3D ? "view.2d" : "view.3d").font(.system(size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 12)
            .padding(.bottom, 180)
        }
    }

    // MARK: - Bottom toolbar

    private var bottomToolbar: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                switch step {
                case .placeTee: teeToolbar
                case .placePin: pinToolbar
                case .draw: drawToolbar
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: Tee toolbar

    private var teeToolbar: some View {
        VStack(spacing: 8) {
            // Tee color selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TeeBox.defaultColors, id: \.color) { item in
                        let existing = holeInfo?.teeBoxes.first { $0.color == item.color }
                        Button {
                            selectedTeeColor = item.color
                            Haptics.light()
                        } label: {
                            HStack(spacing: 4) {
                                Circle().fill(teeDisplayColor(item.color)).frame(width: 8, height: 8)
                                    .overlay(Circle().strokeBorder(item.color == "white" ? Color.gray.opacity(0.4) : .clear, lineWidth: 0.5))
                                Text(item.name).font(DispersionType.mono(10, weight: .medium))
                                if existing?.coord != nil {
                                    Image(systemName: "checkmark").font(.system(size: 8))
                                        .foregroundStyle(DesignTokens.primary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(selectedTeeColor == item.color
                                    ? teeDisplayColor(item.color).opacity(0.25) : DesignTokens.surface)
                            )
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                guard let coord = crosshairCoord else { return }
                placeTee(color: selectedTeeColor, coord: coord)
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(teeDisplayColor(selectedTeeColor)).frame(width: 8, height: 8)
                    Text("Set \(teeColorName(selectedTeeColor)) Tee")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.primary))

            if holeInfo?.teeBoxes.contains(where: { $0.coord != nil }) == true {
                Button {
                    step = .placePin
                    Haptics.light()
                } label: {
                    Text("Next: Place Pins →").frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.ghost))
            }
        }
    }

    // MARK: Pin toolbar

    private var pinToolbar: some View {
        VStack(spacing: 8) {
            // Pin zone selector
            HStack(spacing: 6) {
                ForEach(PinZone.allCases, id: \.self) { zone in
                    let hasCoord = holeInfo?.pin(zone) != nil
                    Button {
                        selectedPinZone = zone
                        Haptics.light()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill").font(.system(size: 9))
                                .foregroundStyle(pinZoneColor(zone))
                            Text(zone.label).font(DispersionType.mono(10, weight: .medium))
                            if hasCoord {
                                Image(systemName: "checkmark").font(.system(size: 8))
                                    .foregroundStyle(DesignTokens.primary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule().fill(selectedPinZone == zone
                                ? pinZoneColor(zone).opacity(0.25) : DesignTokens.surface)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                guard let coord = crosshairCoord else { return }
                placePin(zone: selectedPinZone, coord: coord)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill").font(.system(size: 12))
                        .foregroundStyle(pinZoneColor(selectedPinZone))
                    Text("Set \(selectedPinZone.label) Pin")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dispersion(.primary))

            if holeInfo?.defaultPinCoord != nil {
                Button {
                    step = .draw
                    Haptics.light()
                } label: {
                    Text("Next: Draw Surfaces →").frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.ghost))
            }
        }
    }

    // MARK: Draw toolbar

    private var drawToolbar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach([SurfaceType.fairway, .green, .bunker, .water, .rough, .tee], id: \.self) { surface in
                        Button {
                            activeTool = surface
                            currentPoints = []
                            Haptics.light()
                        } label: {
                            HStack(spacing: 4) {
                                Circle().fill(fillColor(surface)).frame(width: 8, height: 8)
                                Text(surface.rawValue.capitalized)
                                    .font(DispersionType.mono(10, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(activeTool == surface ? fillColor(surface).opacity(0.25) : DesignTokens.surface)
                            )
                            .foregroundStyle(activeTool == surface ? .white : DesignTokens.foreground)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    guard let coord = crosshairCoord else { return }
                    currentPoints.append(coord)
                    Haptics.light()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 12))
                        Text("Point")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.solid))

                if !currentPoints.isEmpty {
                    Button {
                        currentPoints.removeLast()
                        Haptics.light()
                    } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 13))
                    }
                    .buttonStyle(.dispersion(.ghost, size: .icon))
                }

                if currentPoints.count >= 3 {
                    Button { closePolygon() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark").font(.system(size: 12))
                            Text("Close")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.dispersion(.primary))
                }
            }

            HStack(spacing: 8) {
                if !holePolygons.isEmpty {
                    Button { deleteLastPolygon() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 11))
                            Text("Delete last")
                        }
                    }
                    .buttonStyle(.dispersion(.ghost, size: .sm))
                }
                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func ensureHoleInfo() -> HoleInfo {
        if let existing = holeInfos[currentHole] { return existing }
        let info = HoleInfo(courseId: courseId, holeNumber: currentHole)
        holeInfos[currentHole] = info
        try? CoursesRepo(context: modelContext).upsertHoleInfo(info)
        return info
    }

    private func placeTee(color: String, coord: Coord) {
        var info = ensureHoleInfo()
        let name = teeColorName(color)
        if let i = info.teeBoxes.firstIndex(where: { $0.color == color }) {
            info.teeBoxes[i].coord = coord
        } else {
            info.teeBoxes.append(TeeBox(name: name, color: color, coord: coord))
        }
        holeInfos[currentHole] = info
        try? CoursesRepo(context: modelContext).upsertHoleInfo(info)
        Haptics.success()
    }

    private func placePin(zone: PinZone, coord: Coord) {
        var info = ensureHoleInfo()
        if let i = info.pinPositions.firstIndex(where: { $0.zone == zone }) {
            info.pinPositions[i].coord = coord
        } else {
            info.pinPositions.append(HolePinPosition(zone: zone, coord: coord))
        }
        holeInfos[currentHole] = info
        try? CoursesRepo(context: modelContext).upsertHoleInfo(info)
        Haptics.success()
    }

    private func closePolygon() {
        guard currentPoints.count >= 3 else { return }
        let polygon = CoursePolygon(
            id: UUID().uuidString.lowercased(),
            courseId: courseId,
            holeNumber: currentHole,
            surface: activeTool,
            coordinates: currentPoints
        )
        do {
            try CoursesRepo(context: modelContext).insertPolygons([polygon])
            holePolygons.append(polygon)
            currentPoints = []
            Haptics.medium()
        } catch {
            Haptics.error()
        }
    }

    private func deleteLastPolygon() {
        guard let last = holePolygons.last else { return }
        try? CoursesRepo(context: modelContext).deletePolygon(id: last.id)
        holePolygons.removeLast()
        Haptics.medium()
    }

    private func nextHole() {
        currentPoints = []
        currentHole += 1
        Haptics.light()
    }

    private func prevHole() {
        currentPoints = []
        currentHole -= 1
        Haptics.light()
    }

    private func updateStep() {
        guard let info = holeInfos[currentHole] else {
            step = .placeTee
            return
        }
        if info.teeBoxes.allSatisfy({ $0.coord == nil }) { step = .placeTee }
        else if info.defaultPinCoord == nil { step = .placePin }
        else { step = .draw }
    }

    // MARK: - Data

    private func loadAllHoleInfos() {
        let infos = (try? CoursesRepo(context: modelContext).holeInfos(courseId: courseId)) ?? []
        holeInfos = Dictionary(uniqueKeysWithValues: infos.map { ($0.holeNumber, $0) })
        updateStep()
    }

    private func loadHolePolygons() {
        let all = (try? CoursesRepo(context: modelContext).polygons(courseId: courseId, hole: currentHole)) ?? []
        holePolygons = all.filter { $0.holeNumber == currentHole }
    }

    // MARK: - Camera

    private func flyToHole() {
        if is3D { flyToHole3D() } else { flyToHoleOverhead() }
    }

    private func flyToHoleOverhead() {
        let target: CLLocationCoordinate2D
        if let tee = holeInfos[currentHole]?.firstTeeCoord {
            target = CLLocationCoordinate2D(latitude: tee.lat, longitude: tee.lng)
        } else if let pin = holeInfos[currentHole]?.defaultPinCoord {
            target = CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lng)
        } else {
            target = CLLocationCoordinate2D(latitude: course.centerLat, longitude: course.centerLng)
        }
        withAnimation(.easeInOut(duration: 0.5)) {
            position = .camera(MapCamera(centerCoordinate: target, distance: 500, heading: 0, pitch: 0))
        }
    }

    private func flyToHole3D() {
        if let tee = holeInfos[currentHole]?.firstTeeCoord,
           let pin = holeInfos[currentHole]?.defaultPinCoord {
            let mid = Coord(lat: (tee.lat + pin.lat) / 2, lng: (tee.lng + pin.lng) / 2)
            let dist = haversineYards(from: tee, to: pin)
            let bearing = bearingDeg(from: tee, to: pin)
            withAnimation(.easeInOut(duration: 0.6)) {
                position = .camera(MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: mid.lat, longitude: mid.lng),
                    distance: max(250, dist * 1.0),
                    heading: bearing,
                    pitch: 50
                ))
            }
        } else {
            flyToHoleOverhead()
        }
    }

    private func bearingDeg(from a: Coord, to b: Coord) -> Double {
        let lat1 = a.lat * .pi / 180
        let lat2 = b.lat * .pi / 180
        let dLng = (b.lng - a.lng) * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Colors

    private func fillColor(_ surface: SurfaceType) -> Color {
        switch surface {
        case .green:   return hex("#A8C97F")
        case .fairway: return hex("#C4D49A")
        case .bunker:  return hex("#E8DCC0")
        case .water:   return hex("#7EA5C4")
        case .tee:     return hex("#B8C880")
        case .rough:   return hex("#8FA66B")
        }
    }

    private func teeDisplayColor(_ color: String) -> Color {
        switch color {
        case "blue": return .blue
        case "white": return .white
        case "red": return .red
        case "gold": return .yellow
        case "black": return .primary
        default: return .gray
        }
    }

    private func teeColorName(_ color: String) -> String {
        TeeBox.defaultColors.first { $0.color == color }?.name ?? color.capitalized
    }

    private func pinZoneColor(_ zone: PinZone) -> Color {
        switch zone {
        case .front: return .yellow
        case .middle: return accent
        case .back: return .red
        }
    }
}
