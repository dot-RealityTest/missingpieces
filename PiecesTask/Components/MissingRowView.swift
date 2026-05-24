import AppKit
import SwiftUI

/// Read-only row — follow-up from Pieces or a connection problem. Click copies the text.
struct MissingRowView: View {
    let item: AttentionItem
    /// When the list is grouped by session, the section header already shows the session name.
    var showsSessionName: Bool = true
    var onHide: (() -> Void)?
    /// Pastel tint for follow-up rows when grouped by work session.
    var sectionAccent: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: leadingIcon)
                .font(.caption)
                .foregroundStyle(leadingIconColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 18)
                .contentTransition(.symbolEffect(.replace.downUp))
                .symbolEffect(.bounce, value: didCopy)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: item.reason == .nextStep ? .regular : .medium))
                    .foregroundStyle(titleColor)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.interpolate)

                if item.reason.isProblem {
                    Text(item.reason.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(reasonColor.opacity(isHovering ? 1 : 0.85))

                    if let detail = item.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 10))
                            .foregroundStyle(detailColor)
                            .lineLimit(2)
                    }
                } else if showsSessionName, let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(detailColor)
                        .lineLimit(1)
                }
            }

            if didCopy {
                Text("Copied")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
        .padding(.vertical, 5)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .offset(x: rowHoverOffset)
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: isHovering)
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.spring), value: didCopy)
        .contentShape(Rectangle())
        .onHover { hovering in
            PopoverMotion.perform(reduceMotion: reduceMotion, PopoverMotion.quick) {
                isHovering = hovering
            }
        }
        .onTapGesture { copyTitle() }
        .contextMenu { rowContextMenu }
        .help(helpText)
    }

    @ViewBuilder
    private var rowContextMenu: some View {
        Button("Copy") { copyTitle() }
        if item.reason == .nextStep, let onHide {
            Divider()
            Button("Hide") { runRowAction(onHide) }
        }
    }

    private var leadingIcon: String {
        if didCopy { return "checkmark.circle.fill" }
        return item.reason.icon
    }

    private var leadingIconColor: Color {
        if didCopy { return .green.opacity(0.9) }
        if item.reason == .nextStep, let sectionAccent {
            return sectionAccent.opacity(isHovering ? 0.82 : 0.52)
        }
        if item.reason == .nextStep {
            return Color.primary.opacity(isHovering ? 0.55 : 0.4)
        }
        return reasonColor.opacity(isHovering ? 0.95 : 0.78)
    }

    private var iconScale: CGFloat {
        if didCopy { return 1.05 }
        if isHovering { return 1.03 }
        return 1.0
    }

    private var iconOpacity: Double {
        if didCopy { return 1 }
        if isHovering { return 1 }
        return item.reason == .nextStep ? 0.88 : 0.92
    }

    private var rowHoverOffset: CGFloat {
        guard isHovering, !didCopy else { return 0 }
        return reduceMotion ? 0 : 1
    }

    private var titleColor: Color {
        if didCopy { return Color.primary.opacity(0.78) }
        switch item.reason {
        case .nextStep:
            return Color.primary.opacity(isHovering ? 1 : 0.88)
        case .piecesUnavailable, .fetchFailed:
            return Color.primary.opacity(isHovering ? 0.82 : 0.62)
        }
    }

    private var detailColor: Color {
        Color.secondary.opacity(isHovering ? 1 : 0.92)
    }

    private var rowBackground: Color {
        if didCopy { return Color.green.opacity(PopoverGlassStyle.usesLiquidGlass ? 0.14 : 0.11) }
        if isHovering {
            return Color.primary.opacity(PopoverGlassStyle.usesLiquidGlass ? 0.06 : 0.05)
        }
        return .clear
    }

    private var helpText: String {
        if didCopy { return "Copied" }
        if item.reason == .nextStep {
            return "Click to copy · right-click to hide"
        }
        return "Click to copy"
    }

    private var reasonColor: Color {
        switch item.reason {
        case .piecesUnavailable, .fetchFailed:
            return .red
        case .nextStep:
            return Color.primary.opacity(0.4)
        }
    }

    private func copyTitle() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.title, forType: .string)

        PopoverMotion.perform(reduceMotion: reduceMotion, PopoverMotion.spring) {
            didCopy = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            PopoverMotion.perform(reduceMotion: reduceMotion, PopoverMotion.gentle) {
                didCopy = false
            }
        }
    }

    private func runRowAction(_ action: () -> Void) {
        PopoverMotion.perform(reduceMotion: reduceMotion) {
            action()
        }
    }
}
