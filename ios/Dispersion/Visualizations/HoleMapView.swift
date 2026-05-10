// Course map with polygon overlays in yardage-book style.
// Toggleable between polygon view and satellite verification mode.
// Crosshair at center for shot placement.

import MapKit
import SwiftUI

public struct HoleMapView: View {
    @Environment(\.themeAccent) private var accent
    public var polygons: [CoursePolygon]
    public var shots: [CourseShot]
    public var centerCoord: Coord?
    public var teeCoord: Coord?
    public var greenCoord: Coord?
    public var showCrosshair: Bool
    public var dispersion: ClubDispersionOverlay?
    @Binding public var crosshairCoord: Coord?

    public struct ClubDispersionOverlay {
        public var center: Coord
        public var carrySdYards: Double
        public var lateralSdYards: Double
        public var bearing: Double  // radians
        public var clubName: String
        public var carryYards: Int
    }

    @State private var position: MapCameraPosition = .automatic
    @State private var satellite = false
    @State private var cameraCenter: CLLocationCoordinate2D?

    private let greenFill = hex("#A8C97F")
    private let fairwayFill = hex("#C4D49A")
    private let bunkerFill = hex("#E8DCC0")
    private let waterFill = hex("#7EA5C4")
    private let teeFill = hex("#B8C880")
    private let roughFill = hex("#8FA66B")
    private let strokeColor = hex("#5A4D3F")
    private let bgColor = hex("#F2EFE7")

    public init(polygons: [CoursePolygon], shots: [CourseShot] = [],
                centerCoord: Coord? = nil, teeCoord: Coord? = nil,
                greenCoord: Coord? = nil, showCrosshair: Bool = true,
                dispersion: ClubDispersionOverlay? = nil,
                crosshairCoord: Binding<Coord?> = .constant(nil)) {
        self.polygons = polygons
        self.shots = shots
        self.centerCoord = centerCoord
        self.teeCoord = teeCoord
        self.greenCoord = greenCoord
        self.showCrosshair = showCrosshair
        self.dispersion = dispersion
        self._crosshairCoord = crosshairCoord
    }

    public var body: some View {
        ZStack {
            MapReader { proxy in
                Map(position: $position) {

                    // Flag pin
                    if let gc = greenCoord {
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: gc.lat, longitude: gc.lng)) {
                            VStack(spacing: 0) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(accent)
                                Circle().fill(accent).frame(width: 4, height: 4)
                            }
                        }
                    }

                    // Ball/tee marker
                    if let tc = teeCoord {
                        let label = shots.isEmpty ? "Tee" : "Ball"
                        Annotation(label, coordinate: CLLocationCoordinate2D(latitude: tc.lat, longitude: tc.lng)) {
                            ZStack {
                                Circle().fill(.white).frame(width: 16, height: 16)
                                Circle().fill(shots.isEmpty ? hex("#e6c068") : accent).frame(width: 10, height: 10)
                            }
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                    }

                    // Shot markers — the arcs themselves are drawn as a
                    // SwiftUI overlay below so they can take screen-space
                    // height (a true 3D arc on a tilted MapKit projection
                    // isn't supported by MapPolyline).
                    ForEach(sortedShots, id: \.id) { shot in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: shot.startLat, longitude: shot.startLng)) {
                            ZStack {
                                Circle().fill(.white).frame(width: 16, height: 16)
                                Circle().fill(accent).frame(width: 12, height: 12)
                                Text("\(shot.shotNumber)")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }

                    }

                    // Final landing
                    if let last = sortedShots.last {
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: last.endLat, longitude: last.endLng)) {
                            ZStack {
                                Circle().fill(.white).frame(width: 14, height: 14)
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(accent)
                            }
                        }
                    }

                    // Hole number labels on greens (when showing all)
                    ForEach(greenLabels, id: \.0) { label in
                        Annotation("", coordinate: label.1) {
                            Text("\(label.0)")
                                .font(.system(size: 10, weight: .bold, design: .serif))
                                .foregroundStyle(strokeColor)
                                .padding(3)
                                .background(Circle().fill(greenFill.opacity(0.9)))
                        }
                    }

                    // Club dispersion ellipse — locked to carry distance arc,
                    // aimed where the crosshair points
                    if let d = dispersion, let tee = teeCoord, let cam = cameraCenter {
                        let aimTarget = Coord(lat: cam.latitude, lng: cam.longitude)
                        let aimBearing = bearingRad(from: tee, to: aimTarget)
                        let aimCenter = projectCoord(from: tee, distanceYards: Double(d.carryYards), bearing: aimBearing)

                        // 2σ ellipse — outer
                        MapPolygon(coordinates: ellipseCoords(
                            center: aimCenter,
                            carrySd: d.carrySdYards * 2,
                            lateralSd: d.lateralSdYards * 2,
                            bearing: aimBearing
                        ))
                        .foregroundStyle(DesignTokens.heat2.opacity(0.15))
                        .stroke(DesignTokens.heat3.opacity(0.4), lineWidth: 1)

                        // 1σ ellipse — inner
                        MapPolygon(coordinates: ellipseCoords(
                            center: aimCenter,
                            carrySd: d.carrySdYards,
                            lateralSd: d.lateralSdYards,
                            bearing: aimBearing
                        ))
                        .foregroundStyle(DesignTokens.heat4.opacity(0.25))
                        .stroke(DesignTokens.heat5.opacity(0.6), lineWidth: 1.5)


                        // Landing label
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: aimCenter.lat, longitude: aimCenter.lng)) {
                            VStack(spacing: 1) {
                                Text(d.clubName)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                Text("\(d.carryYards)y")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(accent.opacity(0.85)))
                        }
                    }

                    UserAnnotation()
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    cameraCenter = context.camera.centerCoordinate
                    crosshairCoord = Coord(
                        lat: context.camera.centerCoordinate.latitude,
                        lng: context.camera.centerCoordinate.longitude
                    )
                }
                .overlay {
                    // Use MapProxy to get the true coordinate at screen center
                    // This corrects for perspective distortion when pitched
                    GeometryReader { geo in
                        Color.clear.onChange(of: cameraCenter?.latitude) { _, _ in
                            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                            if let coord = proxy.convert(center, from: .local) {
                                crosshairCoord = Coord(lat: coord.latitude, lng: coord.longitude)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay {
                    trajectoryOverlay(proxy: proxy)
                        .allowsHitTesting(false)
                }
            }

            // Crosshair overlay
            if showCrosshair {
                crosshairOverlay
            }

            // Controls overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()

                    // Fit to hole
                    Button {
                        orientCamera()
                        Haptics.light()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "scope").font(.system(size: 11))
                            Text("Hole").font(DispersionType.mono(10, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(DesignTokens.popover)
                                                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
        .onAppear { orientCamera() }
        .onChange(of: teeCoord?.lat) { _, _ in orientCamera() }
        .onChange(of: greenCoord?.lat) { _, _ in orientCamera() }
    }

    // MARK: - Trajectory overlay

    /// Per-shot screen-space arc + dashed residual line from the ball to
    /// the pin. Drawn in screen coordinates because SwiftUI's MapPolyline
    /// is 2D-only — projecting the start/end through MapProxy already
    /// accounts for the camera's pitch and rotation, so the arc just
    /// needs an upward bend in screen pixels.
    @ViewBuilder
    private func trajectoryOverlay(proxy: MapProxy) -> some View {
        // `cameraCenter` ticks on every camera change, so reading it here
        // makes Canvas redraw whenever the user pans / pitches / zooms.
        let _ = cameraCenter
        Canvas { ctx, size in
            for shot in sortedShots {
                let startCoord = CLLocationCoordinate2D(latitude: shot.startLat, longitude: shot.startLng)
                let endCoord = CLLocationCoordinate2D(latitude: shot.endLat, longitude: shot.endLng)
                guard
                    let s = proxy.convert(startCoord, to: .local),
                    let e = proxy.convert(endCoord, to: .local)
                else { continue }

                let path = arcPath(from: s, to: e, distanceYards: shot.distanceYards)
                ctx.stroke(path, with: .color(accent), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))

                // Distance label — perched at the apex of the arc.
                let apex = arcApex(from: s, to: e, distanceYards: shot.distanceYards)
                let label = Text("\(Int(shot.distanceYards))y")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                let resolved = ctx.resolve(label)
                let labelSize = resolved.measure(in: size)
                let pad: CGFloat = 5
                let bgRect = CGRect(
                    x: apex.x - labelSize.width / 2 - pad,
                    y: apex.y - labelSize.height / 2 - 2,
                    width: labelSize.width + pad * 2,
                    height: labelSize.height + 4
                )
                ctx.fill(
                    Path(roundedRect: bgRect, cornerRadius: bgRect.height / 2),
                    with: .color(accent.opacity(0.92))
                )
                ctx.draw(resolved, at: CGPoint(x: apex.x, y: apex.y))
            }

            // Dashed residual line — current ball position → pin. The "ball"
            // is the last shot's landing point if any shots have been hit,
            // otherwise the tee.
            if let pin = greenCoord {
                let from: Coord
                if let last = sortedShots.last {
                    from = Coord(lat: last.endLat, lng: last.endLng)
                } else if let tee = teeCoord {
                    from = tee
                } else {
                    return
                }
                let fromCoord = CLLocationCoordinate2D(latitude: from.lat, longitude: from.lng)
                let toCoord = CLLocationCoordinate2D(latitude: pin.lat, longitude: pin.lng)
                guard
                    let p0 = proxy.convert(fromCoord, to: .local),
                    let p1 = proxy.convert(toCoord, to: .local)
                else { return }
                var line = Path()
                line.move(to: p0)
                line.addLine(to: p1)
                ctx.stroke(
                    line,
                    with: .color(.white.opacity(0.85)),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [5, 5])
                )
            }
        }
    }

    /// Quadratic-Bezier arc in screen space whose apex height scales with
    /// the shot's actual yardage. Apex is `~0.18 × distance` in yards,
    /// rendered in pixels via the start→end screen distance / yards ratio.
    private func arcPath(from s: CGPoint, to e: CGPoint, distanceYards: Double) -> Path {
        let apex = arcApex(from: s, to: e, distanceYards: distanceYards)
        var path = Path()
        path.move(to: s)
        // Quadratic control point at 2 × apex - midpoint so the curve passes
        // through the apex at t = 0.5.
        let mid = CGPoint(x: (s.x + e.x) / 2, y: (s.y + e.y) / 2)
        let control = CGPoint(x: 2 * apex.x - mid.x, y: 2 * apex.y - mid.y)
        path.addQuadCurve(to: e, control: control)
        return path
    }

    private func arcApex(from s: CGPoint, to e: CGPoint, distanceYards: Double) -> CGPoint {
        let mid = CGPoint(x: (s.x + e.x) / 2, y: (s.y + e.y) / 2)
        let dx = e.x - s.x
        let dy = e.y - s.y
        let screenDist = sqrt(dx * dx + dy * dy)
        guard screenDist > 1, distanceYards > 1 else { return mid }
        // Real golf shot apex is roughly proportional to carry: ~30 yards
        // for a driver, ~15 for a wedge. 0.18× is a tasteful average.
        let apexYards = max(8.0, min(40.0, distanceYards * 0.18))
        let pixelsPerYard = screenDist / distanceYards
        let lift = apexYards * pixelsPerYard
        return CGPoint(x: mid.x, y: mid.y - lift)
    }

    // MARK: - Crosshair

    private var crosshairOverlay: some View {
        ZStack {
            // Horizontal line
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 24, height: 1)
            // Vertical line
            Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 1, height: 24)
            // Center dot
            Circle()
                .fill(accent)
                .frame(width: 4, height: 4)
            // Outer ring
            Circle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                .frame(width: 20, height: 20)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Camera

    private func orientCamera() {
        if let tee = teeCoord, let green = greenCoord {
            let bearing = bearingDegrees(from: tee, to: green)
            let mid = Coord(lat: (tee.lat + green.lat) / 2, lng: (tee.lng + green.lng) / 2)
            let dist = haversineYards(from: tee, to: green)
            let altitude = max(250, dist * 1.0)
            withAnimation(.easeInOut(duration: 0.5)) {
                position = .camera(MapCamera(
                    centerCoordinate: CLLocationCoordinate2D(latitude: mid.lat, longitude: mid.lng),
                    distance: altitude,
                    heading: bearing,
                    pitch: 50
                ))
            }
        } else {
            fitToContent()
        }
    }

    private func fitToContent() {
        let allCoords = polygons.flatMap(\.coordinates)
        if !allCoords.isEmpty {
            let bb = boundingBox(allCoords)
            let center = CLLocationCoordinate2D(
                latitude: (bb.min.lat + bb.max.lat) / 2,
                longitude: (bb.min.lng + bb.max.lng) / 2
            )
            let latSpan = (bb.max.lat - bb.min.lat) * 1.4
            let lngSpan = (bb.max.lng - bb.min.lng) * 1.4
            position = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: max(latSpan, 0.002), longitudeDelta: max(lngSpan, 0.002))
            ))
        } else if let c = centerCoord {
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lng),
                latitudinalMeters: 1500, longitudinalMeters: 1500
            ))
        }
    }

    // MARK: - Helpers

    private var sortedPolygons: [CoursePolygon] {
        polygons
            .filter { $0.coordinates.count >= 3 }
            .sorted { $0.surface.zOrder < $1.surface.zOrder }
    }

    private var sortedShots: [CourseShot] {
        shots.sorted { $0.shotNumber < $1.shotNumber }
    }

    private var greenLabels: [(Int, CLLocationCoordinate2D)] {
        polygons
            .filter { $0.surface == .green && $0.holeNumber != nil && $0.coordinates.count >= 3 }
            .filter { greenCoord == nil || centroid($0.coordinates).lat != greenCoord?.lat }
            .map { poly in
                let c = centroid(poly.coordinates)
                return (poly.holeNumber!, CLLocationCoordinate2D(latitude: c.lat, longitude: c.lng))
            }
    }

    private func fillFor(_ surface: SurfaceType) -> Color {
        switch surface {
        case .green:   return greenFill
        case .fairway: return fairwayFill
        case .rough:   return roughFill
        case .bunker:  return bunkerFill
        case .water:   return waterFill
        case .tee:     return teeFill
        }
    }
}

// Generate ellipse polygon coordinates rotated along the hole bearing
private func ellipseCoords(center: Coord, carrySd: Double, lateralSd: Double, bearing: Double, segments: Int = 18) -> [CLLocationCoordinate2D] {
    let metersPerDegLat = 111111.0
    let metersPerDegLng = 111111.0 * cos(center.lat * .pi / 180)
    var coords: [CLLocationCoordinate2D] = []
    for i in 0...segments {
        let angle = Double(i) / Double(segments) * 2 * .pi
        // Ellipse in yards, carry along the bearing axis, lateral perpendicular
        let alongYards = carrySd * cos(angle)
        let acrossYards = lateralSd * sin(angle)
        // Rotate by bearing
        let dNorth = alongYards * cos(bearing) - acrossYards * sin(bearing)
        let dEast = alongYards * sin(bearing) + acrossYards * cos(bearing)
        // Convert to degrees
        let lat = center.lat + (dNorth * 0.9144) / metersPerDegLat
        let lng = center.lng + (dEast * 0.9144) / metersPerDegLng
        coords.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
    }
    return coords
}

private func bearingRad(from a: Coord, to b: Coord) -> Double {
    let lat1 = a.lat * .pi / 180; let lat2 = b.lat * .pi / 180
    let dLng = (b.lng - a.lng) * .pi / 180
    let y = sin(dLng) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
    return atan2(y, x)
}

private func projectCoord(from origin: Coord, distanceYards: Double, bearing: Double) -> Coord {
    let meters = distanceYards * 0.9144
    let lat = origin.lat + (meters / 111111.0) * cos(bearing)
    let lng = origin.lng + (meters / (111111.0 * cos(origin.lat * .pi / 180))) * sin(bearing)
    return Coord(lat: lat, lng: lng)
}

private func bearingDegrees(from a: Coord, to b: Coord) -> Double {
    let lat1 = a.lat * .pi / 180
    let lat2 = b.lat * .pi / 180
    let dLng = (b.lng - a.lng) * .pi / 180
    let y = sin(dLng) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
    return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
}
