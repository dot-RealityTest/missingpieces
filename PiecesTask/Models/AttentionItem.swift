import Foundation

/// Why something appears in “what you're missing”.
enum AttentionReason: String, CaseIterable, Sendable {
    case piecesUnavailable
    case nextStep
    case fetchFailed

    var label: String {
        switch self {
        case .piecesUnavailable: return "Pieces OS is off"
        case .nextStep: return "Next step"
        case .fetchFailed: return "Couldn't read Pieces"
        }
    }

    var icon: String {
        switch self {
        case .piecesUnavailable: return "wifi.exclamationmark"
        case .nextStep: return "arrow.turn.down.right"
        case .fetchFailed: return "exclamationmark.icloud"
        }
    }

    var isProblem: Bool {
        switch self {
        case .nextStep: return false
        case .piecesUnavailable, .fetchFailed: return true
        }
    }
}

struct AttentionItem: Identifiable, Sendable {
    let id: String
    let title: String
    /// Full text copied on double-click; equals `title` for connection problems.
    let copyText: String
    let reason: AttentionReason
    let detail: String?
}

/// One work session and its follow-up steps (for grouped list UI).
struct AttentionSection: Identifiable, Sendable {
    let id: String
    let sessionName: String
    let items: [AttentionItem]
}

/// A follow-up action parsed from a Pieces workstream summary.
struct PiecesNextStep: Sendable {
    let summaryID: String
    let sessionName: String
    let stepText: String
}
