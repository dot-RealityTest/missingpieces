import AppKit
import SwiftUI

/// Read-only row — follow-up from Pieces or a connection problem. Click expands; double-click copies.
struct MissingRowView: View {
    let item: AttentionItem
    /// When the list is grouped by session, the section header already shows the session name.
    var showsSessionName: Bool = true
    var onMarkDone: (() -> Void)?
    /// Pastel tint for follow-up row icons when grouped by work session.
    var sectionAccent: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var didCopy = false

    private var canExpand: Bool {
        guard item.reason == .nextStep else { return false }
        return expandedContent != nil
    }

    private var expandedContent: String? {
        PiecesNextStepsParser.displayExpandedContent(from: item.copyText)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            leadingAccessory

            VStack(alignment: .leading, spacing: isExpanded ? 6 : 2) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: titleWeight))
                    .foregroundStyle(titleColor)
                    .lineLimit(item.reason == .nextStep ? 1 : (isExpanded ? nil : 1))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                rowSecondaryContent
            }

            trailingFeedback
        }
        .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
        .padding(.vertical, isExpanded ? 8 : 5)
        .background(rowBackground)
        .overlay(rowBorder)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.expand), value: isExpanded)
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.quick), value: isHovering)
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.feedback), value: didCopy)
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { copyTitle() }
        .onTapGesture(count: 1) { handleSingleTap() }
        .contextMenu { rowContextMenu }
        .help(helpText)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isExpanded ? .isSelected : [])
        .accessibilityHint(helpText)
    }

    @ViewBuilder
    private var leadingAccessory: some View {
        Image(systemName: item.reason.icon)
            .font(.caption)
            .foregroundStyle(leadingIconColor)
            .symbolRenderingMode(.hierarchical)
            .frame(width: 18)
    }

    private var leadingIconColor: Color {
        if item.reason == .nextStep, let sectionAccent {
            return sectionAccent.opacity(isExpanded ? 0.88 : (isHovering ? 0.72 : 0.52))
        }
        if item.reason == .nextStep {
            return Color.primary.opacity(isHovering ? 0.55 : 0.4)
        }
        return reasonColor.opacity(isHovering ? 0.95 : 0.78)
    }

    @ViewBuilder
    private var rowSecondaryContent: some View {
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
        } else if item.reason == .nextStep, isExpanded, canExpand {
            expandedBody
                .transition(PopoverMotion.revealTransition(reduceMotion: reduceMotion))
        } else if item.reason == .nextStep, let detail = item.detail, !detail.isEmpty {
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(Color.primary.opacity(0.38))
                .lineLimit(1)
        } else if showsSessionName, let detail = item.detail, !detail.isEmpty {
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(detailColor)
                .lineLimit(1)
        }
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            PopoverGlassStyle.sectionDivider
                .frame(height: 0.5)

            if let expandedContent {
                Text(expandedContent)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.primary.opacity(0.54))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private var trailingFeedback: some View {
        if didCopy {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.green.opacity(0.92))
                .frame(width: 14, height: 14)
                .transition(.opacity)
        } else {
            Color.clear.frame(width: 14, height: 14)
        }
    }

    @ViewBuilder
    private var rowBorder: some View {
        if isExpanded, canExpand {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var rowContextMenu: some View {
        if item.reason == .nextStep, onMarkDone != nil {
            Button("Mark done") { markDone() }
        }
        Button("Copy") { copyTitle() }
    }

    private var titleWeight: Font.Weight {
        item.reason == .nextStep ? .regular : .medium
    }

    private var titleColor: Color {
        switch item.reason {
        case .nextStep:
            return Color.primary.opacity(isExpanded || isHovering ? 0.94 : 0.86)
        case .piecesUnavailable, .fetchFailed:
            return Color.primary.opacity(isHovering ? 0.82 : 0.62)
        }
    }

    private var detailColor: Color {
        Color.secondary.opacity(isHovering ? 1 : 0.92)
    }

    private var rowBackground: Color {
        if didCopy { return Color.green.opacity(0.08) }
        if isExpanded { return Color.primary.opacity(0.055) }
        if isHovering { return Color.primary.opacity(0.04) }
        return .clear
    }

    private var helpText: String {
        if didCopy { return "Copied" }
        if canExpand {
            return isExpanded
                ? "Click to collapse · double-click to copy"
                : "Click to expand · double-click to copy"
        }
        if item.reason == .nextStep {
            return "Click or double-click to copy"
        }
        return "Double-click to copy"
    }

    private var reasonColor: Color {
        switch item.reason {
        case .piecesUnavailable, .fetchFailed:
            return .red
        case .nextStep:
            return Color.primary.opacity(0.4)
        }
    }

    private func handleSingleTap() {
        if canExpand {
            PopoverMotion.perform(reduceMotion: reduceMotion, PopoverMotion.expand) {
                isExpanded.toggle()
            }
        } else {
            copyTitle()
        }
    }

    private func markDone() {
        guard item.reason == .nextStep, let onMarkDone else { return }
        PopoverMotion.perform(reduceMotion: reduceMotion, PopoverMotion.expand) {
            isExpanded = false
            onMarkDone()
        }
    }

    private func copyTitle() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.copyText, forType: .string)

        PopoverMotion.perform(reduceMotion: reduceMotion, PopoverMotion.feedback) {
            didCopy = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.75))
            PopoverMotion.perform(reduceMotion: reduceMotion, PopoverMotion.quick) {
                didCopy = false
            }
        }
    }
}
