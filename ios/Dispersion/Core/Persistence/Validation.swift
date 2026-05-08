// Persistence-boundary validation. Guards against NaN, Infinity, and
// nonsensical values before they reach SwiftData.

import Foundation

public enum ValidationError: LocalizedError {
    case emptyName
    case invalidCarry(Double)
    case invalidSigma(String, Double)
    case invalidDistance(Double)
    case invalidDelta(String, Double)

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Club name cannot be empty."
        case .invalidCarry(let v):
            return "Invalid carry distance: \(v)"
        case .invalidSigma(let field, let v):
            return "Invalid \(field): \(v)"
        case .invalidDistance(let v):
            return "Invalid target distance: \(v)"
        case .invalidDelta(let field, let v):
            return "Invalid \(field): \(v)"
        }
    }
}
