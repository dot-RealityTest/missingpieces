import AppKit
import SwiftUI

struct RootPopoverView: View {
    @Environment(AppState.self) var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var emptyAppearToken = 0

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
        }
    }

    // MARK: - Chrome

    @ViewBuilder
    private var topChrome: some View {
        VStack(spacing: 0) {
            headerBar
            if let error = appState.lastPiecesError, appState.hasProblemItems {
                issueBanner(error, icon: "exclamationmark.triangle")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.expand), value: appState.hasProblemItems)
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
        if !appState.isPiecesConnected { return "Start Pieces OS to see recent work" }
        if appState.attentionCount == 0 { return "You're caught up" }
        if appState.hasNextStepsOnly {
            var parts = ["\(appState.attentionCount) still open"]
            if appState.dismissedFollowUpCount > 0 {
                parts.append("\(appState.dismissedFollowUpCount) marked done")
            }
            return parts.joined(separator: " · ")
        }
        return "\(appState.attentionCount) need attention"
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
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
                } else if appState.attentionCount == 0 {
                    emptyState
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(appState.attentionSections.enumerated()), id: \.element.id) { index, section in
                            sectionView(
                                section,
                                accent: SectionAccentPalette.color(sectionIndex: index),
                                isFirst: index == 0
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                    .padding(.bottom, 6)
                    .transition(.opacity)
                }
            }
            .padding(.bottom, 4)
            .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.expand), value: scrollContentPhase)
        }
        .scrollIndicators(.automatic)
        .popoverListPanel()
        .onChange(of: scrollContentPhase) { oldPhase, phase in
            if phase == "empty", oldPhase != "empty", !reduceMotion {
                emptyAppearToken += 1
            }
        }
    }

    private var scrollContentPhase: String {
        if appState.isLoading && appState.attentionSections.isEmpty { return "loading" }
        if appState.attentionCount == 0 { return "empty" }
        return "list-\(appState.attentionCount)"
    }

    @ViewBuilder
    private func sectionView(_ section: AttentionSection, accent: Color, isFirst: Bool) -> some View {
        let usesAccent = section.items.allSatisfy { $0.reason == .nextStep }

        if !section.sessionName.isEmpty, usesAccent {
            Text(PiecesNextStepsParser.sessionName(section.sessionName))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(accent.opacity(0.72))
                .lineLimit(1)
                .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
                .padding(.top, isFirst ? 4 : 10)
                .padding(.bottom, 2)
        }

        ForEach(section.items) { item in
            MissingRowView(
                item: item,
                showsSessionName: section.sessionName.isEmpty,
                onMarkDone: item.reason == .nextStep
                    ? { appState.dismissFollowUp(id: item.id) }
                    : nil,
                sectionAccent: item.reason == .nextStep ? accent : nil
            )
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .leading))
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
                .symbolEffect(.bounce, options: .nonRepeating, value: emptyAppearToken)

            Text("You're caught up")
                .font(.subheadline)
                .fontWeight(.semibold)

            Text("No open next steps from recent work.")
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

            Spacer(minLength: 0)

            if appState.isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .transition(.opacity)
            }
        }
        .animation(PopoverMotion.animation(reduceMotion: reduceMotion, PopoverMotion.quick), value: appState.isLoading)
        .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding)
        .padding(.vertical, PopoverGlassStyle.chromeVerticalPadding)
        .overlay(alignment: .top) {
            PopoverGlassStyle.sectionDivider
                .frame(height: 0.5)
        }
    }

    private var bottomStatusText: String {
        if appState.isLoading { return "Checking Pieces…" }
        if appState.attentionCount == 0 { return "All clear" }
        if appState.attentionCount > 0 {
            return "Click to expand · double-click to copy"
        }
        return "\(appState.attentionCount) to review"
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
