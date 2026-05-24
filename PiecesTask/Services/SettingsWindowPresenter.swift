import AppKit
import SwiftUI

/// Presents Settings in a real window. Required for LSUIElement menu bar apps where
/// `showSettingsWindow:` often does nothing.
@MainActor
final class SettingsWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowPresenter()

    private var window: NSWindow?
    private var appState: AppState?
    private var appSettings: AppSettings?

    private override init() {
        super.init()
    }

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
            applyWindowChrome(to: window)
            window.setContentSize(NSSize(width: 480, height: 400))
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = SettingsView(
            appState: appState,
            appSettings: appSettings,
            onDismiss: { [weak self] in self?.close() }
        )

        let hosting = NSHostingController(rootView: rootView)
        hosting.safeAreaRegions = []

        let window = NSWindow(contentViewController: hosting)
        window.title = "PiecesTask Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 480, height: 400))
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = self
        applyWindowChrome(to: window)

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyWindowChrome(to window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.hasShadow = true
    }

    /// Hide the menu bar popover window so it does not compete with Settings for focus/updates.
    func close() {
        appState?.cancelRefresh()
        window?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        close()
        return false
    }

    private func dismissMenuBarPopover() {
        for window in NSApp.windows where window !== self.window {
            let name = String(describing: type(of: window))
            if name.contains("StatusBar") || name.contains("MenuBarExtra") {
                window.orderOut(nil)
            }
        }
    }
}
