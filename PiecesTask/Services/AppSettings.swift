import Foundation

/// User preferences stored in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let lookbackDays = "piecesLookbackDays"
        static let visibleItemLimit = "piecesVisibleItemLimit"
        static let stepsPerSession = "piecesStepsPerSession"
        static let refreshOnPopoverOpen = "piecesRefreshOnPopoverOpen"
        static let ollamaBaseURL = "ollamaBaseURL"
        static let ollamaSelectedModel = "ollamaSelectedModel"
        static let ollamaCloudAPIKey = "ollamaCloudAPIKey"
        static let dismissedFollowUpIDs = "dismissedFollowUpIDs"
        static let summaryReminderSchedule = "summaryReminderSchedule"
        static let quickWinRemindersEnabled = "quickWinRemindersEnabled"
    }

    /// Follow-ups the user hid in this app only (not sent to Pieces).
    private(set) var dismissedFollowUpIDs: Set<String> = []

    static let lookbackOptions = [3, 7, 14]
    static let visibleLimitOptions = [5, 8, 12]
    static let stepsPerSessionOptions = [1, 2, 3]

    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            applyLaunchAtLogin()
        }
    }

    /// How far back to read workstream summaries.
    var lookbackDays: Int {
        didSet {
            let clamped = Self.clamp(lookbackDays, to: Self.lookbackOptions, default: 7)
            if clamped != lookbackDays { lookbackDays = clamped; return }
            UserDefaults.standard.set(lookbackDays, forKey: Keys.lookbackDays)
        }
    }

    /// Max follow-up rows shown in the menu bar popover.
    var visibleItemLimit: Int {
        didSet {
            let clamped = Self.clamp(visibleItemLimit, to: Self.visibleLimitOptions, default: 8)
            if clamped != visibleItemLimit { visibleItemLimit = clamped; return }
            UserDefaults.standard.set(visibleItemLimit, forKey: Keys.visibleItemLimit)
        }
    }

    /// Next steps pulled from each work session summary.
    var stepsPerSession: Int {
        didSet {
            let clamped = Self.clamp(stepsPerSession, to: Self.stepsPerSessionOptions, default: 2)
            if clamped != stepsPerSession { stepsPerSession = clamped; return }
            UserDefaults.standard.set(stepsPerSession, forKey: Keys.stepsPerSession)
        }
    }

    /// When on, opening the popover checks Pieces again (not background polling).
    var refreshOnPopoverOpen: Bool {
        didSet {
            UserDefaults.standard.set(refreshOnPopoverOpen, forKey: Keys.refreshOnPopoverOpen)
        }
    }

    /// macOS notification cadence for AI/plain follow-up summaries.
    var summaryReminderSchedule: SummaryReminderSchedule {
        didSet {
            if summaryReminderSchedule != oldValue {
                UserDefaults.standard.set(summaryReminderSchedule.rawValue, forKey: Keys.summaryReminderSchedule)
            }
        }
    }

    var summaryRemindersEnabled: Bool {
        summaryReminderSchedule != .off
    }

    /// Suggest one small follow-up about every 30 minutes.
    var quickWinRemindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(quickWinRemindersEnabled, forKey: Keys.quickWinRemindersEnabled)
        }
    }

    /// Ollama API base URL (local inference).
    var ollamaBaseURL: String {
        didSet {
            let normalized = OllamaService.normalizedBaseURL(ollamaBaseURL)
            if normalized != ollamaBaseURL {
                ollamaBaseURL = normalized
                return
            }
            UserDefaults.standard.set(ollamaBaseURL, forKey: Keys.ollamaBaseURL)
        }
    }

    /// Last successfully tested Ollama model name.
    var ollamaSelectedModel: String {
        didSet {
            UserDefaults.standard.set(ollamaSelectedModel, forKey: Keys.ollamaSelectedModel)
        }
    }

    /// API key for Ollama cloud / remote models (`Authorization: Bearer …`).
    var ollamaCloudAPIKey: String {
        didSet {
            UserDefaults.standard.set(ollamaCloudAPIKey, forKey: Keys.ollamaCloudAPIKey)
        }
    }

    var hasOllamaCloudAPIKey: Bool {
        !ollamaCloudAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedModelNeedsCloudAPIKey: Bool {
        OllamaModelPreference.isCloudModel(ollamaSelectedModel)
    }

    /// Upper bound when fetching from Pieces (a bit above what we show).
    var fetchTotalLimit: Int {
        min(24, max(visibleItemLimit, stepsPerSession * 6))
    }

    var lookbackLabel: String {
        switch lookbackDays {
        case 1: return "1 day"
        case 7: return "1 week"
        case 14: return "2 weeks"
        default: return "\(lookbackDays) days"
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
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
        stepsPerSession = Self.clamp(
            defaults.object(forKey: Keys.stepsPerSession) as? Int ?? 2,
            to: Self.stepsPerSessionOptions,
            default: 2
        )
        refreshOnPopoverOpen = defaults.object(forKey: Keys.refreshOnPopoverOpen) as? Bool ?? true
        summaryReminderSchedule = SummaryReminderSchedule.fromStored(
            defaults.string(forKey: Keys.summaryReminderSchedule)
        )
        if defaults.object(forKey: Keys.quickWinRemindersEnabled) == nil {
            quickWinRemindersEnabled = true
        } else {
            quickWinRemindersEnabled = defaults.bool(forKey: Keys.quickWinRemindersEnabled)
        }
        ollamaBaseURL = defaults.string(forKey: Keys.ollamaBaseURL) ?? OllamaService.defaultBaseURL
        ollamaSelectedModel = defaults.string(forKey: Keys.ollamaSelectedModel) ?? ""
        ollamaCloudAPIKey = defaults.string(forKey: Keys.ollamaCloudAPIKey) ?? ""
        if let stored = defaults.array(forKey: Keys.dismissedFollowUpIDs) as? [String] {
            dismissedFollowUpIDs = Set(stored)
        }
    }

    var dismissedFollowUpCount: Int { dismissedFollowUpIDs.count }

    var canUseOllamaSummary: Bool { !ollamaSelectedModel.isEmpty }

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

    /// Fills in a default model only when none is chosen or the saved name is gone.
    /// Does not change the user's pick on connectivity test (keeps cloud/heavy models).
    func pickOllamaModel(from models: [OllamaModelInfo]) {
        guard !models.isEmpty else {
            ollamaSelectedModel = ""
            return
        }
        let preferred = OllamaModelPreference.preferredLightModel(from: models) ?? models[0].name

        if ollamaSelectedModel.isEmpty {
            ollamaSelectedModel = preferred
            return
        }
        if !models.contains(where: { $0.name == ollamaSelectedModel }) {
            ollamaSelectedModel = preferred
        }
    }

    func syncLaunchAtLoginFromSystem() {
        let systemEnabled = LaunchAtLoginHelper.isEnabled
        guard systemEnabled != launchAtLogin else { return }
        launchAtLogin = systemEnabled
    }

    private func applyLaunchAtLogin() {
        do {
            try LaunchAtLoginHelper.setEnabled(launchAtLogin)
        } catch {
            launchAtLogin = LaunchAtLoginHelper.isEnabled
        }
    }

    private static func clamp(_ value: Int, to options: [Int], default defaultValue: Int) -> Int {
        options.contains(value) ? value : defaultValue
    }
}
