import AppKit
import SwiftUI

/// Renders the menu bar glyph + status dot into a bitmap so the badge stays visible in the status bar.
@MainActor
enum MenuBarStatusIcon {
    private static let canvasSize: CGFloat = 18
    private static let symbolPointSize: CGFloat = 13

    static func makeNSImage(
        isPiecesConnected: Bool,
        attentionCount: Int,
        hasProblemItems: Bool
    ) -> NSImage? {
        let content = labelContent(
            isPiecesConnected: isPiecesConnected,
            attentionCount: attentionCount,
            hasProblemItems: hasProblemItems
        )
        .frame(width: canvasSize, height: canvasSize)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.size = NSSize(width: canvasSize, height: canvasSize)
        image.isTemplate = false
        return image
    }

    @ViewBuilder
    static func labelContent(
        isPiecesConnected: Bool,
        attentionCount: Int,
        hasProblemItems: Bool
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "puzzlepiece.fill")
                .font(.system(size: symbolPointSize, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color(nsColor: .labelColor))
                .frame(width: 15, height: 15)
                .offset(x: -0.5, y: 0.5)

            statusDot(
                isPiecesConnected: isPiecesConnected,
                attentionCount: attentionCount,
                hasProblemItems: hasProblemItems
            )
            .offset(x: 4, y: -3)
        }
    }

    @ViewBuilder
    private static func statusDot(
        isPiecesConnected: Bool,
        attentionCount: Int,
        hasProblemItems: Bool
    ) -> some View {
        let fill = dotFill(
            isPiecesConnected: isPiecesConnected,
            attentionCount: attentionCount,
            hasProblemItems: hasProblemItems
        )

        Circle()
            .fill(fill)
            .frame(width: 6.5, height: 6.5)
            .overlay {
                Circle()
                    .strokeBorder(dotRingColor, lineWidth: 1.25)
            }
            .shadow(color: .black.opacity(0.18), radius: 0.5, y: 0.5)
    }

    private static func dotFill(
        isPiecesConnected: Bool,
        attentionCount: Int,
        hasProblemItems: Bool
    ) -> Color {
        if hasProblemItems { return .orange }
        if !isPiecesConnected { return Color(nsColor: .tertiaryLabelColor) }
        if attentionCount > 0 { return Color(red: 0.20, green: 0.48, blue: 0.95) }
        return Color(red: 0.13, green: 0.78, blue: 0.37)
    }

    private static var dotRingColor: Color {
        Color(nsColor: .windowBackgroundColor)
    }
}
