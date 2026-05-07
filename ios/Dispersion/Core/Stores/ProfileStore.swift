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
    case brass, silver, copper, leather, carbon

    public var label: String { rawValue.capitalized }

    public var strapTop: Color {
        switch self {
        case .brass:   return hex("#c4a444")
        case .silver:  return hex("#b8bcc0")
        case .copper:  return hex("#c07848")
        case .leather: return hex("#6b4423")
        case .carbon:  return hex("#2a2a2a")
        }
    }

    public var strapBottom: Color {
        switch self {
        case .brass:   return hex("#8b7030")
        case .silver:  return hex("#808488")
        case .copper:  return hex("#8a5433")
        case .leather: return hex("#3d2613")
        case .carbon:  return hex("#111111")
        }
    }

    public var grommet: Color {
        switch self {
        case .brass:   return hex("#d4b44e")
        case .silver:  return hex("#e0e2e4")
        case .copper:  return hex("#d09060")
        case .leather: return hex("#8b5e3c")
        case .carbon:  return hex("#444444")
        }
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
    public var material: ProfileMaterial = .leather

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
        material = ProfileMaterial(rawValue: decoded.material) ?? .leather
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
