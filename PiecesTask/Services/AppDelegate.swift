import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let rightClickMenu = MenuBarRightClickMenuInstaller()

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsWindowPresenter.shared.configure(
            appState: AppState.shared,
            appSettings: AppSettings.shared
        )
        rightClickMenu.start()
        Task { @MainActor in
            await AppState.shared.probePiecesConnection()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        rightClickMenu.stop()
    }
}
