// Port of app/src/lib/sessionStore.ts. Tracks the currently-active session
// (range or round) so the calculator + range screens can attach shots to it.

import Foundation
import Observation

public struct ActiveSession: Hashable, Codable, Sendable {
    public var id: String
    public var kind: SessionKind
    public var label: String
}

@MainActor
@Observable
public final class SessionStore {
    public static let shared = SessionStore()

    public var active: ActiveSession?

    private let defaults = UserDefaults.standard
    private let key = "sessionStore.active"

    public init() { load() }

    private func load() {
        guard let data = defaults.data(forKey: key) else { return }
        active = try? JSONDecoder().decode(ActiveSession.self, from: data)
    }

    public func setActive(_ session: ActiveSession?) {
        active = session
        if let s = session, let data = try? JSONEncoder().encode(s) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func clear() { setActive(nil) }
}
