import Foundation

/// How often PiecesTask nudges you with a follow-up summary.
enum SummaryReminderSchedule: String, CaseIterable, Identifiable, Sendable {
    case off
    case every15Minutes
    case every30Minutes
    case every60Minutes

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .every15Minutes: return "Every 15 minutes"
        case .every30Minutes: return "Every 30 minutes"
        case .every60Minutes: return "Every hour"
        }
    }

    /// `nil` when reminders are off.
    var intervalSeconds: TimeInterval? {
        switch self {
        case .off: return nil
        case .every15Minutes: return 15 * 60
        case .every30Minutes: return 30 * 60
        case .every60Minutes: return 60 * 60
        }
    }

    static func fromStored(_ raw: String?) -> SummaryReminderSchedule {
        guard let raw, let value = SummaryReminderSchedule(rawValue: raw) else {
            return .off
        }
        return value
    }
}
