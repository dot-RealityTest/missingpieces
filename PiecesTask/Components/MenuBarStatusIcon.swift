import AppKit
import SwiftUI

/// Renders the menu bar glyph + status dot into a bitmap so the badge stays visible in the status bar.
@MainActor
enum MenuBarStatusIcon {
    private static let canvasSize: CGFloat = 18
    private static let glyphSide: CGFloat = 16

    private static func loadAppGlyph() -> NSImage? {
        if let image = Bundle.main.image(forResource: NSImage.Name("MenuBarIcon")) {
            return image
        }
        if let icon = NSApplication.shared.applicationIconImage {
            return icon
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            return icon
        }
        return nil
    }

    static func makeNSImage(
        isPiecesConnected: Bool,
        attentionCount: Int,
        hasProblemItems: Bool
    ) -> NSImage? {
        let fill = dotFill(
            isPiecesConnected: isPiecesConnected,
            attentionCount: attentionCount,
            hasProblemItems: hasProblemItems
        )
        let glyph = loadAppGlyph()

        let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize), flipped: false) { _ in
            if let glyph {
                let rect = NSRect(
                    x: (canvasSize - glyphSide) / 2,
                    y: (canvasSize - glyphSide) / 2,
                    width: glyphSide,
                    height: glyphSide
                )
                sized(glyph).draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0, respectFlipped: false, hints: [
                    .interpolation: NSImageInterpolation.high
                ])
            } else {
                drawFallbackGlyph()
            }

            drawStatusDot(fill: fill)
            return true
        }
        image.isTemplate = false
        return image
    }

    @ViewBuilder
    static func labelContent(
        isPiecesConnected: Bool,
        attentionCount: Int,
        hasProblemItems: Bool
    ) -> some View {
        AppStatusGlyphView(
            isPiecesConnected: isPiecesConnected,
            attentionCount: attentionCount,
            hasProblemItems: hasProblemItems
        )
    }

    private static func sized(_ image: NSImage) -> NSImage {
        let copy = (image.copy() as? NSImage) ?? image
        copy.size = NSSize(width: glyphSide, height: glyphSide)
        return copy
    }

    private static func drawFallbackGlyph() {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        if let symbol = NSImage(systemSymbolName: "puzzlepiece.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let side: CGFloat = 13
            let rect = NSRect(
                x: (canvasSize - side) / 2,
                y: (canvasSize - side) / 2,
                width: side,
                height: side
            )
            symbol.draw(in: rect)
        }
    }

    private static func drawStatusDot(fill: Color) {
        let diameter: CGFloat = 6.5
        let rect = NSRect(
            x: canvasSize - diameter + 1,
            y: canvasSize - diameter - 1,
            width: diameter,
            height: diameter
        )

        fill.nsColor.setFill()
        NSBezierPath(ovalIn: rect).fill()

        NSColor.windowBackgroundColor.setStroke()
        let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 0.4, dy: 0.4))
        ring.lineWidth = 1.25
        ring.stroke()
    }

    static func dotFill(
        isPiecesConnected: Bool,
        attentionCount: Int,
        hasProblemItems: Bool
    ) -> Color {
        if hasProblemItems { return .orange }
        if !isPiecesConnected { return Color(nsColor: .tertiaryLabelColor) }
        if attentionCount > 0 { return Color(red: 0.20, green: 0.48, blue: 0.95) }
        return Color(red: 0.13, green: 0.78, blue: 0.37)
    }

    fileprivate static var dotRingColor: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    @ViewBuilder
    fileprivate static func statusDotView(
        isPiecesConnected: Bool,
        attentionCount: Int,
        hasProblemItems: Bool,
        size: CGFloat
    ) -> some View {
        let fill = dotFill(
            isPiecesConnected: isPiecesConnected,
            attentionCount: attentionCount,
            hasProblemItems: hasProblemItems
        )

        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .strokeBorder(dotRingColor, lineWidth: 1.25)
            }
            .shadow(color: .black.opacity(0.18), radius: 0.5, y: 0.5)
    }
}

/// Shared app icon + connection dot used in the menu bar and popover header.
struct AppStatusGlyphView: View {
    var isPiecesConnected: Bool
    var attentionCount: Int
    var hasProblemItems: Bool
    var glyphSize: CGFloat = 16
    var dotSize: CGFloat = 6.5
    var dotOffset: CGSize = CGSize(width: 3, height: -2)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            appGlyph
                .frame(width: glyphSize, height: glyphSize)

            MenuBarStatusIcon.statusDotView(
                isPiecesConnected: isPiecesConnected,
                attentionCount: attentionCount,
                hasProblemItems: hasProblemItems,
                size: dotSize
            )
            .offset(dotOffset)
        }
    }

    @ViewBuilder
    private var appGlyph: some View {
        if Bundle.main.image(forResource: NSImage.Name("MenuBarIcon")) != nil {
            Image("MenuBarIcon")
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "puzzlepiece.fill")
                .font(.system(size: glyphSize * 0.78, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color(nsColor: .labelColor))
        }
    }
}

private extension Color {
    var nsColor: NSColor {
        NSColor(self)
    }
}
