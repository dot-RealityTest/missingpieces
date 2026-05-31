import SwiftUI

private enum SettingsLayout {
    static let width: CGFloat = 480
    /// Fits hero + three sections + footer without a tall empty scroll area.
    static func height(markedDoneCount: Int) -> CGFloat {
        markedDoneCount > 0 ? 368 : 292
    }
}

struct SettingsView: View {
    @Bindable var appState: AppState
    @Bindable var appSettings: AppSettings
    var onDismiss: () -> Void

    @State private var settingsRefreshTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            settingsHero
                .overlay(alignment: .bottom) {
                    PopoverGlassStyle.sectionDivider
                        .frame(height: 0.5)
                        .padding(.horizontal, 12)
                }

            settingsForm
                .padding(12)

            settingsFooter
                .overlay(alignment: .top) {
                    PopoverGlassStyle.sectionDivider
                        .frame(height: 0.5)
                }
        }
        .frame(
            width: SettingsLayout.width,
            height: SettingsLayout.height(markedDoneCount: appSettings.dismissedFollowUpCount)
        )
        .settingsWindowBackground()
        .controlSize(.small)
        .onDisappear {
            settingsRefreshTask?.cancel()
            settingsRefreshTask = nil
        }
        .onChange(of: appSettings.lookbackDays) { _, _ in
            scheduleSettingsRefresh()
        }
        .onChange(of: appSettings.visibleItemLimit) { _, _ in
            scheduleSettingsRefresh()
        }
    }

    private var settingsHero: some View {
        HStack(spacing: 10) {
            AppStatusGlyphView(
                isPiecesConnected: appState.isPiecesConnected,
                attentionCount: appState.attentionCount,
                hasProblemItems: appState.hasProblemItems,
                glyphSize: 20,
                dotSize: 6,
                dotOffset: CGSize(width: 2, height: -1)
            )
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("missingpieces")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary.opacity(0.72))
                Text(appState.isPiecesConnected ? "Pieces OS connected" : "Pieces OS offline")
                    .font(.caption2)
                    .foregroundStyle(Color.primary.opacity(0.38))
            }

            Spacer(minLength: 0)

            Text(appVersion)
                .font(.caption2)
                .foregroundStyle(Color.primary.opacity(0.32))

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
            }
            .popoverToolbarButtonStyle()
            .help("Close")
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, PopoverGlassStyle.chromeHorizontalPadding + 6)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var settingsForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsGlassSection {
                SettingsToggleRow(
                    title: "Check Pieces when I open the list",
                    isOn: $appSettings.refreshOnPopoverOpen
                )
            }

            SettingsGlassSection {
                SettingsPickerRow(title: "Lookback", selection: $appSettings.lookbackDays) {
                    Text("3 days").tag(3)
                    Text("1 week").tag(7)
                    Text("2 weeks").tag(14)
                }
                SettingsSectionDivider()
                SettingsPickerRow(title: "Show up to", selection: $appSettings.visibleItemLimit) {
                    ForEach(AppSettings.visibleLimitOptions, id: \.self) { n in
                        Text("\(n) follow-ups").tag(n)
                    }
                }
            }

            SettingsGlassSection {
                Button {
                    Task { await appState.refreshMissingFromPieces() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("Refresh list")
                            .font(.system(size: 12.5))
                        Spacer(minLength: 0)
                        if appState.isLoading {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                    .foregroundStyle(SettingsTheme.label)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(appState.isLoading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                if !statusLine.isEmpty {
                    SettingsSectionDivider()
                    Text(statusLine)
                        .font(.caption2)
                        .foregroundStyle(SettingsTheme.secondaryLabel)
                        .lineLimit(3)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }

            if appSettings.dismissedFollowUpCount > 0 {
                SettingsGlassSection {
                    SettingsLabeledRow(title: "Marked done") {
                        Text("\(appSettings.dismissedFollowUpCount)")
                            .font(.caption)
                            .foregroundStyle(SettingsTheme.secondaryLabel)
                    }
                    SettingsSectionDivider()
                    SettingsActionRow(
                        title: "Show them again",
                        systemImage: "eye"
                    ) {
                        Task { await appState.restoreDismissedFollowUps() }
                    }
                }
            }
        }
    }

    private var settingsFooter: some View {
        HStack {
            Spacer(minLength: 0)
            Button("Done") {
                onDismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .font(.system(size: 12.5))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var statusLine: String {
        var parts: [String] = []
        if appState.attentionCount > 0, appState.hasNextStepsOnly {
            parts.append("\(appState.attentionCount) in list")
        }
        if let checked = appState.lastPiecesCheckDate {
            parts.append("Updated \(checked.formatted(date: .omitted, time: .shortened))")
        }
        return parts.joined(separator: " · ")
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    private func scheduleSettingsRefresh() {
        settingsRefreshTask?.cancel()
        settingsRefreshTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await appState.refreshMissingFromPieces()
        }
    }
}
