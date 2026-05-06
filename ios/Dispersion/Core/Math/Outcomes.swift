// Port of app/src/lib/outcomes.ts. Tag set logic + persistence helpers.

import Foundation

public enum Outcomes {
    /// Toggle a tag in/out of a set, with the constraint that some tags are
    /// mutually exclusive (e.g. "in" cannot coexist with directional misses).
    public static func toggle(
        in current: Set<ShotOutcomeTag>,
        tag: ShotOutcomeTag
    ) -> Set<ShotOutcomeTag> {
        var next = current
        if next.contains(tag) {
            next.remove(tag)
            return next
        }
        // "in" zeroes out directional misses.
        if tag == .in {
            return [.in]
        }
        // Adding a directional/penalty tag clears "in".
        next.remove(.in)
        // Long ↔ short are mutually exclusive; same for left ↔ right.
        switch tag {
        case .short: next.remove(.long)
        case .long:  next.remove(.short)
        case .left:  next.remove(.right)
        case .right: next.remove(.left)
        case .in, .penalty: break
        }
        next.insert(tag)
        return next
    }

    /// Encode for persistence (CSV string, mirrors the TS schema).
    public static func encode(_ tags: Set<ShotOutcomeTag>) -> String {
        // Stable order so equivalent sets compare equal as strings.
        let sorted = tags.map(\.rawValue).sorted()
        return sorted.joined(separator: ",")
    }

    public static func decode(_ raw: String) -> Set<ShotOutcomeTag> {
        let parts = raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        return Set(parts.compactMap { ShotOutcomeTag(rawValue: $0) })
    }
}
