// Port of app/src/lib/presets.ts. Common safe-zone presets the calculator uses.

import Foundation

public struct ZonePreset: Identifiable, Hashable, Sendable {
    public var id: String
    public var label: String
    public var widthYards: Double
    public var depthYards: Double
}

public enum Presets {
    public static let all: [ZonePreset] = [
        ZonePreset(id: "fairway", label: "Fairway", widthYards: 30, depthYards: 60),
        ZonePreset(id: "tight-fairway", label: "Tight fairway", widthYards: 22, depthYards: 50),
        ZonePreset(id: "green", label: "Green", widthYards: 25, depthYards: 25),
        ZonePreset(id: "lay-up", label: "Lay-up", widthYards: 40, depthYards: 30),
        ZonePreset(id: "tight-pin", label: "Tight pin", widthYards: 14, depthYards: 14),
    ]

    public static let defaultId: String = "fairway"

    public static func get(_ id: String) -> ZonePreset? {
        all.first { $0.id == id }
    }

    public static var defaultPreset: ZonePreset {
        get(defaultId) ?? all[0]
    }
}
