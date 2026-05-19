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

/// Small connection dot for use inside the popover (always visible on any header icon color).
struct PiecesConnectionDot: View {
    let isConnected: Bool
    var hasProblem: Bool = false
    var hasFollowUps: Bool = false
    var size: CGFloat = 7

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .scaleEffect(isConnected && !hasProblem ? 1.0 : 0.92)
            .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: isConnected)
            .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.quick), value: hasProblem)
            .accessibilityHidden(true)
    }

    private var fillColor: Color {
        if hasProblem { return .orange }
        if !isConnected { return Color(nsColor: .tertiaryLabelColor) }
        if hasFollowUps { return Color(red: 0.20, green: 0.48, blue: 0.95) }
        return Color(red: 0.13, green: 0.78, blue: 0.37)
    }
}
