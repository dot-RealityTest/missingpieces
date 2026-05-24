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
        static let dismissedFollowUpIDs = "dismissedFollowUpIDs"
        static let globalShortcutEnabled = "globalShortcutEnabled"
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

    var stepsPerSession: Int {
        didSet {
            let clamped = Self.clamp(stepsPerSession, to: Self.stepsPerSessionOptions, default: 2)
            if clamped != stepsPerSession { stepsPerSession = clamped; return }
            UserDefaults.standard.set(stepsPerSession, forKey: Keys.stepsPerSession)
        }
    }

    var refreshOnPopoverOpen: Bool {
        didSet {
            UserDefaults.standard.set(refreshOnPopoverOpen, forKey: Keys.refreshOnPopoverOpen)
        }
    }

    var globalShortcutEnabled: Bool {
        didSet {
            UserDefaults.standard.set(globalShortcutEnabled, forKey: Keys.globalShortcutEnabled)
            GlobalHotKeyService.shared.start(enabled: globalShortcutEnabled)
        }
    }

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

    var ollamaSelectedModel: String {
        didSet {
            UserDefaults.standard.set(ollamaSelectedModel, forKey: Keys.ollamaSelectedModel)
        }
    }

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
        if defaults.object(forKey: Keys.globalShortcutEnabled) == nil {
            globalShortcutEnabled = true
        } else {
            globalShortcutEnabled = defaults.bool(forKey: Keys.globalShortcutEnabled)
        }
        ollamaBaseURL = defaults.string(forKey: Keys.ollamaBaseURL) ?? OllamaService.defaultBaseURL
        ollamaSelectedModel = defaults.string(forKey: Keys.ollamaSelectedModel) ?? ""
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

    func restoreDismissedFollowUp(id: String) {
        guard !id.isEmpty else { return }
        dismissedFollowUpIDs.remove(id)
        persistDismissedFollowUps()
    }

    func restoreAllDismissedFollowUps() {
        dismissedFollowUpIDs.removeAll()
        persistDismissedFollowUps()
    }

    private func persistDismissedFollowUps() {
        UserDefaults.standard.set(Array(dismissedFollowUpIDs), forKey: Keys.dismissedFollowUpIDs)
    }

    func pickOllamaModel(from models: [OllamaModelInfo]) {
        ollamaSelectedModel = OllamaModelPreference.pickModelName(
            current: ollamaSelectedModel,
            from: models
        )
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
