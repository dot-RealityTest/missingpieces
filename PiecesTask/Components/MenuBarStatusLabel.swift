import SwiftUI

/// Observes `AppState` so the menu bar icon updates when Pieces connects or disconnects.
struct MenuBarExtraLabel: View {
    @Bindable var appState: AppState

    var body: some View {
        MenuBarStatusLabel(
            isPiecesConnected: appState.isPiecesConnected,
            attentionCount: appState.attentionCount,
            hasProblemItems: appState.hasProblemItems
        )
    }
}

/// Menu bar icon shown in `MenuBarExtra`. Right-click menu is provided by `MenuBarRightClickMenuInstaller`.
struct MenuBarStatusLabel: View {
    var isPiecesConnected: Bool
    var attentionCount: Int
    var hasProblemItems: Bool = false

    var body: some View {
        Group {
            if let image = MenuBarStatusIcon.makeNSImage(
                isPiecesConnected: isPiecesConnected,
                attentionCount: attentionCount,
                hasProblemItems: hasProblemItems
            ) {
                Image(nsImage: image)
            } else {
                MenuBarStatusIcon.labelContent(
                    isPiecesConnected: isPiecesConnected,
                    attentionCount: attentionCount,
                    hasProblemItems: hasProblemItems
                )
                .frame(width: 18, height: 18)
            }
        }
        .help(helpText)
        .accessibilityLabel(helpText)
    }

    private var helpText: String {
        let connection = isPiecesConnected ? "Pieces OS connected" : "Pieces OS offline"
        if attentionCount > 0 {
            return "\(connection) — \(attentionCount) follow-up\(attentionCount == 1 ? "" : "s")"
        }
        if hasProblemItems {
            return "\(connection) — needs attention"
        }
        return "\(connection) — right-click for menu"
    }
}
