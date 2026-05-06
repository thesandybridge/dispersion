// Port of app/src/lib/dialStore.ts. Each route registers its action set on
// appear; the persistent radial dial reads from here.

import Foundation
import Observation
import SwiftUI

public struct DialAction: Identifiable, Hashable {
    public var id: String
    public var label: String
    public var systemImage: String
    public var tone: Tone
    public var isDisabled: Bool
    public var perform: @MainActor () -> Void

    public enum Tone: Hashable {
        case `default`
        case primary
        case danger
    }

    public init(
        id: String,
        label: String,
        systemImage: String,
        tone: Tone = .default,
        isDisabled: Bool = false,
        perform: @escaping @MainActor () -> Void
    ) {
        self.id = id
        self.label = label
        self.systemImage = systemImage
        self.tone = tone
        self.isDisabled = isDisabled
        self.perform = perform
    }

    // Identity-only conformance — perform closures aren't comparable.
    public static func == (lhs: DialAction, rhs: DialAction) -> Bool {
        lhs.id == rhs.id
            && lhs.label == rhs.label
            && lhs.systemImage == rhs.systemImage
            && lhs.tone == rhs.tone
            && lhs.isDisabled == rhs.isDisabled
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(label)
        hasher.combine(systemImage)
        hasher.combine(tone)
        hasher.combine(isDisabled)
    }
}

@MainActor
@Observable
public final class DialStore {
    public static let shared = DialStore()

    public var actions: [DialAction] = []

    public init() {}

    public func setActions(_ next: [DialAction]) {
        actions = next
    }
}
