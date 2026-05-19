import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let rightClickMenu = MenuBarRightClickMenuInstaller()

    func applicationDidFinishLaunching(_ notification: Notification) {
        rightClickMenu.start()
        UNUserNotificationCenter.current().delegate = SummaryNotificationService.shared
        Task { @MainActor in
            await AppModel.shared.appState.probePiecesConnection()
            await SummaryNotificationService.shared.refreshAuthorizationStatus()
            if AppSettings.shared.summaryRemindersEnabled {
                SummaryNotificationService.shared.reschedule()
            }
            if AppSettings.shared.quickWinRemindersEnabled {
                QuickWinNotificationService.shared.reschedule()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        SummaryNotificationService.shared.stop()
        QuickWinNotificationService.shared.stop()
        rightClickMenu.stop()
    }
}
