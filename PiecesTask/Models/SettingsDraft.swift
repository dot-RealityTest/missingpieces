import Foundation

/// Editable copy of user preferences while the Settings window is open.
@MainActor
struct SettingsDraft: Equatable {
    var launchAtLogin: Bool
    var refreshOnPopoverOpen: Bool
    var globalShortcutEnabled: Bool
    var ollamaBaseURL: String
    var ollamaSelectedModel: String
    var lookbackDays: Int
    var visibleItemLimit: Int
    var stepsPerSession: Int

    init(from settings: AppSettings) {
        launchAtLogin = settings.launchAtLogin
        refreshOnPopoverOpen = settings.refreshOnPopoverOpen
        globalShortcutEnabled = settings.globalShortcutEnabled
        ollamaBaseURL = settings.ollamaBaseURL
        ollamaSelectedModel = settings.ollamaSelectedModel
        lookbackDays = settings.lookbackDays
        visibleItemLimit = settings.visibleItemLimit
        stepsPerSession = settings.stepsPerSession
    }

    @MainActor
    func commit(to settings: AppSettings, appState: AppState) async {
        let oldLookback = settings.lookbackDays
        let oldVisibleLimit = settings.visibleItemLimit
        let oldStepsPerSession = settings.stepsPerSession

        settings.launchAtLogin = launchAtLogin
        settings.refreshOnPopoverOpen = refreshOnPopoverOpen
        settings.globalShortcutEnabled = globalShortcutEnabled
        settings.ollamaBaseURL = ollamaBaseURL
        settings.ollamaSelectedModel = ollamaSelectedModel
        settings.lookbackDays = lookbackDays
        settings.visibleItemLimit = visibleItemLimit
        settings.stepsPerSession = stepsPerSession

        if lookbackDays != oldLookback
            || visibleItemLimit != oldVisibleLimit
            || stepsPerSession != oldStepsPerSession {
            await appState.refreshMissingFromPieces()
        }
    }
}
