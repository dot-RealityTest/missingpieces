import Foundation

/// Shared app model — one instance for menu bar popover, settings window, and menus.
@MainActor
final class AppModel {
    static let shared = AppModel()

    let appState = AppState()
    let appSettings = AppSettings.shared

    private init() {
        SettingsWindowPresenter.shared.configure(
            appState: appState,
            appSettings: appSettings
        )
        SummaryNotificationService.shared.configure(appState: appState)
        QuickWinNotificationService.shared.configure(appState: appState)
        if appSettings.summaryRemindersEnabled {
            SummaryNotificationService.shared.reschedule()
        }
        if appSettings.quickWinRemindersEnabled {
            QuickWinNotificationService.shared.reschedule()
        }
    }
}
