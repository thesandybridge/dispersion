// Port of app/src/lib/settingsStore.ts. Persisted via UserDefaults.

import Foundation
import Observation

@MainActor
@Observable
public final class SettingsStore {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let unit = "settings.unit"
        static let onboardingComplete = "settings.onboardingComplete"
        static let debugOverlay = "settings.debugOverlay"
    }

    public var unit: DistanceUnit = .yards
    public var onboardingComplete: Bool = false
    public var debugOverlay: Bool = false

    public init() {
        load()
    }

    private func load() {
        if let raw = defaults.string(forKey: Keys.unit),
           let parsed = DistanceUnit(rawValue: raw) {
            unit = parsed
        }
        onboardingComplete = defaults.bool(forKey: Keys.onboardingComplete)
        debugOverlay = defaults.bool(forKey: Keys.debugOverlay)
    }

    public func setUnit(_ u: DistanceUnit) {
        unit = u
        defaults.set(u.rawValue, forKey: Keys.unit)
    }

    public func setOnboardingComplete(_ value: Bool) {
        onboardingComplete = value
        defaults.set(value, forKey: Keys.onboardingComplete)
    }

    public func setDebugOverlay(_ value: Bool) {
        debugOverlay = value
        defaults.set(value, forKey: Keys.debugOverlay)
    }

    public func resetOnboarding() {
        setOnboardingComplete(false)
    }
}
