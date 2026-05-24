import AppKit
import SwiftUI

/// Popover chrome — Liquid Glass on macOS 26+, vibrancy fallback on earlier releases.
enum PopoverGlassStyle {
    static let cornerRadius: CGFloat = 12
    static let listCornerRadius: CGFloat = 8
    static let borderOpacity: CGFloat = 0.38
    static let shadowRadius: CGFloat = 22
    static let shadowY: CGFloat = 10

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
}

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

    func updateNSView(_ nsView: PopoverWindowConfiguratorView, context: Context) {}
}

final class PopoverWindowConfiguratorView: NSView {
    private weak var configuredWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureIfNeeded()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        configureIfNeeded(force: true)
    }

    func configureIfNeeded(force: Bool = false) {
        guard let window else {
            configuredWindow = nil
            return
        }
        if !force, configuredWindow === window { return }
        configuredWindow = window
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.titlebarAppearsTransparent = true
        if let panel = window as? NSPanel {
            panel.isFloatingPanel = true
        }
    }
}

private enum PopoverSurface {
    case chrome
    case inset
}

private struct PopoverSurfaceModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let surface: PopoverSurface

    func body(content: Content) -> some View {
        switch surface {
        case .chrome:
            if reduceTransparency {
                content
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: PopoverGlassStyle.cornerRadius, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: PopoverGlassStyle.shadowRadius, y: PopoverGlassStyle.shadowY)
            } else if #available(macOS 26, *) {
                content
                    .background(PopoverWindowConfigurator())
                    .glassEffect(.regular, in: .rect(cornerRadius: PopoverGlassStyle.cornerRadius, style: .continuous))
                    .overlay { chromeBorder(cornerRadius: PopoverGlassStyle.cornerRadius) }
                    .shadow(color: Color.black.opacity(0.16), radius: PopoverGlassStyle.shadowRadius, y: PopoverGlassStyle.shadowY)
            } else {
                content
                    .background { GlassEffectView().ignoresSafeArea() }
                    .background(PopoverWindowConfigurator())
                    .clipShape(RoundedRectangle(cornerRadius: PopoverGlassStyle.cornerRadius, style: .continuous))
                    .overlay { chromeBorder(cornerRadius: PopoverGlassStyle.cornerRadius) }
                    .shadow(color: Color.black.opacity(0.2), radius: PopoverGlassStyle.shadowRadius, y: PopoverGlassStyle.shadowY)
            }
        case .inset:
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
                    .overlay { chromeBorder(cornerRadius: PopoverGlassStyle.listCornerRadius, opacity: 0.06) }
            }
        }
    }

    private func chromeBorder(cornerRadius: CGFloat, opacity: Double = PopoverGlassStyle.borderOpacity * 0.35) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.primary.opacity(opacity), lineWidth: 0.5)
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
        modifier(PopoverSurfaceModifier(surface: .chrome))
    }

    func popoverListPanel() -> some View {
        modifier(PopoverSurfaceModifier(surface: .inset))
    }

    func popoverToolbarButtonStyle() -> some View {
        modifier(PopoverToolbarButtonStyleModifier())
    }

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

    /// Settings uses a real `NSWindow`; avoid popover glass/container loops on that surface.
    func settingsWindowBackground() -> some View {
        background {
            GlassEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
    }
}
