// Port of app/src/lib/clubCategory.ts.

import SwiftUI

public enum ClubCategory: String, CaseIterable, Sendable {
    case driver
    case wood
    case hybrid
    case longIron = "long-iron"
    case midIron = "mid-iron"
    case shortIron = "short-iron"
    case wedge
    case putter
}

public struct CategoryStyle: Sendable {
    public let label: String
    /// Light/accent color
    public let accent: Color
    /// Deep/darker accent (for outlines, deeper text)
    public let accentDeep: Color
    /// Gradient from accentDeep → accent (135°)
    public let gradient: Gradient
    /// Foreground color suitable for text on top of `accent`
    public let inkOnAccent: Color
}

public enum ClubCategoryRegistry {
    public static func style(for category: ClubCategory) -> CategoryStyle {
        switch category {
        case .driver:
            return CategoryStyle(
                label: "Driver",
                accent: hex("#62b375"),
                accentDeep: hex("#2c8a5e"),
                gradient: Gradient(colors: [hex("#2c8a5e"), hex("#16624a")]),
                inkOnAccent: hex("#0a1410")
            )
        case .wood:
            return CategoryStyle(
                label: "Wood",
                accent: hex("#a9d18e"),
                accentDeep: hex("#62b375"),
                gradient: Gradient(colors: [hex("#62b375"), hex("#2c8a5e")]),
                inkOnAccent: hex("#0a1410")
            )
        case .hybrid:
            return CategoryStyle(
                label: "Hybrid",
                accent: hex("#e6c068"),
                accentDeep: hex("#b08e3a"),
                gradient: Gradient(colors: [hex("#d4a942"), hex("#8a6d22")]),
                inkOnAccent: hex("#1a2419")
            )
        case .longIron:
            return CategoryStyle(
                label: "Long iron",
                accent: hex("#c87060"),
                accentDeep: hex("#8a4a3e"),
                gradient: Gradient(colors: [hex("#b85a4a"), hex("#6b3a30")]),
                inkOnAccent: hex("#f6f1e1")
            )
        case .midIron:
            return CategoryStyle(
                label: "Mid iron",
                accent: hex("#1f3a5f"),
                accentDeep: hex("#102342"),
                gradient: Gradient(colors: [hex("#1f3a5f"), hex("#102342")]),
                inkOnAccent: hex("#f6f1e1")
            )
        case .shortIron:
            return CategoryStyle(
                label: "Short iron",
                accent: hex("#5b8db8"),
                accentDeep: hex("#36648c"),
                gradient: Gradient(colors: [hex("#4d7fa8"), hex("#2a4f74")]),
                inkOnAccent: hex("#f6f1e1")
            )
        case .wedge:
            return CategoryStyle(
                label: "Wedge",
                accent: hex("#f0e7b8"),
                accentDeep: hex("#c4b878"),
                gradient: Gradient(colors: [hex("#d4c98a"), hex("#8a7c4a")]),
                inkOnAccent: hex("#1a2419")
            )
        case .putter:
            return CategoryStyle(
                label: "Putter",
                accent: Color(red: 0.10, green: 0.14, blue: 0.10).opacity(0.6),
                accentDeep: Color(red: 0.10, green: 0.14, blue: 0.10).opacity(0.85),
                gradient: Gradient(colors: [hex("#4a544c"), hex("#1a2419")]),
                inkOnAccent: hex("#f6f1e1")
            )
        }
    }

    /// Categorize from name first; fall back to carry distance.
    public static func categorize(name: String, carryYards: Double) -> ClubCategory {
        let byName = categoryFromName(name)
        if byName != .midIron { return byName }
        return categoryFromCarry(carryYards)
    }

    private static func categoryFromName(_ name: String) -> ClubCategory {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()

        // Order matters — check more specific patterns before the generic fallback.
        if matches(lower, regex: #"\bdriver\b|\bdvr\b"#) { return .driver }
        if matches(lower, regex: #"\bwood\b|\b\dw\b|\b\d wood\b"#) { return .wood }
        if matches(lower, regex: #"\bhybrid\b|\bh\d\b|\b\dh\b|\butility\b"#) { return .hybrid }
        if matches(lower, regex: #"\b(lob|sand|gap|pitch)\s*wedge|\b(lw|sw|gw|pw)\b|\bwedge\b"#) { return .wedge }
        if matches(lower, regex: #"\bputter\b|\bptr\b"#) { return .putter }
        if matches(lower, regex: #"\b[1-4]\s*iron\b|\b[1-4]i\b"#) { return .longIron }
        if matches(lower, regex: #"\b[5-7]\s*iron\b|\b[5-7]i\b"#) { return .midIron }
        if matches(lower, regex: #"\b[8-9]\s*iron\b|\b[8-9]i\b"#) { return .shortIron }
        return .midIron
    }

    private static func categoryFromCarry(_ carryYards: Double) -> ClubCategory {
        if carryYards >= 250 { return .driver }
        if carryYards >= 220 { return .wood }
        if carryYards >= 200 { return .hybrid }
        if carryYards >= 180 { return .longIron }
        if carryYards >= 150 { return .midIron }
        if carryYards >= 130 { return .shortIron }
        if carryYards >= 60 { return .wedge }
        return .putter
    }

    private static func matches(_ s: String, regex: String) -> Bool {
        guard let re = try? NSRegularExpression(pattern: regex, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return re.firstMatch(in: s, options: [], range: range) != nil
    }
}

