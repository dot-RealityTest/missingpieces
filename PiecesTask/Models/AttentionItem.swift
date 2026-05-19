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

    var sortOrder: Int {
        switch self {
        case .piecesUnavailable: return 0
        case .fetchFailed: return 1
        case .nextStep: return 2
        }
    }
}

struct AttentionItem: Identifiable, Sendable {
    let id: String
    let title: String
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
