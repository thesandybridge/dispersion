// Route enumeration. The TabView selection + the RadialDial joystick both
// pivot on this. Mirrors the four top-level routes in app/src/routes/.

import SwiftUI

public enum AppRoute: String, CaseIterable, Hashable, Identifiable {
    case calculator
    case bag
    case range
    case settings

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .calculator: return "Calc"
        case .bag:        return "Bag"
        case .range:      return "Range"
        case .settings:   return "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .calculator: return "scope"
        case .bag:        return "briefcase.fill"
        case .range:      return "flag.fill"
        case .settings:   return "gearshape.fill"
        }
    }
}

/// Routes that EmptyBagGuard locks out when there are zero clubs.
public let protectedRoutes: Set<AppRoute> = [.calculator, .range]
