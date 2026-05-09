// User-defined palette. Each slot persists as a hex string in UserDefaults
// so it round-trips across launches. When the user switches palette mode to
// `.custom`, the calculator and visualizations read from this store.

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class CustomPaletteStore {
    public static let shared = CustomPaletteStore()

    public enum Slot: String, CaseIterable, Sendable {
        case pStrong, pFavored, pMarginal, pPoor, danger
        case primary, destructive, flag
        case heat0, heat1, heat2, heat3, heat4, heat5

        public var label: String {
            switch self {
            case .pStrong:     return "Strong"
            case .pFavored:    return "Favored"
            case .pMarginal:   return "Marginal"
            case .pPoor:       return "Poor"
            case .danger:      return "Danger"
            case .primary:     return "Primary"
            case .destructive: return "Destructive"
            case .flag:        return "Flag"
            case .heat0:       return "Heat 0"
            case .heat1:       return "Heat 1"
            case .heat2:       return "Heat 2"
            case .heat3:       return "Heat 3"
            case .heat4:       return "Heat 4"
            case .heat5:       return "Heat 5"
            }
        }

        /// Shortcut for the section divider in Settings UI.
        public var section: Section {
            switch self {
            case .pStrong, .pFavored, .pMarginal, .pPoor, .danger:
                return .probability
            case .primary, .destructive, .flag:
                return .status
            case .heat0, .heat1, .heat2, .heat3, .heat4, .heat5:
                return .heat
            }
        }
    }

    public enum Section: String, CaseIterable, Sendable {
        case probability, status, heat
        public var label: String {
            switch self {
            case .probability: return "Probability gradient"
            case .status:      return "Status colors"
            case .heat:        return "Heat ramp"
            }
        }
    }

    /// Hex strings keyed by slot. Defaults to the standard palette.
    public private(set) var hexes: [Slot: String] = [:]

    private let defaults = UserDefaults.standard
    private let key = "customPalette"

    public init() {
        load()
        if hexes.isEmpty {
            // First launch: seed from the standard palette so the user has a
            // sensible starting point in the picker.
            seed(from: .standard)
        }
    }

    public func color(for slot: Slot) -> Color {
        if let h = hexes[slot] { return hex(h) }
        return Palettes.standard.color(for: slot)
    }

    public func setColor(_ color: Color, for slot: Slot) {
        hexes[slot] = color.toHex()
        save()
    }

    public func setHex(_ hex: String, for slot: Slot) {
        hexes[slot] = hex
        save()
    }

    /// Replace all custom colors with the colors from a base mode. Useful
    /// when the user wants to start customizing from an existing palette.
    public func seed(from mode: PaletteMode) {
        // Avoid recursion if mode is .custom — fall back to standard.
        let base: Palette = (mode == .custom)
            ? Palettes.standard
            : Palettes.resolve(mode)
        for slot in Slot.allCases {
            hexes[slot] = base.color(for: slot).toHex() ?? "#888888"
        }
        save()
    }

    public func resolved() -> Palette {
        Palette(
            pStrong:     color(for: .pStrong),
            pFavored:    color(for: .pFavored),
            pMarginal:   color(for: .pMarginal),
            pPoor:       color(for: .pPoor),
            danger:      color(for: .danger),
            primary:     color(for: .primary),
            destructive: color(for: .destructive),
            flag:        color(for: .flag),
            heat0:       color(for: .heat0),
            heat1:       color(for: .heat1),
            heat2:       color(for: .heat2),
            heat3:       color(for: .heat3),
            heat4:       color(for: .heat4),
            heat5:       color(for: .heat5)
        )
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        for (k, v) in decoded {
            if let slot = Slot(rawValue: k) {
                hexes[slot] = v
            }
        }
    }

    private func save() {
        let dict = hexes.reduce(into: [String: String]()) { $0[$1.key.rawValue] = $1.value }
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: key)
        }
    }
}

// MARK: - Helpers

extension Palette {
    /// Slot accessor — used by `CustomPaletteStore.seed(from:)` to copy colors
    /// from a base palette into the custom set.
    func color(for slot: CustomPaletteStore.Slot) -> Color {
        switch slot {
        case .pStrong:     return pStrong
        case .pFavored:    return pFavored
        case .pMarginal:   return pMarginal
        case .pPoor:       return pPoor
        case .danger:      return danger
        case .primary:     return primary
        case .destructive: return destructive
        case .flag:        return flag
        case .heat0:       return heat0
        case .heat1:       return heat1
        case .heat2:       return heat2
        case .heat3:       return heat3
        case .heat4:       return heat4
        case .heat5:       return heat5
        }
    }
}

// MARK: - Color ↔ hex

extension Color {
    /// Best-effort hex string for round-tripping through UserDefaults. Falls
    /// back to nil if the color isn't representable as RGB (rare for the
    /// colors we use, but possible for system materials).
    fileprivate func toHex() -> String? {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let R = Int((r * 255).rounded())
        let G = Int((g * 255).rounded())
        let B = Int((b * 255).rounded())
        return String(format: "#%02X%02X%02X", R, G, B)
        #else
        return nil
        #endif
    }
}
