import SwiftUI
import UserNotifications

private enum SettingsLayout {
    static let width: CGFloat = 560
    static let height: CGFloat = 460
    /// Content below the tab bar.
    static let contentHeight: CGFloat = 388
}

struct SettingsView: View {
    @Bindable var appState: AppState
    @Bindable var appSettings: AppSettings

    @State private var reminderAuthStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(spacing: 0) {
            settingsHero
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    PopoverGlassStyle.sectionDivider
                        .frame(height: 0.5)
                        .padding(.horizontal, 12)
                }

            TabView {
                generalTab
                    .tabItem { Label("General", systemImage: "gear") }
                connectionsTab
                    .tabItem { Label("Connections", systemImage: "network") }
                piecesTab
                    .tabItem { Label("Pieces", systemImage: "puzzlepiece.extension") }
            }
            .frame(height: SettingsLayout.contentHeight)
        }
        .frame(width: SettingsLayout.width, height: SettingsLayout.height)
        .controlSize(.small)
        .onAppear {
            appSettings.syncLaunchAtLoginFromSystem()
            Task { await refreshReminderAuth() }
        }
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                Toggle("Check Pieces when I open the list", isOn: refreshOnOpenBinding)
            }

            Section("Reminders") {
                Picker("Summary", selection: reminderScheduleBinding) {
                    ForEach(SummaryReminderSchedule.allCases) { schedule in
                        Text(schedule.label).tag(schedule)
                    }
                }

                Toggle("Quick win nudges", isOn: quickWinRemindersBinding)

                if appSettings.summaryRemindersEnabled || appSettings.quickWinRemindersEnabled {
                    LabeledContent("Notifications") {
                        Text(reminderAuthLabel)
                            .foregroundStyle(reminderAuthColor)
                    }
                    if reminderAuthStatus == .denied {
                        Button("Open Notification Settings…") {
                            SummaryNotificationService.shared.openNotificationSettings()
                        }
                    }
                }
            }

            if appSettings.dismissedFollowUpCount > 0 {
                Section {
                    LabeledContent("Hidden") {
                        Text("\(appSettings.dismissedFollowUpCount)")
                            .foregroundStyle(.secondary)
                    }
                    Button("Show hidden follow-ups again") {
                        Task { await appState.restoreDismissedFollowUps() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    // MARK: - Connections

    private var connectionsTab: some View {
        HStack(alignment: .top, spacing: 12) {
            connectionPanel(
                name: "Pieces OS",
                systemImage: "puzzlepiece.extension",
                isConnected: appState.isPiecesConnected,
                subtitle: piecesConnectionSubtitle,
                isTesting: appState.isTestingPiecesConnectivity,
                testResult: appState.piecesConnectivityTest
            ) {
                Task { await appState.testPiecesConnectivity() }
            }

            connectionPanel(
                name: "Ollama",
                systemImage: "cpu",
                isConnected: appState.isOllamaConnected,
                subtitle: ollamaConnectionSubtitle,
                isTesting: appState.isTestingOllamaConnectivity,
                testResult: appState.ollamaConnectivityTest
            ) {
                Task { await appState.testOllamaConnectivity() }
            } extra: {
                ollamaFields
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .scrollDisabled(true)
    }

    private var ollamaFields: some View {
        Group {
            TextField("URL", text: ollamaBaseURLBinding)
            SecureField("Cloud key", text: ollamaCloudAPIKeyBinding)
            if appSettings.selectedModelNeedsCloudAPIKey, !appSettings.hasOllamaCloudAPIKey {
                Text("Key required for \(appSettings.ollamaSelectedModel)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
            if !appState.ollamaModels.isEmpty {
                Picker("Model", selection: ollamaModelBinding) {
                    if !appSettings.ollamaSelectedModel.isEmpty,
                       !appState.ollamaModels.contains(where: { $0.name == appSettings.ollamaSelectedModel }) {
                        Text(appSettings.ollamaSelectedModel).tag(appSettings.ollamaSelectedModel)
                    }
                    ForEach(appState.ollamaModels) { model in
                        Text(model.name).tag(model.name)
                    }
                }
                .onAppear {
                    if appSettings.ollamaSelectedModel.isEmpty {
                        appSettings.pickOllamaModel(from: appState.ollamaModels)
                    }
                }
            }
            Link("ollama.com/settings/keys", destination: URL(string: "https://ollama.com/settings/keys")!)
                .font(.caption2)
        }
    }

    private func connectionPanel<Extra: View>(
        name: String,
        systemImage: String,
        isConnected: Bool,
        subtitle: String,
        isTesting: Bool,
        testResult: ServiceConnectivityResult?,
        test: @escaping () -> Void,
        @ViewBuilder extra: () -> Extra = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ConnectivityServiceCard(
                name: name,
                systemImage: systemImage,
                isConnected: isConnected,
                subtitle: subtitle
            )

            extra()

            SettingsTestButton(title: "Test", isRunning: isTesting, action: test)

            ConnectivityTestResultView(result: testResult, compact: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }

    // MARK: - Pieces

    private var piecesTab: some View {
        Form {
            Section {
                Picker("Lookback", selection: lookbackBinding) {
                    Text("3 days").tag(3)
                    Text("1 week").tag(7)
                    Text("2 weeks").tag(14)
                }
                Picker("List size", selection: visibleLimitBinding) {
                    ForEach(AppSettings.visibleLimitOptions, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                Picker("Steps / session", selection: stepsPerSessionBinding) {
                    ForEach(AppSettings.stepsPerSessionOptions, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
            }

            Section {
                Button {
                    Task { await appState.refreshMissingFromPieces() }
                } label: {
                    HStack(spacing: 8) {
                        Label("Refresh list", systemImage: "arrow.clockwise")
                        Spacer(minLength: 0)
                        if appState.isLoading {
                            ProgressView().controlSize(.mini)
                        }
                    }
                }
                .disabled(appState.isLoading)

                if !piecesStatusLine.isEmpty {
                    Text(piecesStatusLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    // MARK: - Components

    private var settingsHero: some View {
        HStack(spacing: 10) {
            Image(systemName: "puzzlepiece.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)

            Text("PiecesTask")
                .font(.headline)

            Spacer(minLength: 0)

            Text(appVersion)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var piecesStatusLine: String {
        var parts: [String] = []
        if appState.attentionCount > 0, appState.hasNextStepsOnly {
            parts.append("\(appState.attentionCount) showing")
            if appState.hiddenNextStepsCount > 0 {
                parts.append("\(appState.hiddenNextStepsCount) capped")
            }
            if appState.dismissedFollowUpCount > 0 {
                parts.append("\(appState.dismissedFollowUpCount) hidden")
            }
        }
        if let checked = appState.lastPiecesCheckDate {
            parts.append("Updated \(checked.formatted(date: .omitted, time: .shortened))")
        }
        return parts.joined(separator: " · ")
    }

    private var piecesConnectionSubtitle: String {
        if appState.isPiecesConnected { return "On this Mac" }
        return "Not reachable"
    }

    private var ollamaConnectionSubtitle: String {
        if appState.isOllamaConnected {
            if appSettings.ollamaSelectedModel.isEmpty { return "Pick a model" }
            return appSettings.ollamaSelectedModel
        }
        return "Not running"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    // MARK: - Bindings

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { appSettings.launchAtLogin }, set: { appSettings.launchAtLogin = $0 })
    }

    private var refreshOnOpenBinding: Binding<Bool> {
        Binding(get: { appSettings.refreshOnPopoverOpen }, set: { appSettings.refreshOnPopoverOpen = $0 })
    }

    private var ollamaBaseURLBinding: Binding<String> {
        Binding(get: { appSettings.ollamaBaseURL }, set: { appSettings.ollamaBaseURL = $0 })
    }

    private var ollamaModelBinding: Binding<String> {
        Binding(get: { appSettings.ollamaSelectedModel }, set: { appSettings.ollamaSelectedModel = $0 })
    }

    private var ollamaCloudAPIKeyBinding: Binding<String> {
        Binding(get: { appSettings.ollamaCloudAPIKey }, set: { appSettings.ollamaCloudAPIKey = $0 })
    }

    private var lookbackBinding: Binding<Int> {
        Binding(
            get: { appSettings.lookbackDays },
            set: { appSettings.lookbackDays = $0 }
        )
    }

    private var visibleLimitBinding: Binding<Int> {
        Binding(
            get: { appSettings.visibleItemLimit },
            set: { appSettings.visibleItemLimit = $0 }
        )
    }

    private var stepsPerSessionBinding: Binding<Int> {
        Binding(
            get: { appSettings.stepsPerSession },
            set: { appSettings.stepsPerSession = $0 }
        )
    }

    private var quickWinRemindersBinding: Binding<Bool> {
        Binding(
            get: { appSettings.quickWinRemindersEnabled },
            set: { new in
                Task {
                    _ = await QuickWinNotificationService.shared.setEnabled(new, sendSoon: new)
                    await refreshReminderAuth()
                }
            }
        )
    }

    private var reminderScheduleBinding: Binding<SummaryReminderSchedule> {
        Binding(
            get: { appSettings.summaryReminderSchedule },
            set: { new in
                let wasOff = appSettings.summaryReminderSchedule == .off
                Task {
                    _ = await SummaryNotificationService.shared.applySchedule(
                        new,
                        sendSoon: wasOff && new != .off
                    )
                    await refreshReminderAuth()
                }
            }
        )
    }

    private var reminderAuthLabel: String {
        switch reminderAuthStatus {
        case .authorized: return "Allowed"
        case .denied: return "Blocked"
        case .notDetermined: return "Not asked"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    private var reminderAuthColor: Color {
        switch reminderAuthStatus {
        case .authorized: return .green
        case .denied: return .red
        default: return .secondary
        }
    }

    private func refreshReminderAuth() async {
        await SummaryNotificationService.shared.refreshAuthorizationStatus()
        reminderAuthStatus = SummaryNotificationService.shared.authorizationStatus
    }
}
