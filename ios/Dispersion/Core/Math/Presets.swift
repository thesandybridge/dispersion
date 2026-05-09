// Port of app/src/lib/presets.ts. Common safe-zone presets the calculator uses.

import Foundation

/// Whether the safe zone represents a green (pin to aim AT) or a fairway-style
/// corridor (an area to land IN). Drives the visual treatment in DispersionViz.
public enum ZoneKind: String, Hashable, Sendable {
    case green
    case fairway
}

public struct ZonePreset: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var widthYards: Double
    public var depthYards: Double
    public var kind: ZoneKind
}

public enum Presets {
    public static let all: [ZonePreset] = [
        ZonePreset(id: "fairway",       label: "Fairway",       widthYards: 30, depthYards: 60, kind: .fairway),
        ZonePreset(id: "tight-fairway", label: "Tight fairway", widthYards: 22, depthYards: 50, kind: .fairway),
        ZonePreset(id: "green",         label: "Green",         widthYards: 25, depthYards: 25, kind: .green),
        ZonePreset(id: "lay-up",        label: "Lay-up",        widthYards: 40, depthYards: 30, kind: .fairway),
        ZonePreset(id: "tight-pin",     label: "Tight pin",     widthYards: 14, depthYards: 14, kind: .green),
    ]

    public static let defaultId: String = "fairway"

    public static func get(_ id: String) -> ZonePreset? {
        all.first { $0.id == id }
    }

    public static var defaultPreset: ZonePreset {
        Self.get(defaultId) ?? all[0]
    }

    /// Resolve the zone kind for a scenario. Uses the matching preset when
    /// present; falls back to an aspect-ratio heuristic for custom zones —
    /// roughly square (depth/width within ~1.4×) reads as a green, otherwise
    /// fairway corridor.
    public static func kind(presetId: String?, width: Double, depth: Double) -> ZoneKind {
        if let id = presetId, let p = get(id) { return p.kind }
        guard width > 0, depth > 0 else { return .fairway }
        let ratio = max(width, depth) / min(width, depth)
        return ratio <= 1.4 ? .green : .fairway
    }
}
