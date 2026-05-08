// Port of app/src/lib/profileStore.ts. Stores the user's personalization data
// for the bag tag: name, handicap, home course, and visual style choices.

import Foundation
import Observation
import SwiftUI

// MARK: - Accent

public enum ProfileAccent: String, CaseIterable, Codable, Sendable {
    case bentgrass, flag, sand, water, pine, sage

    public var color: Color {
        switch self {
        case .bentgrass: return hex("#a9d18e")
        case .flag:      return hex("#c87060")
        case .sand:      return hex("#e6c068")
        case .water:     return hex("#7aa3cc")
        case .pine:      return hex("#4a7c5c")
        case .sage:      return hex("#8fae8b")
        }
    }

    public var label: String { rawValue.capitalized }
}

// MARK: - Font

public enum ProfileFont: String, CaseIterable, Codable, Sendable {
    case serif, sans, mono

    public var label: String {
        switch self {
        case .serif: return "Serif"
        case .sans:  return "Sans"
        case .mono:  return "Mono"
        }
    }

    public func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .serif: return .system(size: size, design: .serif).weight(weight)
        case .sans:  return .system(size: size, design: .default).weight(weight)
        case .mono:  return .system(size: size, design: .monospaced).weight(weight)
        }
    }
}

// MARK: - Material

public enum ProfileMaterial: String, CaseIterable, Codable, Sendable {
    case silver, black, gold, roseGold

    public var label: String {
        switch self {
        case .silver: return "Silver"
        case .black: return "Black"
        case .gold: return "Gold"
        case .roseGold: return "Rose Gold"
        }
    }

    public var preview: Color {
        switch self {
        case .silver:   return Color(red: 0.75, green: 0.76, blue: 0.78)
        case .black:    return Color(red: 0.12, green: 0.13, blue: 0.14)
        case .gold:     return Color(red: 0.83, green: 0.69, blue: 0.42)
        case .roseGold: return Color(red: 0.72, green: 0.45, blue: 0.45)
        }
    }

    public var baseUIColor: UIColor {
        switch self {
        case .silver:   return UIColor(red: 0.75, green: 0.76, blue: 0.78, alpha: 1)
        case .black:    return UIColor(red: 0.12, green: 0.13, blue: 0.14, alpha: 1)
        case .gold:     return UIColor(red: 0.83, green: 0.69, blue: 0.42, alpha: 1)
        case .roseGold: return UIColor(red: 0.72, green: 0.45, blue: 0.45, alpha: 1)
        }
    }

    public var edgeColor: UIColor {
        switch self {
        case .silver:   return UIColor(red: 0.82, green: 0.83, blue: 0.85, alpha: 1)
        case .black:    return UIColor(red: 0.2, green: 0.21, blue: 0.22, alpha: 1)
        case .gold:     return UIColor(red: 0.88, green: 0.76, blue: 0.5, alpha: 1)
        case .roseGold: return UIColor(red: 0.78, green: 0.52, blue: 0.52, alpha: 1)
        }
    }

    public var texBg: [Color] {
        switch self {
        case .silver:   return [hex("#4a4d50"), hex("#3a3d40"), hex("#2e3133")]
        case .black:    return [hex("#1e2022"), hex("#161819"), hex("#111314")]
        case .gold:     return [hex("#5c4a2a"), hex("#4a3b22"), hex("#3a2e1a")]
        case .roseGold: return [hex("#4a2e2e"), hex("#3a2424"), hex("#2e1c1c")]
        }
    }

    public var textOpacity: Double {
        self == .black ? 0.85 : 0.95
    }
}

// MARK: - Store

@MainActor
@Observable
public final class ProfileStore {
    public static let shared = ProfileStore()

    public var name: String = ""
    public var handicap: String = ""
    public var homeCourse: String = ""
    public var motto: String = ""
    public var contact: String = ""
    public var accent: ProfileAccent = .bentgrass
    public var font: ProfileFont = .serif
    public var material: ProfileMaterial = .silver

    private let defaults = UserDefaults.standard
    private let key = "dispersion.profile.v1"

    public init() { load() }

    public func setProfile(
        name: String? = nil,
        handicap: String? = nil,
        homeCourse: String? = nil,
        motto: String? = nil,
        contact: String? = nil,
        accent: ProfileAccent? = nil,
        font: ProfileFont? = nil,
        material: ProfileMaterial? = nil
    ) {
        if let v = name { self.name = v }
        if let v = handicap { self.handicap = v }
        if let v = homeCourse { self.homeCourse = v }
        if let v = motto { self.motto = v }
        if let v = contact { self.contact = v }
        if let v = accent { self.accent = v }
        if let v = font { self.font = v }
        if let v = material { self.material = v }
        save()
    }

    private func save() {
        let data = ProfileData(
            name: name, handicap: handicap, homeCourse: homeCourse,
            motto: motto, contact: contact,
            accent: accent.rawValue, font: font.rawValue, material: material.rawValue
        )
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: key)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ProfileData.self, from: data) else { return }
        name = decoded.name
        handicap = decoded.handicap
        homeCourse = decoded.homeCourse
        motto = decoded.motto
        contact = decoded.contact
        accent = ProfileAccent(rawValue: decoded.accent) ?? .bentgrass
        font = ProfileFont(rawValue: decoded.font) ?? .serif
        material = ProfileMaterial(rawValue: decoded.material) ?? .silver
    }
}

private struct ProfileData: Codable {
    var name: String
    var handicap: String
    var homeCourse: String
    var motto: String
    var contact: String
    var accent: String
    var font: String
    var material: String
}
