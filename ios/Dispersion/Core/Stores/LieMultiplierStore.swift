// User-tunable σ multipliers per lie type. Defaults are the hand-tuned
// values from `LieType.defaultSigmaMultiplier`; if the player overrides any,
// the override is persisted and `multiplier(for:)` reflects it.

import Foundation
import Observation

@MainActor
@Observable
public final class LieMultiplierStore {
    public static let shared = LieMultiplierStore()

    /// Per-lie overrides keyed by `LieType.rawValue`. A value here means the
    /// player has chosen a custom multiplier for that lie.
    public private(set) var overrides: [LieType: Double] = [:]

    private let defaults = UserDefaults.standard
    private let key = "lieMultiplierOverrides"

    public init() { load() }

    /// The σ multiplier the calculator should actually use for the given lie.
    /// Returns the override if set, otherwise the hand-tuned default.
    public func multiplier(for lie: LieType) -> Double {
        overrides[lie] ?? lie.defaultSigmaMultiplier
    }

    public func isOverridden(_ lie: LieType) -> Bool {
        overrides[lie] != nil
    }

    /// Set an override. Pass nil to clear and revert to the default.
    public func setOverride(_ value: Double?, for lie: LieType) {
        if let value {
            let clamped = max(LieType.multiplierRange.lowerBound,
                              min(value, LieType.multiplierRange.upperBound))
            overrides[lie] = clamped
        } else {
            overrides.removeValue(forKey: lie)
        }
        save()
    }

    /// Clear all overrides — every lie reverts to its default.
    public func resetAll() {
        overrides.removeAll()
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data)
        else { return }
        for (k, v) in decoded {
            if let lie = LieType(rawValue: k) {
                overrides[lie] = v
            }
        }
    }

    private func save() {
        let encodable = overrides.reduce(into: [String: Double]()) {
            $0[$1.key.rawValue] = $1.value
        }
        if let data = try? JSONEncoder().encode(encodable) {
            defaults.set(data, forKey: key)
        }
    }
}
