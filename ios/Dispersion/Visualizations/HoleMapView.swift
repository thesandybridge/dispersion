// Course map using MapKit with satellite imagery.
// Orients camera tee-to-green, shows markers and shot tracking.

import MapKit
import SwiftUI

public struct HoleMapView: View {
    public var polygons: [CoursePolygon]
    public var shots: [CourseShot]
    public var centerCoord: Coord?
    public var teeCoord: Coord?
    public var greenCoord: Coord?
    public var onTapLocation: ((Coord) -> Void)?

    @State private var position: MapCameraPosition = .automatic

    private let accentColor = hex("#C25E3F")
    private let greenColor = hex("#2c8a5e")
    private let teeColor = hex("#e6c068")

    public init(polygons: [CoursePolygon], shots: [CourseShot] = [],
                centerCoord: Coord? = nil, teeCoord: Coord? = nil,
                greenCoord: Coord? = nil, onTapLocation: ((Coord) -> Void)? = nil) {
        self.polygons = polygons
        self.shots = shots
        self.centerCoord = centerCoord
        self.teeCoord = teeCoord
        self.greenCoord = greenCoord
        self.onTapLocation = onTapLocation
    }

    public var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                // Green pin
                if let gc = greenCoord {
                    Annotation("Green", coordinate: CLLocationCoordinate2D(latitude: gc.lat, longitude: gc.lng)) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(greenColor)
                            .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    }
                }

                // Tee marker
                if let tc = teeCoord {
                    Annotation("Tee", coordinate: CLLocationCoordinate2D(latitude: tc.lat, longitude: tc.lng)) {
                        ZStack {
                            Circle().fill(teeColor).frame(width: 14, height: 14)
                            Circle().strokeBorder(.white, lineWidth: 2).frame(width: 14, height: 14)
                        }
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                    }
                }

                // Other green labels (when showing all holes)
                ForEach(greenLabels, id: \.0) { label in
                    Annotation("", coordinate: label.1) {
                        Text("\(label.0)")
                            .font(.system(size: 9, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(greenColor.opacity(0.85)))
                    }
                }

                // Shot lines and markers
                ForEach(sortedShots, id: \.id) { shot in
                    MapPolyline(coordinates: [
                        CLLocationCoordinate2D(latitude: shot.startLat, longitude: shot.startLng),
                        CLLocationCoordinate2D(latitude: shot.endLat, longitude: shot.endLng)
                    ])
                    .stroke(accentColor, lineWidth: 2.5)

                    // Start dot
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: shot.startLat, longitude: shot.startLng)) {
                        ZStack {
                            Circle().fill(accentColor).frame(width: 12, height: 12)
                            Circle().strokeBorder(.white, lineWidth: 1.5).frame(width: 12, height: 12)
                            Text("\(shot.shotNumber)")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                    // Yardage label
                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: (shot.startLat + shot.endLat) / 2,
                        longitude: (shot.startLng + shot.endLng) / 2
                    )) {
                        Text("\(Int(shot.distanceYards))y")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(accentColor.opacity(0.9)))
                    }
                }

                // Final landing marker
                if let last = sortedShots.last {
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: last.endLat, longitude: last.endLng)) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(accentColor)
                            .background(Circle().fill(.white).frame(width: 10, height: 10))
                    }
                }

                UserAnnotation()
            }
            .mapStyle(.imagery(elevation: .flat))
            .mapControls {
                MapCompass()
                MapScaleView()
                MapUserLocationButton()
            }
            .onTapGesture { screenPoint in
                if let coord = proxy.convert(screenPoint, from: .local) {
                    onTapLocation?(Coord(lat: coord.latitude, lng: coord.longitude))
                }
            }
        }
        .onAppear { orientCamera() }
        .onChange(of: teeCoord?.lat) { _, _ in orientCamera() }
        .onChange(of: greenCoord?.lat) { _, _ in orientCamera() }
        .onChange(of: polygons.count) { _, _ in orientCamera() }
    }

    // MARK: - Camera orientation (tee → green)

    private func orientCamera() {
        if let tee = teeCoord, let green = greenCoord {
            // Orient looking from tee toward green
            let bearing = bearingDegrees(from: tee, to: green)
            let mid = Coord(lat: (tee.lat + green.lat) / 2, lng: (tee.lng + green.lng) / 2)
            let dist = haversineYards(from: tee, to: green)
            // Camera altitude in meters — further holes need higher camera
            let altitude = max(200, dist * 0.8)
            position = .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(latitude: mid.lat, longitude: mid.lng),
                distance: altitude,
                heading: bearing,
                pitch: 45
            ))
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

    private var sortedShots: [CourseShot] {
        shots.sorted { $0.shotNumber < $1.shotNumber }
    }

    private var greenLabels: [(Int, CLLocationCoordinate2D)] {
        // Only show labels for holes other than the focused one
        polygons
            .filter { $0.surface == .green && $0.holeNumber != nil }
            .filter { greenCoord == nil || centroid($0.coordinates).lat != greenCoord?.lat }
            .map { poly in
                let c = centroid(poly.coordinates)
                return (poly.holeNumber!, CLLocationCoordinate2D(latitude: c.lat, longitude: c.lng))
            }
    }
}

// MARK: - Bearing calculation

private func bearingDegrees(from a: Coord, to b: Coord) -> Double {
    let lat1 = a.lat * .pi / 180
    let lat2 = b.lat * .pi / 180
    let dLng = (b.lng - a.lng) * .pi / 180
    let y = sin(dLng) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
    let bearing = atan2(y, x) * 180 / .pi
    return (bearing + 360).truncatingRemainder(dividingBy: 360)
}
