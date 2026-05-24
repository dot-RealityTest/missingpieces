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
        GlobalHotKeyService.shared.start(enabled: AppSettings.shared.globalShortcutEnabled)
        Task { @MainActor in
            await AppState.shared.probePiecesConnection()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GlobalHotKeyService.shared.stop()
        rightClickMenu.stop()
    }
}
