import Foundation

public enum Provider: String, CaseIterable, Codable, Sendable {
    case claude
    case codex

    public var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        }
    }
}
