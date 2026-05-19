import SwiftUI
import AppKit

enum PopoverLayout {
    static let width: CGFloat = 360
    /// Menu bar windows clip the top curve — need extra space above the header.
    static let topInset: CGFloat = 10
    static let bottomInset: CGFloat = 8
    static let horizontalInset: CGFloat = 8

    static var edgeInsets: EdgeInsets {
        EdgeInsets(
            top: topInset,
            leading: horizontalInset,
            bottom: bottomInset,
            trailing: horizontalInset
        )
    }

    static var size: CGSize {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 900
        let height = min(500, max(400, screenHeight * 0.42))
        return CGSize(width: width, height: height)
    }
}

@main
struct PiecesTaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            RootPopoverView()
                .environment(model.appState)
                .environment(model.appSettings)
        } label: {
            MenuBarExtraLabel(appState: model.appState)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    SettingsWindowPresenter.shared.open()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
