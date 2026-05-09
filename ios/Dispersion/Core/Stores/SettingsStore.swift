// Port of app/src/lib/settingsStore.ts. Persisted via UserDefaults.

import Foundation
import Observation
import SwiftUI

public enum AppAppearance: String, CaseIterable, Sendable {
    case system, dark, light

    public var label: String { rawValue.capitalized }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

public enum HapticsIntensity: String, CaseIterable, Sendable {
    case off, light, medium, full

    public var label: String {
        switch self {
        case .off:    return "Off"
        case .light:  return "Light"
        case .medium: return "Medium"
        case .full:   return "Full"
        }
    }
}

public enum PaletteMode: String, CaseIterable, Sendable {
    case standard
    case redGreenSafe
    case blueYellowSafe
    case custom

    public var label: String {
        switch self {
        case .standard:       return "Standard"
        case .redGreenSafe:   return "Red-green safe"
        case .blueYellowSafe: return "Blue-yellow safe"
        case .custom:         return "Custom"
        }
    }

    public var helper: String {
        switch self {
        case .standard:
            return "Default green / red gradient"
        case .redGreenSafe:
            return "For deuteranopia or protanopia. Blue → orange axis."
        case .blueYellowSafe:
            return "For tritanopia. Red → teal axis."
        case .custom:
            return "Pick every color yourself."
        }
    }
}

@MainActor
@Observable
public final class SettingsStore {
    public static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let unit = "settings.unit"
        static let onboardingComplete = "settings.onboardingComplete"
        static let debugOverlay = "settings.debugOverlay"
        static let themeAccent = "settings.themeAccent"
        static let handedness = "settings.handedness"
        static let appearance = "settings.appearance"
        static let hapticsIntensity = "settings.hapticsIntensity"
        static let soundsEnabled = "settings.soundsEnabled"
        static let colorBlindMode = "settings.colorBlindMode"
    }

    public var unit: DistanceUnit = .yards
    public var onboardingComplete: Bool = false
    public var debugOverlay: Bool = false
    public var themeAccent: ProfileAccent = .bentgrass
    public var leftHanded: Bool = false
    public var appearance: AppAppearance = .system
    public var hapticsIntensity: HapticsIntensity = .full
    public var soundsEnabled: Bool = true
    public var paletteMode: PaletteMode = .standard

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
        leftHanded = defaults.bool(forKey: Keys.handedness)
        if let raw = defaults.string(forKey: Keys.themeAccent),
           let parsed = ProfileAccent(rawValue: raw) {
            themeAccent = parsed
        }
        if let raw = defaults.string(forKey: Keys.appearance),
           let parsed = AppAppearance(rawValue: raw) {
            appearance = parsed
        }
        if let raw = defaults.string(forKey: Keys.hapticsIntensity),
           let parsed = HapticsIntensity(rawValue: raw) {
            hapticsIntensity = parsed
        }
        if defaults.object(forKey: Keys.soundsEnabled) != nil {
            soundsEnabled = defaults.bool(forKey: Keys.soundsEnabled)
        }
        if let raw = defaults.string(forKey: Keys.colorBlindMode),
           let parsed = PaletteMode(rawValue: raw) {
            paletteMode = parsed
        }
    }

    public func setHapticsIntensity(_ v: HapticsIntensity) {
        hapticsIntensity = v
        defaults.set(v.rawValue, forKey: Keys.hapticsIntensity)
    }

    public func setSoundsEnabled(_ v: Bool) {
        soundsEnabled = v
        defaults.set(v, forKey: Keys.soundsEnabled)
    }

    public func setPaletteMode(_ v: PaletteMode) {
        paletteMode = v
        defaults.set(v.rawValue, forKey: Keys.colorBlindMode)
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

    public func setLeftHanded(_ value: Bool) {
        leftHanded = value
        defaults.set(value, forKey: Keys.handedness)
    }

    public func setThemeAccent(_ a: ProfileAccent) {
        themeAccent = a
        defaults.set(a.rawValue, forKey: Keys.themeAccent)
    }

    public func setAppearance(_ a: AppAppearance) {
        appearance = a
        defaults.set(a.rawValue, forKey: Keys.appearance)
    }

    public func resetOnboarding() {
        setOnboardingComplete(false)
    }
}
