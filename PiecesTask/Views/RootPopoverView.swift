import AppKit
import SwiftUI

struct RootPopoverView: View {
    @Environment(AppState.self) var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFooterHovering = false

    private var popoverSize: CGSize { PopoverLayout.size }

    var body: some View {
        VStack(spacing: 0) {
            topChrome

            scrollContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomBar
        }
        .popoverGlassContentGroup()
        .padding(PopoverLayout.edgeInsets)
        .frame(width: popoverSize.width, height: popoverSize.height, alignment: .top)
        .popoverGlassChrome()
        .task {
            if AppSettings.shared.refreshOnPopoverOpen {
                await appState.refreshMissingFromPieces()
            } else {
                await appState.probePiecesConnection()
            }
        }
        .onDisappear {
            appState.cancelRefresh()
            appState.cancelSummary()
        }
    }

    // MARK: - Chrome

    @ViewBuilder
    private var topChrome: some View {
        VStack(spacing: 0) {
            headerBar
            if let undo = appState.undoOffer {
                PopoverUndoBanner(message: undo.message) {
                    Task { await appState.performUndo() }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let error = appState.lastPiecesError, appState.hasProblemItems {
                issueBanner(error, icon: "exclamationmark.triangle")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if showsSummaryPanel {
                FollowUpSummaryPanel(
                    brief: appState.ollamaSummaryBrief,
                    followUpTitles: appState.summaryFollowUpTitles,
                    isExpanded: appState.isOllamaSummaryExpanded,
                    isExpandable: appState.ollamaSummaryIsExpandable,
                    error: appState.ollamaSummaryError,
                    isLoading: appState.isGeneratingOllamaSummary,
                    onToggleExpand: {
                        appState.toggleOllamaSummaryExpanded()
                    },
                    onDismiss: {
                        appState.clearOllamaSummary()
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: showsSummaryPanel)
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: appState.hasProblemItems)
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: appState.undoOffer)
    }

    private var showsSummaryPanel: Bool {
        appState.isGeneratingOllamaSummary
            || appState.ollamaSummaryBrief != nil
            || appState.ollamaSummaryError != nil
    }

    private var canSummarizeWithOllama: Bool {
        AppSettings.shared.canUseOllamaSummary && appState.attentionCount > 0 && appState.hasNextStepsOnly
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            AppStatusGlyphView(
                isPiecesConnected: appState.isPiecesConnected,
                attentionCount: appState.attentionCount,
                hasProblemItems: appState.hasProblemItems,
                glyphSize: 22,
                dotSize: 6.5,
                dotOffset: CGSize(width: 2, height: -1)
            )
            .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text("What you're missing")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(headerSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .contentTransition(.interpolate)
                    .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: headerSubtitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            headerToolbar
        }
        .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
        .padding(.vertical, PopoverGlassStyle.chromeVerticalPadding)
        .overlay(alignment: .bottom) {
            PopoverGlassStyle.sectionDivider
                .frame(height: 0.5)
        }
    }

    private var headerToolbar: some View {
        HStack(spacing: 0) {
            if appState.attentionCount > 0, appState.hasNextStepsOnly {
                Button {
                    _ = appState.copyAllVisibleFollowUpsToPasteboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .popoverToolbarButtonStyle()
                .help("Copy all visible follow-ups")
            }

            if canSummarizeWithOllama {
                Button {
                    Task { await appState.summarizeFollowUps() }
                } label: {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(appState.isGeneratingOllamaSummary ? .purple : .secondary)
                        .symbolEffect(.variableColor.iterative, isActive: appState.isGeneratingOllamaSummary && !reduceMotion)
                }
                .popoverToolbarButtonStyle()
                .disabled(appState.isGeneratingOllamaSummary)
                .help("Summarize follow-ups with Ollama")
            }

            RefreshPiecesButton(
                isLoading: appState.isLoading,
                isEnabled: true,
                action: recheck
            )

            Button {
                SettingsWindowPresenter.shared.open()
            } label: {
                Image(systemName: "gearshape")
                    .symbolRenderingMode(.hierarchical)
            }
            .popoverToolbarButtonStyle()
            .help("Settings (⌘,)")
        }
    }

    private var headerSubtitle: String {
        if !appState.isPiecesConnected { return "Pieces OS is off" }
        if appState.attentionCount == 0 { return "Nothing slipping through" }
        if appState.hasNextStepsOnly {
            let n = appState.attentionCount
            var text = "\(n) follow-up\(n == 1 ? "" : "s") · last week"
            if appState.hiddenNextStepsCount > 0 {
                text += " (+\(appState.hiddenNextStepsCount) more)"
            }
            if appState.dismissedFollowUpCount > 0 {
                text += " · \(appState.dismissedFollowUpCount) hidden"
            }
            return text
        }
        return "\(appState.attentionCount) to fix"
    }

    private func issueBanner(_ message: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - List

    private var scrollContent: some View {
        ScrollView {
            Group {
                if appState.isLoading && appState.attentionSections.isEmpty {
                    ProgressView("Reading Pieces…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .transition(.opacity)
                } else if appState.attentionCount == 0 {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(appState.attentionSections.enumerated()), id: \.element.id) { index, section in
                            sectionView(section, accent: SectionAccentPalette.color(sectionIndex: index))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .padding(.bottom, 6)
                    .transition(.opacity)
                }
            }
            .padding(.bottom, 4)
            .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: appState.attentionCount)
            .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.quick), value: appState.isLoading)
        }
        .scrollIndicators(.automatic)
        .popoverListPanel()
    }

    @ViewBuilder
    private func sectionView(_ section: AttentionSection, accent: Color) -> some View {
        let usesAccent = section.items.allSatisfy { $0.reason == .nextStep }

        if !section.sessionName.isEmpty, usesAccent {
            Text(section.sessionName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.primary.opacity(0.42))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 2)
        }

        ForEach(section.items) { item in
            MissingRowView(
                item: item,
                showsSessionName: section.sessionName.isEmpty,
                onHide: item.reason == .nextStep
                    ? {
                        appState.dismissFollowUp(
                            id: item.id,
                            title: item.title,
                            sessionName: item.detail ?? section.sessionName
                        )
                    }
                    : nil,
                sectionAccent: item.reason == .nextStep ? accent : nil
            )
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .leading))
                )
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.bounce, value: appState.attentionCount == 0)

            Text("You're caught up")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("No open next steps in recent Pieces sessions.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var bottomBar: some View {
        HStack(spacing: 6) {
            Text(bottomStatusText)
                .font(.caption2)
                .foregroundStyle(bottomStatusColor)
                .lineLimit(1)
                .contentTransition(.interpolate)
                .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.gentle), value: bottomStatusText)

            Spacer(minLength: 0)

            if appState.isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .opacity(isFooterHovering ? 1 : 0.55)
            }
        }
        .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
        .padding(.vertical, PopoverGlassStyle.chromeVerticalPadding)
        .background(Color.primary.opacity(isFooterHovering && !appState.isLoading ? 0.04 : 0))
        .contentShape(Rectangle())
        .onHover { isFooterHovering = $0 }
        .onTapGesture {
            guard !appState.isLoading else { return }
            recheck()
        }
        .help("Refresh from Pieces")
        .overlay(alignment: .top) {
            PopoverGlassStyle.sectionDivider
                .frame(height: 0.5)
        }
    }

    private var bottomStatusText: String {
        if appState.isLoading { return "Checking Pieces…" }
        if appState.attentionCount == 0 { return "All clear" }
        if appState.hiddenNextStepsCount > 0 {
            let total = appState.attentionCount + appState.hiddenNextStepsCount
            return "\(appState.attentionCount) of \(total) shown · tap row to copy"
        }
        if appState.attentionCount > 0 {
            return "\(appState.attentionCount) follow-ups · tap row to copy"
        }
        return "\(appState.attentionCount) to look at"
    }

    private var bottomStatusColor: Color {
        if appState.attentionCount == 0 { return .green }
        if appState.hasNextStepsOnly { return .secondary }
        return .orange
    }

    private func recheck() {
        Task { await appState.refreshMissingFromPieces() }
    }
}
