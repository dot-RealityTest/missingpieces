import AppKit
import SwiftUI

/// Popover chrome — Liquid Glass on macOS 26+, vibrancy fallback on earlier releases.
enum PopoverGlassStyle {
    static let cornerRadius: CGFloat = 12
    static let listCornerRadius: CGFloat = 8
    static let borderOpacity: CGFloat = 0.38
    static let shadowRadius: CGFloat = 22
    static let shadowY: CGFloat = 10

    /// Shared chrome spacing for header, summary, and footer.
    static let chromeHorizontalPadding: CGFloat = 10
    static let chromeVerticalPadding: CGFloat = 7
    static let toolbarIconSize: CGFloat = 13
    static let toolbarHitSize: CGFloat = 24

    static var sectionDivider: Color {
        Color.primary.opacity(0.1)
    }

    static var insetPanelFill: Color {
        Color.primary.opacity(0.045)
    }

    static var usesLiquidGlass: Bool {
        if #available(macOS 26, *) {
            return true
        }
        return false
    }
}

// MARK: - Legacy vibrancy (macOS 14–25)

struct GlassEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

struct PopoverWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> PopoverWindowConfiguratorView {
        PopoverWindowConfiguratorView()
    }

    func updateNSView(_ nsView: PopoverWindowConfiguratorView, context: Context) {
        nsView.configure()
    }
}

final class PopoverWindowConfiguratorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configure()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        configure()
    }

    func configure() {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        if let panel = window as? NSPanel {
            panel.isFloatingPanel = true
        }
    }
}

// MARK: - Modifiers

private struct PopoverGlassChromeModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: PopoverGlassStyle.cornerRadius, style: .continuous))
                .shadow(
                    color: Color.black.opacity(0.18),
                    radius: PopoverGlassStyle.shadowRadius,
                    y: PopoverGlassStyle.shadowY
                )
        } else if #available(macOS 26, *) {
            content
                .background(PopoverWindowConfigurator())
                .glassEffect(
                    .regular,
                    in: .rect(cornerRadius: PopoverGlassStyle.cornerRadius, style: .continuous)
                )
                .overlay { popoverBorder }
                .shadow(
                    color: Color.black.opacity(0.16),
                    radius: PopoverGlassStyle.shadowRadius,
                    y: PopoverGlassStyle.shadowY
                )
        } else {
            content
                .background {
                    GlassEffectView()
                        .ignoresSafeArea()
                }
                .background(PopoverWindowConfigurator())
                .clipShape(RoundedRectangle(cornerRadius: PopoverGlassStyle.cornerRadius, style: .continuous))
                .overlay { popoverBorder }
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: PopoverGlassStyle.shadowRadius,
                    y: PopoverGlassStyle.shadowY
                )
        }
    }

    private var popoverBorder: some View {
        RoundedRectangle(cornerRadius: PopoverGlassStyle.cornerRadius, style: .continuous)
            .strokeBorder(
                Color.primary.opacity(PopoverGlassStyle.borderOpacity * 0.35),
                lineWidth: 0.5
            )
    }
}

private struct PopoverListPanelModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: PopoverGlassStyle.listCornerRadius, style: .continuous))
        } else if #available(macOS 26, *) {
            content
                .clipShape(RoundedRectangle(cornerRadius: PopoverGlassStyle.listCornerRadius, style: .continuous))
        } else {
            content
                .background(PopoverGlassStyle.insetPanelFill)
                .clipShape(RoundedRectangle(cornerRadius: PopoverGlassStyle.listCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PopoverGlassStyle.listCornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                }
        }
    }
}

private struct PopoverSummaryGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: PopoverGlassStyle.listCornerRadius, style: .continuous))
        } else if #available(macOS 26, *) {
            content
                .glassEffect(
                    .regular.tint(.purple.opacity(0.22)),
                    in: .rect(cornerRadius: PopoverGlassStyle.listCornerRadius, style: .continuous)
                )
        } else {
            content
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: PopoverGlassStyle.listCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: PopoverGlassStyle.listCornerRadius, style: .continuous)
                        .strokeBorder(Color.purple.opacity(0.15), lineWidth: 0.5)
                }
        }
    }
}

private struct PopoverToolbarButtonStyleModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .font(.system(size: PopoverGlassStyle.toolbarIconSize, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(
                width: PopoverGlassStyle.toolbarHitSize,
                height: PopoverGlassStyle.toolbarHitSize
            )
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
            }
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
    }
}

extension View {
    func popoverGlassChrome() -> some View {
        modifier(PopoverGlassChromeModifier())
    }

    /// Same glass shell as the menu bar popover (Settings window).
    func settingsGlassChrome() -> some View {
        modifier(PopoverGlassChromeModifier())
    }

    func popoverListPanel() -> some View {
        modifier(PopoverListPanelModifier())
    }

    func popoverSummaryGlass() -> some View {
        modifier(PopoverSummaryGlassModifier())
    }

    func popoverToolbarButtonStyle() -> some View {
        modifier(PopoverToolbarButtonStyleModifier())
    }

    /// Groups nested glass surfaces (summary chip, etc.) on macOS 26+.
    @ViewBuilder
    func popoverGlassContentGroup() -> some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                self
            }
        } else {
            self
        }
    }
}
