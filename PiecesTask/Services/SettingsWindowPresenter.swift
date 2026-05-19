import AppKit
import SwiftUI

/// Presents Settings in a real window. Required for LSUIElement menu bar apps where
/// `showSettingsWindow:` often does nothing.
@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?
    private var appState: AppState?
    private var appSettings: AppSettings?

    private init() {}

    func configure(appState: AppState, appSettings: AppSettings) {
        self.appState = appState
        self.appSettings = appSettings
    }

    func open() {
        guard let appState, let appSettings else {
            NSLog("PiecesTask: Settings not configured yet.")
            return
        }

        // Stop a slow popover refresh so Settings stays responsive.
        appState.cancelRefresh()
        dismissMenuBarPopover()

        if let window {
            window.setContentSize(NSSize(width: 560, height: 460))
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = SettingsView(appState: appState, appSettings: appSettings)

        let hosting = NSHostingController(rootView: rootView)
        hosting.safeAreaRegions = []

        let window = NSWindow(contentViewController: hosting)
        window.title = "PiecesTask Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 560, height: 460))
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Hide the menu bar popover window so it does not compete with Settings for focus/updates.
    private func dismissMenuBarPopover() {
        for window in NSApp.windows where window !== self.window {
            let name = String(describing: type(of: window))
            if name.contains("StatusBar") || name.contains("MenuBarExtra") {
                window.orderOut(nil)
            }
        }
    }
}
