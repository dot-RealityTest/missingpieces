import Foundation

/// User preferences stored in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let lookbackDays = "piecesLookbackDays"
        static let visibleItemLimit = "piecesVisibleItemLimit"
        static let refreshOnPopoverOpen = "piecesRefreshOnPopoverOpen"
        static let dismissedFollowUpIDs = "dismissedFollowUpIDs"
    }

    /// Follow-ups the user marked done in this app only (not sent to Pieces).
    private(set) var dismissedFollowUpIDs: Set<String> = []

    static let lookbackOptions = [3, 7, 14]
    static let visibleLimitOptions = [5, 8, 12]

    var lookbackDays: Int {
        didSet {
            let clamped = Self.clamp(lookbackDays, to: Self.lookbackOptions, default: 7)
            if clamped != lookbackDays { lookbackDays = clamped; return }
            UserDefaults.standard.set(lookbackDays, forKey: Keys.lookbackDays)
        }
    }

    var visibleItemLimit: Int {
        didSet {
            let clamped = Self.clamp(visibleItemLimit, to: Self.visibleLimitOptions, default: 8)
            if clamped != visibleItemLimit { visibleItemLimit = clamped; return }
            UserDefaults.standard.set(visibleItemLimit, forKey: Keys.visibleItemLimit)
        }
    }

    var refreshOnPopoverOpen: Bool {
        didSet {
            UserDefaults.standard.set(refreshOnPopoverOpen, forKey: Keys.refreshOnPopoverOpen)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        lookbackDays = Self.clamp(
            defaults.object(forKey: Keys.lookbackDays) as? Int ?? 7,
            to: Self.lookbackOptions,
            default: 7
        )
        visibleItemLimit = Self.clamp(
            defaults.object(forKey: Keys.visibleItemLimit) as? Int ?? 8,
            to: Self.visibleLimitOptions,
            default: 8
        )
        refreshOnPopoverOpen = defaults.object(forKey: Keys.refreshOnPopoverOpen) as? Bool ?? true
        if let stored = defaults.array(forKey: Keys.dismissedFollowUpIDs) as? [String] {
            dismissedFollowUpIDs = Set(stored)
        }
    }

    var dismissedFollowUpCount: Int { dismissedFollowUpIDs.count }

    func isDismissedFollowUp(id: String) -> Bool {
        dismissedFollowUpIDs.contains(id)
    }

    func dismissFollowUp(id: String) {
        guard !id.isEmpty else { return }
        dismissedFollowUpIDs.insert(id)
        persistDismissedFollowUps()
    }

    func restoreAllDismissedFollowUps() {
        dismissedFollowUpIDs.removeAll()
        persistDismissedFollowUps()
    }

    private func persistDismissedFollowUps() {
        UserDefaults.standard.set(Array(dismissedFollowUpIDs), forKey: Keys.dismissedFollowUpIDs)
    }

    private static func clamp(_ value: Int, to options: [Int], default defaultValue: Int) -> Int {
        options.contains(value) ? value : defaultValue
    }
}
