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
    @State private var previewCoord: Coord?
    @State private var position: MapCameraPosition = .automatic
    @State private var is3D = false
    @State private var quickEdit = true   // auto-fill mode vs manual draw
    @State private var filling = false
    @State private var fillError: String?
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var fillTolerance: Double = 5
    @State private var traceCoords: [Coord]?
    @State private var traceProgress: CGFloat = 0
    @State private var traceSurface: SurfaceType = .fairway
    @State private var selectedPolygonId: String?
    @State private var selectedVertexIndex: Int?
    @State private var editUndoStack: [[Coord]] = []  // previous states of the polygon being edited

    // Tee/pin editing
    @State private var selectedTeeColor: String = "white"
    @State private var selectedPinZone: PinZone = .middle

    @State private var holeInfos: [Int: HoleInfo] = [:]
    @State private var holePolygons: [CoursePolygon] = []
    @State private var showScorecard = false
    @State private var showHolePicker = false

    private var holeInfo: HoleInfo? { holeInfos[currentHole] }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack {
                mapContent
                traceOverlay
                crosshairOverlay
                bottomToolbar
                mapControls
            }
        }
        .background(DesignTokens.backgroundDeep.ignoresSafeArea())
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
        .dispersionSheet(isPresented: $showHolePicker, detents: [.medium]) {
            builderHolePicker
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
                Button { showHolePicker = true; Haptics.light() } label: {
                    HStack(spacing: 4) {
                        Text("Hole \(currentHole)")
                            .font(DispersionType.display(22, weight: .regular))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(DesignTokens.mutedForeground)
                    }
                }
                .buttonStyle(.plain)
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
            Text(active ? label : (done ? "✎ \(label)" : label))
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

    private var sortedHolePolygons: [CoursePolygon] {
        holePolygons
            .filter { $0.coordinates.count >= 3 }
            .sorted { $0.surface.zOrder < $1.surface.zOrder }
    }

    private var mapContent: some View {
        MapReader { proxy in
        Map(position: $position) {
            // Completed polygons — z-ordered
            ForEach(sortedHolePolygons, id: \.id) { polygon in
                let isSelected = selectedPolygonId == polygon.id
                MapPolygon(coordinates: polygon.coordinates.map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                })
                .foregroundStyle(fillColor(polygon.surface).opacity(polygon.surface.zOrder >= 2 ? 0.7 : 0.4))
                .stroke(isSelected ? Color.white : Color.white.opacity(0.6),
                        lineWidth: isSelected ? 2.5 : 1)

            }

            // Vertex handles for selected polygon
            if let selId = selectedPolygonId,
               let selPoly = holePolygons.first(where: { $0.id == selId }) {
                // Show every Nth vertex to avoid Metal crash with many annotations
                let coords = selPoly.coordinates
                let step = max(1, coords.count / 40)
                ForEach(Array(stride(from: 0, to: coords.count, by: step)), id: \.self) { i in
                    let coord = coords[i]
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng)) {
                        let isActive = selectedVertexIndex == i
                        Circle()
                            .fill(isActive ? Color.white : fillColor(selPoly.surface))
                            .frame(width: isActive ? 18 : 10, height: isActive ? 18 : 10)
                            .overlay {
                                if isActive {
                                    Circle().strokeBorder(fillColor(selPoly.surface), lineWidth: 2.5)
                                        .frame(width: 18, height: 18)
                                }
                            }
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                            .onTapGesture {
                                selectedVertexIndex = (selectedVertexIndex == i) ? nil : i
                                Haptics.medium()
                            }
                    }
                }
            }

            // In-progress polygon preview — filled with dashed outline
            if currentPoints.count >= 2, let preview = previewPolygonCoords {
                MapPolygon(coordinates: preview)
                    .foregroundStyle(fillColor(activeTool).opacity(0.2))
                    .stroke(fillColor(activeTool), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            } else if currentPoints.count == 1, let pc = previewCoord {
                // Single line from first point to crosshair
                MapPolyline(coordinates: [
                    CLLocationCoordinate2D(latitude: currentPoints[0].lat, longitude: currentPoints[0].lng),
                    CLLocationCoordinate2D(latitude: pc.lat, longitude: pc.lng)
                ])
                .stroke(fillColor(activeTool).opacity(0.6), lineWidth: 1.5)
            }

            // Vertex markers with numbers
            ForEach(currentPoints.indices, id: \.self) { i in
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: currentPoints[i].lat, longitude: currentPoints[i].lng
                )) {
                    ZStack {
                        Circle().fill(fillColor(activeTool)).frame(width: 14, height: 14)
                        Text("\(i + 1)")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
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
        .mapStyle(step == .draw && quickEdit
            ? .standard(elevation: .realistic, pointsOfInterest: .excludingAll)
            : .imagery(elevation: .realistic))
        .mapControls { MapCompass() }
        .onMapCameraChange(frequency: .continuous) { context in
            let coord = Coord(
                lat: context.camera.centerCoordinate.latitude,
                lng: context.camera.centerCoordinate.longitude
            )
            crosshairCoord = coord
            visibleRegion = context.region
            if step == .draw, !currentPoints.isEmpty {
                previewCoord = coord
            }
        }
        .onLongPressGesture(minimumDuration: 0.4, pressing: { pressing in
            if pressing && step == .draw {
                Haptics.light()  // feedback that press is recognized
            }
        }) {
            guard step == .draw else { return }
            selectPolygonAtCrosshair()
        }
        } // MapReader
    }

    private var previewPolygonCoords: [CLLocationCoordinate2D]? {
        guard currentPoints.count >= 2 else { return nil }
        var coords = currentPoints.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        if let pc = previewCoord {
            coords.append(CLLocationCoordinate2D(latitude: pc.lat, longitude: pc.lng))
        }
        coords.append(coords[0])
        return coords
    }

    // MARK: - Trace animation

    private var traceOverlay: some View {
        GeometryReader { geo in
            if let coords = traceCoords, let region = visibleRegion, coords.count >= 3 {
                let screenPts = coords.map { coord -> CGPoint in
                    let fracX = (coord.lng - (region.center.longitude - region.span.longitudeDelta / 2))
                        / region.span.longitudeDelta
                    let fracY = 1.0 - (coord.lat - (region.center.latitude - region.span.latitudeDelta / 2))
                        / region.span.latitudeDelta
                    return CGPoint(x: fracX * geo.size.width, y: fracY * geo.size.height)
                }
                let color = fillColor(traceSurface)

                // Glowing fill that fades in
                Path { path in
                    path.move(to: screenPts[0])
                    for pt in screenPts.dropFirst() { path.addLine(to: pt) }
                    path.closeSubpath()
                }
                .fill(color.opacity(0.3 * traceProgress))

                // Tracing stroke
                Path { path in
                    path.move(to: screenPts[0])
                    for pt in screenPts.dropFirst() { path.addLine(to: pt) }
                    path.closeSubpath()
                }
                .trim(from: 0, to: traceProgress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .shadow(color: color, radius: 8)
                .shadow(color: color, radius: 4)
            }
        }
        .allowsHitTesting(false)
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

    // MARK: - Map controls (top overlay)

    private var mapControls: some View {
        VStack {
            HStack(spacing: 8) {
                if step == .draw {
                    Button {
                        quickEdit.toggle()
                        currentPoints = []
                        Haptics.light()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: quickEdit ? "wand.and.stars" : "pencil.tip")
                                .font(.system(size: 11))
                            Text(quickEdit ? "Auto" : "Manual")
                                .font(DispersionType.mono(10, weight: .medium))
                        }
                        .foregroundStyle(quickEdit ? accent : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(DesignTokens.popover).environment(\.colorScheme, .dark))
                    }
                    .buttonStyle(.plain)
                }

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
                        .background(Capsule().fill(DesignTokens.popover).environment(\.colorScheme, .dark))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()
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
                    .fill(DesignTokens.popover)
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
                    let hasTee = holeInfo?.teeBoxes.first(where: { $0.color == selectedTeeColor })?.coord != nil
                    Text(hasTee ? "Move \(teeColorName(selectedTeeColor)) Tee" : "Set \(teeColorName(selectedTeeColor)) Tee")
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
                    let hasPin = holeInfo?.pin(selectedPinZone) != nil
                    Text(hasPin ? "Move \(selectedPinZone.label) Pin" : "Set \(selectedPinZone.label) Pin")
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
        Group {
            if selectedPolygonId != nil {
                editPolygonToolbar
            } else {
                drawNewToolbar
            }
        }
    }

    private var editPolygonToolbar: some View {
        VStack(spacing: 8) {
            // Edit mode header
            let polyName = holePolygons.first(where: { $0.id == selectedPolygonId })?.surface.rawValue.capitalized ?? "Polygon"
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "pencil").font(.system(size: 11))
                    Text("Editing \(polyName)")
                        .font(DispersionType.mono(10, weight: .medium))
                }
                Spacer()
                let vtxCount = holePolygons.first(where: { $0.id == selectedPolygonId })?.coordinates.count ?? 0
                Text("\(vtxCount) pts")
                    .font(DispersionType.mono(9))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }

            if selectedVertexIndex != nil {
                // Vertex selected — place or delete
                HStack(spacing: 8) {
                    Button {
                        guard let coord = crosshairCoord else { return }
                        pushEditUndo()
                        moveVertex(to: coord)
                        selectedVertexIndex = nil
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "scope").font(.system(size: 12))
                            Text("Place here")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.dispersion(.primary))

                    Button {
                        pushEditUndo()
                        deleteVertex()
                    } label: {
                        Image(systemName: "minus.circle").font(.system(size: 14))
                    }
                    .buttonStyle(.dispersion(.ghost, size: .icon))
                }
                Text("Pan crosshair to new position")
                    .font(DispersionType.mono(8))
                    .foregroundStyle(DesignTokens.mutedForeground)
            } else {
                // No vertex selected — insert or tap one
                HStack(spacing: 8) {
                    Button {
                        pushEditUndo()
                        insertVertex()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle").font(.system(size: 12))
                            Text("Insert point")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.dispersion(.solid))

                    if !editUndoStack.isEmpty {
                        Button { editUndo() } label: {
                            Image(systemName: "arrow.uturn.backward").font(.system(size: 13))
                        }
                        .buttonStyle(.dispersion(.ghost, size: .icon))
                    }
                }
                Text("Tap a vertex to move it")
                    .font(DispersionType.mono(8))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }

            // Save / Cancel
            HStack(spacing: 8) {
                Button {
                    selectedPolygonId = nil
                    selectedVertexIndex = nil
                    editUndoStack = []
                    Haptics.light()
                } label: {
                    Text("Done").frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.solid))

                Button {
                    deletePolygon(id: selectedPolygonId!)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash").font(.system(size: 11))
                        Text("Delete")
                    }
                }
                .buttonStyle(.dispersion(.destructive, size: .sm))
            }
        }
    }

    private func pushEditUndo() {
        guard let selId = selectedPolygonId,
              let poly = holePolygons.first(where: { $0.id == selId }) else { return }
        editUndoStack.append(poly.coordinates)
    }

    private func editUndo() {
        guard let selId = selectedPolygonId,
              let polyIdx = holePolygons.firstIndex(where: { $0.id == selId }),
              let prev = editUndoStack.popLast() else { return }
        holePolygons[polyIdx].coordinates = prev
        let updated = holePolygons[polyIdx]
        let repo = CoursesRepo(context: modelContext)
        try? repo.deletePolygon(id: selId)
        try? repo.insertPolygons([updated])
        selectedVertexIndex = nil
        Haptics.light()
    }

    private var drawNewToolbar: some View {
        VStack(spacing: 8) {
            // Surface type selector
            HStack(spacing: 5) {
                ForEach([SurfaceType.fairway, .green, .bunker, .water, .rough, .tee], id: \.self) { surface in
                    Button {
                        activeTool = surface
                        currentPoints = []
                        Haptics.light()
                    } label: {
                        VStack(spacing: 3) {
                            Circle().fill(fillColor(surface)).frame(width: 10, height: 10)
                            Text(surface.rawValue.capitalized)
                                .font(DispersionType.mono(8, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(activeTool == surface ? fillColor(surface).opacity(0.25) : DesignTokens.surface)
                        )
                        .foregroundStyle(activeTool == surface ? .white : DesignTokens.foreground)
                    }
                    .buttonStyle(.plain)
                }
            }

            if quickEdit {
                // Auto-fill mode
                Button {
                    handleQuickFill()
                } label: {
                    HStack(spacing: 6) {
                        if filling {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Image(systemName: "wand.and.stars").font(.system(size: 13))
                        }
                        Text(filling ? "Tracing..." : "Fill \(activeTool.rawValue.capitalized)")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.dispersion(.primary))
                .disabled(filling)

                Text("Long-press map to select & edit a polygon")
                    .font(DispersionType.mono(8))
                    .foregroundStyle(DesignTokens.mutedForeground)

                HStack(spacing: 8) {
                    Text("Sensitivity").font(DispersionType.mono(9)).foregroundStyle(DesignTokens.mutedForeground)
                    Slider(value: $fillTolerance, in: 1...30, step: 1)
                        .tint(accent)
                    Text("\(Int(fillTolerance))").font(DispersionType.mono(9)).foregroundStyle(DesignTokens.mutedForeground)
                        .frame(width: 24)
                }

                if let err = fillError {
                    Text(err)
                        .font(DispersionType.mono(9))
                        .foregroundStyle(DesignTokens.destructive)
                }
            } else {
                // Manual draw mode
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
                    .buttonStyle(.dispersion(.primary))

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
                        }
                        .buttonStyle(.dispersion(.solid, size: .icon))
                    }
                }
            }

            // Polygon management
            if !holePolygons.isEmpty {
                // Polygon chips — tap to select, shows surface type
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(holePolygons, id: \.id) { poly in
                            let isSel = selectedPolygonId == poly.id
                            Button {
                                selectedPolygonId = isSel ? nil : poly.id
                                selectedVertexIndex = nil
                                Haptics.light()
                            } label: {
                                HStack(spacing: 3) {
                                    Circle().fill(fillColor(poly.surface)).frame(width: 6, height: 6)
                                    Text(poly.surface.rawValue.prefix(3).uppercased())
                                        .font(DispersionType.mono(8, weight: .bold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule().fill(isSel ? Color.white.opacity(0.2) : DesignTokens.surface)
                                )
                                .overlay(Capsule().strokeBorder(isSel ? Color.white : Color.clear, lineWidth: 1))
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Polygon management (only when not editing)
                if !holePolygons.isEmpty {
                    HStack(spacing: 6) {
                        Button {
                            if let last = holePolygons.last { deletePolygon(id: last.id) }
                        } label: {
                            Image(systemName: "arrow.uturn.backward").font(.system(size: 12))
                        }
                        .buttonStyle(.dispersion(.ghost, size: .icon))

                        Spacer()

                        Text("\(holePolygons.count) surfaces")
                            .font(DispersionType.mono(9))
                            .foregroundStyle(DesignTokens.mutedForeground)

                        if holePolygons.count > 1 {
                            Button { clearHolePolygons() } label: {
                                Text("Clear all")
                                    .font(DispersionType.mono(9, weight: .medium))
                                    .foregroundStyle(DesignTokens.destructive)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text("Long-press map to edit a polygon")
                    .font(DispersionType.mono(8))
                    .foregroundStyle(DesignTokens.mutedForeground)
            }
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var builderHolePicker: some View {
        DSheetHeader(eyebrow: "Jump to", title: "Select hole")

        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...course.holeCount, id: \.self) { hole in
                let info = holeInfos[hole]
                let hasTee = info?.teeBoxes.contains(where: { $0.coord != nil }) == true
                let hasPin = info?.defaultPinCoord != nil
                let hasPolys = (try? CoursesRepo(context: modelContext).polygons(courseId: courseId, hole: hole).contains { $0.holeNumber == hole }) ?? false
                let isCurrent = hole == currentHole
                Button {
                    currentPoints = []
                    selectedPolygonId = nil
                    selectedVertexIndex = nil
                    currentHole = hole
                    showHolePicker = false
                    Haptics.medium()
                } label: {
                    VStack(spacing: 3) {
                        Text("\(hole)")
                            .font(DispersionType.display(18, weight: .regular))
                            .monospacedDigit()
                        HStack(spacing: 2) {
                            if hasTee { Circle().fill(hex("#B8C880")).frame(width: 4, height: 4) }
                            if hasPin { Circle().fill(accent).frame(width: 4, height: 4) }
                            if hasPolys { Circle().fill(hex("#C4D49A")).frame(width: 4, height: 4) }
                        }
                        .frame(height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isCurrent ? accent.opacity(0.2) : DesignTokens.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(isCurrent ? accent : Color.clear, lineWidth: 1.5)
                            )
                    )
                    .foregroundStyle(DesignTokens.foreground)
                }
                .buttonStyle(.plain)
            }
        }
    }

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

    /// Check if the crosshair is inside any existing polygon — if so, select it for editing.
    private func selectPolygonAtCrosshair() {
        guard let coord = crosshairCoord else { return }
        // Check polygons in reverse z-order (top-most first)
        let reversed = holePolygons
            .filter { $0.coordinates.count >= 3 }
            .sorted { $0.surface.zOrder > $1.surface.zOrder }
        for poly in reversed {
            if pointInPolygon(coord, polygon: poly.coordinates) {
                selectedPolygonId = poly.id
                selectedVertexIndex = nil
                editUndoStack = []
                Haptics.heavy()
                return
            }
        }
        // Nothing under crosshair
        Haptics.light()
    }

    private func handleQuickFill() {
        guard let coord = crosshairCoord, let region = visibleRegion else { return }
        filling = true
        fillError = nil
        Haptics.light()
        Task {
            do {
                let result = try await MapAutoFill.fill(
                    center: CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng),
                    span: region.span,
                    tolerance: Int(fillTolerance)
                )

                // Animate the trace
                traceSurface = activeTool
                traceCoords = result.coordinates
                traceProgress = 0
                withAnimation(.easeOut(duration: 0.5)) { traceProgress = 1 }
                Haptics.success()

                // Wait for animation, then save and clear
                try await Task.sleep(for: .seconds(0.6))
                let polygon = CoursePolygon(
                    id: UUID().uuidString.lowercased(),
                    courseId: courseId,
                    holeNumber: currentHole,
                    surface: activeTool,
                    coordinates: result.coordinates
                )
                try CoursesRepo(context: modelContext).insertPolygons([polygon])
                holePolygons.append(polygon)
                withAnimation(.easeOut(duration: 0.3)) { traceCoords = nil }
                fillError = nil
            } catch {
                fillError = error.localizedDescription
                Haptics.error()
            }
            filling = false
        }
    }

    private func closePolygon() {
        guard currentPoints.count >= 3 else { return }
        // Smooth sharp angles with Chaikin corner cutting (2 iterations)
        let smoothed = chaikinSmooth(currentPoints, iterations: 2)
        let polygon = CoursePolygon(
            id: UUID().uuidString.lowercased(),
            courseId: courseId,
            holeNumber: currentHole,
            surface: activeTool,
            coordinates: smoothed
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

    /// Chaikin's corner-cutting algorithm — subdivides a closed polygon to
    /// soften sharp angles. Each iteration replaces vertices with two new
    /// points at 25% and 75% along each edge.
    private func chaikinSmooth(_ points: [Coord], iterations: Int) -> [Coord] {
        guard points.count >= 3, iterations > 0 else { return points }
        var result = points
        for _ in 0..<iterations {
            var smoothed: [Coord] = []
            let n = result.count
            for i in 0..<n {
                let a = result[i]
                let b = result[(i + 1) % n]
                smoothed.append(Coord(
                    lat: a.lat * 0.75 + b.lat * 0.25,
                    lng: a.lng * 0.75 + b.lng * 0.25
                ))
                smoothed.append(Coord(
                    lat: a.lat * 0.25 + b.lat * 0.75,
                    lng: a.lng * 0.25 + b.lng * 0.75
                ))
            }
            result = smoothed
        }
        return result
    }

    /// Insert a new vertex at the crosshair position between the two nearest
    /// consecutive vertices on the selected polygon's edge.
    private func insertVertex() {
        guard let coord = crosshairCoord,
              let selId = selectedPolygonId,
              let polyIdx = holePolygons.firstIndex(where: { $0.id == selId }) else { return }
        let coords = holePolygons[polyIdx].coordinates
        guard coords.count >= 3 else { return }

        // Find the edge segment closest to the crosshair
        var bestIdx = 0
        var bestDist = Double.infinity
        for i in 0..<coords.count {
            let a = coords[i]
            let b = coords[(i + 1) % coords.count]
            let d = distToSegment(coord, a: a, b: b)
            if d < bestDist { bestDist = d; bestIdx = i }
        }

        // Insert after bestIdx
        holePolygons[polyIdx].coordinates.insert(coord, at: bestIdx + 1)
        let updated = holePolygons[polyIdx]
        let repo = CoursesRepo(context: modelContext)
        try? repo.deletePolygon(id: selId)
        try? repo.insertPolygons([updated])
        selectedVertexIndex = bestIdx + 1
        Haptics.medium()
    }

    private func distToSegment(_ p: Coord, a: Coord, b: Coord) -> Double {
        let dx = b.lng - a.lng, dy = b.lat - a.lat
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return sqrt(pow(p.lng - a.lng, 2) + pow(p.lat - a.lat, 2)) }
        let t = max(0, min(1, ((p.lng - a.lng) * dx + (p.lat - a.lat) * dy) / lenSq))
        return sqrt(pow(p.lng - (a.lng + t * dx), 2) + pow(p.lat - (a.lat + t * dy), 2))
    }

    private func moveVertex(to coord: Coord) {
        guard let selId = selectedPolygonId,
              let polyIdx = holePolygons.firstIndex(where: { $0.id == selId }),
              let vi = selectedVertexIndex,
              vi < holePolygons[polyIdx].coordinates.count else { return }
        holePolygons[polyIdx].coordinates[vi] = coord
        // Persist: delete old, insert updated
        let updated = holePolygons[polyIdx]
        let repo = CoursesRepo(context: modelContext)
        try? repo.deletePolygon(id: selId)
        try? repo.insertPolygons([updated])
        Haptics.medium()
    }

    private func deleteVertex() {
        guard let selId = selectedPolygonId,
              let polyIdx = holePolygons.firstIndex(where: { $0.id == selId }),
              let vi = selectedVertexIndex,
              vi < holePolygons[polyIdx].coordinates.count,
              holePolygons[polyIdx].coordinates.count > 3 else { return }
        holePolygons[polyIdx].coordinates.remove(at: vi)
        selectedVertexIndex = nil
        let updated = holePolygons[polyIdx]
        let repo = CoursesRepo(context: modelContext)
        try? repo.deletePolygon(id: selId)
        try? repo.insertPolygons([updated])
        Haptics.medium()
    }

    private func deletePolygon(id: String) {
        try? CoursesRepo(context: modelContext).deletePolygon(id: id)
        holePolygons.removeAll { $0.id == id }
        if selectedPolygonId == id { selectedPolygonId = nil }
        Haptics.medium()
    }

    private func clearHolePolygons() {
        try? CoursesRepo(context: modelContext).deletePolygons(courseId: courseId, hole: currentHole)
        holePolygons.removeAll()
        selectedPolygonId = nil
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
