// Port of app/src/lib/scenarioStore.ts (the *state* part — the pure functions
// `effectiveDistance` / `lieMultiplier` / `LIE_TYPES` live in
// Core/Math/LieAndConditions.swift).
//
// State persists across app launches via UserDefaults so a half-set scenario
// isn't lost when the user backgrounds the app.

import Foundation
import Observation

@MainActor
@Observable
public final class ScenarioStore {
    public static let shared = ScenarioStore()

    public var distance: Double = 150
    public var width: Double = 30
    public var depth: Double = 60
    public var presetId: String? = Presets.defaultId
    public var windMph: Double = 0
    public var elevationFt: Double = 0
    public var lie: LieType = .fairway
    public var minProbability: Double = 0
    public var pinPosition: PinPosition = .middle

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let distance = "scenario.distance"
        static let width = "scenario.width"
        static let depth = "scenario.depth"
        static let preset = "scenario.preset"
        static let wind = "scenario.windMph"
        static let elev = "scenario.elevationFt"
        static let lie = "scenario.lie"
        static let minProb = "scenario.minProbability"
    }

    public init() { load() }

    private func load() {
        if let v = numberValue(Keys.distance) { distance = v }
        if let v = numberValue(Keys.width) { width = v }
        if let v = numberValue(Keys.depth) { depth = v }
        if let raw = defaults.string(forKey: Keys.preset) { presetId = raw }
        if let v = numberValue(Keys.wind) { windMph = v }
        if let v = numberValue(Keys.elev) { elevationFt = v }
        if let raw = defaults.string(forKey: Keys.lie),
           let parsed = LieType(rawValue: raw) { lie = parsed }
        if let v = numberValue(Keys.minProb) { minProbability = v }
    }

    private func numberValue(_ key: String) -> Double? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.double(forKey: key)
    }

    /// Bound and persist a single field. Mirrors the safe() reducer in TS.
    public func update(_ patch: Patch) {
        if let v = patch.distance {
            distance = max(1, min(v, 1_000))
            defaults.set(distance, forKey: Keys.distance)
        }
        if let v = patch.width {
            width = max(1, min(v, 500))
            defaults.set(width, forKey: Keys.width)
        }
        if let v = patch.depth {
            depth = max(1, min(v, 500))
            defaults.set(depth, forKey: Keys.depth)
        }
        if let v = patch.preset {
            presetId = v
            if let s = v {
                defaults.set(s, forKey: Keys.preset)
            } else {
                defaults.removeObject(forKey: Keys.preset)
            }
        }
        if let v = patch.windMph {
            windMph = v
            defaults.set(v, forKey: Keys.wind)
        }
        if let v = patch.elevationFt {
            elevationFt = v
            defaults.set(v, forKey: Keys.elev)
        }
        if let v = patch.lie {
            lie = v
            defaults.set(v.rawValue, forKey: Keys.lie)
        }
        if let v = patch.minProbability {
            minProbability = max(0, min(v, 1))
            defaults.set(minProbability, forKey: Keys.minProb)
        }
    }

    public func applyPreset(_ id: String) {
        guard let p = Presets.get(id) else { return }
        update(Patch(width: p.widthYards, depth: p.depthYards, preset: id))
    }

    public struct Patch {
        public var distance: Double?
        public var width: Double?
        public var depth: Double?
        /// Use `.some(nil)` to clear (custom zone). Optional-of-optional is awkward
        /// in Swift; use `Patch.clearPreset()` helper instead.
        public var preset: String??
        public var windMph: Double?
        public var elevationFt: Double?
        public var lie: LieType?
        public var minProbability: Double?

        public init(
            distance: Double? = nil,
            width: Double? = nil,
            depth: Double? = nil,
            preset: String?? = nil,
            windMph: Double? = nil,
            elevationFt: Double? = nil,
            lie: LieType? = nil,
            minProbability: Double? = nil
        ) {
            self.distance = distance
            self.width = width
            self.depth = depth
            self.preset = preset
            self.windMph = windMph
            self.elevationFt = elevationFt
            self.lie = lie
            self.minProbability = minProbability
        }

        public static func clearPreset() -> Patch { Patch(preset: .some(nil)) }
    }
}
