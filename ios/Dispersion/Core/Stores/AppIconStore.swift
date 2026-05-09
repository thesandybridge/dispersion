// Drives the app's alternate-icon picker. Each `AppIcon` corresponds to a
// `.appiconset` shipped in the asset catalog with three luminosity variants
// (light / dark / tinted), so iOS Home Screen customization (dark mode +
// user tint) renders correctly regardless of which palette the player picks.
//
// `AppIcon-Sand`, `AppIcon-Sunset`, and `AppIcon-Slate` are registered as
// alternates via `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` in
// project.yml; the primary `AppIcon` is the pine palette.

import Foundation
import Observation
import SwiftUI
import UIKit

public struct AppIcon: Identifiable, Hashable, Sendable {
    /// `nil` for the primary icon, otherwise the asset-catalog name passed
    /// to `UIApplication.setAlternateIconName(_:)`.
    public let alternateName: String?
    public let displayName: String
    public let previewAsset: String   // Asset Catalog imageset name

    public var id: String { alternateName ?? "primary" }
}

@MainActor
public extension AppIcon {
    static let pine = AppIcon(
        alternateName: nil,
        displayName: "Pine",
        previewAsset: "IconPreview-Pine"
    )
    static let sand = AppIcon(
        alternateName: "AppIcon-Sand",
        displayName: "Sand",
        previewAsset: "IconPreview-Sand"
    )
    static let sunset = AppIcon(
        alternateName: "AppIcon-Sunset",
        displayName: "Sunset",
        previewAsset: "IconPreview-Sunset"
    )
    static let slate = AppIcon(
        alternateName: "AppIcon-Slate",
        displayName: "Slate",
        previewAsset: "IconPreview-Slate"
    )

    static let all: [AppIcon] = [.pine, .sand, .sunset, .slate]
}

@Observable
@MainActor
public final class AppIconStore {
    public static let shared = AppIconStore()

    public private(set) var current: AppIcon

    private init() {
        let alt = UIApplication.shared.alternateIconName
        self.current = AppIcon.all.first { $0.alternateName == alt } ?? .pine
    }

    public func setIcon(_ icon: AppIcon) async {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        guard icon.id != current.id else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(icon.alternateName)
            self.current = icon
        } catch {
            // Silent: iOS will surface the failure via its own alert.
        }
    }
}
