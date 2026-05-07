// Single-shot GPS capture. Samples for 2 seconds, averages readings,
// returns the best fix. No background tracking.

import CoreLocation
import Foundation

@MainActor
public final class LocationCapture: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published public var lastCoord: Coord?
    @Published public var accuracy: Double = 999
    @Published public var capturing = false
    @Published public var error: String?

    private let manager = CLLocationManager()
    private var samples: [CLLocation] = []
    private var continuation: CheckedContinuation<Coord, Error>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
    }

    public func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    public var isAuthorized: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    /// Capture a single GPS fix. Samples for ~2 seconds, returns averaged position.
    public func capture() async throws -> Coord {
        if !isAuthorized { requestPermission() }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.samples = []
            self.capturing = true
            self.error = nil
            manager.startUpdatingLocation()

            // Stop after 2 seconds and return best fix
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                self.finish()
            }
        }
    }

    private func finish() {
        manager.stopUpdatingLocation()
        capturing = false

        guard let cont = continuation else { return }
        continuation = nil

        guard !samples.isEmpty else {
            cont.resume(throwing: CaptureError.noFix)
            return
        }

        let avgLat = samples.reduce(0.0) { $0 + $1.coordinate.latitude } / Double(samples.count)
        let avgLng = samples.reduce(0.0) { $0 + $1.coordinate.longitude } / Double(samples.count)
        let bestAccuracy = samples.map(\.horizontalAccuracy).min() ?? 999

        let coord = Coord(lat: avgLat, lng: avgLng)
        lastCoord = coord
        accuracy = bestAccuracy

        if bestAccuracy > 8 {
            error = "Low accuracy: \(Int(bestAccuracy))m"
        }

        cont.resume(returning: coord)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let valid = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy < 50 }
        Task { @MainActor in
            self.samples.append(contentsOf: valid)
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error.localizedDescription
        }
    }

    public enum CaptureError: LocalizedError {
        case noFix
        public var errorDescription: String? { "Could not get a GPS fix" }
    }
}
