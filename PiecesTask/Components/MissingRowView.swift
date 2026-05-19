import AppKit
import SwiftUI

/// Read-only row — follow-up from Pieces or a connection problem. Click copies the text.
struct MissingRowView: View {
    let item: AttentionItem
    /// When the list is grouped by session, the section header already shows the session name.
    var showsSessionName: Bool = true
    var onHide: (() -> Void)?

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
                .scaleEffect(didCopy ? 1.06 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: item.reason == .nextStep ? .regular : .semibold))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                if item.reason.isProblem {
                    Text(item.reason.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(reasonColor)

                    if let detail = item.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else if showsSessionName, let detail = item.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
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
        .scaleEffect(isHovering && !didCopy ? 1.002 : 1.0)
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.quick), value: isHovering)
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
            Button("Hide") { hideRow(onHide) }
        }
    }

    private var leadingIcon: String {
        if didCopy { return "checkmark.circle.fill" }
        return item.reason.icon
    }

    private var leadingIconColor: Color {
        if didCopy { return .green }
        return reasonColor
    }

    private var rowBackground: Color {
        if didCopy { return Color.green.opacity(PopoverGlassStyle.usesLiquidGlass ? 0.18 : 0.14) }
        if isHovering { return Color.primary.opacity(PopoverGlassStyle.usesLiquidGlass ? 0.1 : 0.08) }
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
            return .blue
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

    private func hideRow(_ action: () -> Void) {
        PopoverMotion.perform(reduceMotion: reduceMotion) {
            action()
        }
    }
}
