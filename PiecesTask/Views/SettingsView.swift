import SwiftUI

private enum SettingsLayout {
    static let width: CGFloat = 560
    static let height: CGFloat = 512
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case connections
    case pieces

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .connections: return "Connections"
        case .pieces: return "Pieces"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gear"
        case .connections: return "network"
        case .pieces: return "puzzlepiece.extension"
        }
    }
}

struct SettingsView: View {
    @Bindable var appState: AppState
    @Bindable var appSettings: AppSettings
    var onDismiss: () -> Void

    @State private var selectedTab: SettingsTab = .general
    @State private var draft = SettingsDraft(from: AppSettings.shared)
    @State private var savedSnapshot = SettingsDraft(from: AppSettings.shared)
    @State private var piecesTestResult: ServiceConnectivityResult?
    @State private var ollamaTestResult: ServiceConnectivityResult?
    @State private var isTestingPieces = false
    @State private var isTestingOllama = false
    @State private var ollamaModels: [OllamaModelInfo] = []
    @State private var ollamaConnected = false

    private var hasUnsavedChanges: Bool { draft != savedSnapshot }

    var body: some View {
        VStack(spacing: 0) {
            settingsHero
                .overlay(alignment: .bottom) {
                    PopoverGlassStyle.sectionDivider
                        .frame(height: 0.5)
                        .padding(.horizontal, 12)
                }

            tabBar

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            settingsFooter
                .overlay(alignment: .top) {
                    PopoverGlassStyle.sectionDivider
                        .frame(height: 0.5)
                }
        }
        .frame(width: SettingsLayout.width, height: SettingsLayout.height)
        .popoverGlassContentGroup()
        .settingsGlassChrome()
        .background(PopoverWindowConfigurator())
        .controlSize(.small)
        .onAppear {
            reloadDraftFromSaved()
            appSettings.syncLaunchAtLoginFromSystem()
            reloadDraftFromSaved()
        }
    }

    // MARK: - Tabs

    private var tabBar: some View {
        Picker("Section", selection: $selectedTab) {
            ForEach(SettingsTab.allCases) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            generalTab
        case .connections:
            connectionsTab
        case .pieces:
            piecesTab
        }
    }

    // MARK: - General

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SettingsGlassSection {
                    SettingsToggleRow(title: "Launch at login", isOn: launchAtLoginBinding)
                    SettingsSectionDivider()
                    SettingsToggleRow(
                        title: "Check Pieces when I open the list",
                        isOn: refreshOnOpenBinding
                    )
                    SettingsSectionDivider()
                    SettingsToggleRow(
                        title: "Global shortcut (\(GlobalHotKeyService.shortcutLabel))",
                        isOn: globalShortcutBinding
                    )
                }

                if appSettings.dismissedFollowUpCount > 0 {
                    SettingsGlassSection {
                        SettingsLabeledRow(title: "Hidden") {
                            Text("\(appSettings.dismissedFollowUpCount)")
                                .font(.caption)
                                .foregroundStyle(SettingsTheme.secondaryLabel)
                        }
                        SettingsSectionDivider()
                        SettingsActionRow(
                            title: "Show hidden follow-ups again",
                            systemImage: "eye"
                        ) {
                            Task { await appState.restoreDismissedFollowUps() }
                        }
                    }
                }
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Connections

    private var connectionsTab: some View {
        HStack(alignment: .top, spacing: 12) {
            connectionPanel(
                name: "Pieces OS",
                systemImage: "puzzlepiece.extension",
                isConnected: appState.isPiecesConnected,
                subtitle: piecesConnectionSubtitle,
                isTesting: isTestingPieces,
                testResult: piecesTestResult
            ) {
                Task { await testPiecesConnection() }
            }

            connectionPanel(
                name: "Ollama",
                systemImage: "cpu",
                isConnected: ollamaConnected,
                subtitle: ollamaConnectionSubtitle,
                isTesting: isTestingOllama,
                testResult: ollamaTestResult
            ) {
                Task { await testOllamaConnection() }
            } extra: {
                ollamaFields
            }
        }
        .padding(12)
    }

    private var ollamaFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            settingsTextField("URL", text: ollamaBaseURLBinding)
            if !ollamaModels.isEmpty {
                SettingsPickerRow(title: "Model", selection: ollamaModelBinding) {
                    if !draft.ollamaSelectedModel.isEmpty,
                       !ollamaModels.contains(where: { $0.name == draft.ollamaSelectedModel }) {
                        Text(draft.ollamaSelectedModel).tag(draft.ollamaSelectedModel)
                    }
                    ForEach(ollamaModels) { model in
                        Text(model.name).tag(model.name)
                    }
                }
            }
        }
    }

    private func settingsTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.caption)
            .foregroundStyle(SettingsTheme.value)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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

            SettingsTestButton(title: "Test connection", isRunning: isTesting, action: test)

            ConnectivityTestResultView(result: testResult, compact: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .popoverListPanel()
    }

    // MARK: - Pieces

    private var piecesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SettingsGlassSection {
                    SettingsPickerRow(title: "Lookback", selection: lookbackBinding) {
                        Text("3 days").tag(3)
                        Text("1 week").tag(7)
                        Text("2 weeks").tag(14)
                    }
                    SettingsSectionDivider()
                    SettingsPickerRow(title: "List size", selection: visibleLimitBinding) {
                        ForEach(AppSettings.visibleLimitOptions, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    SettingsSectionDivider()
                    SettingsPickerRow(title: "Steps / session", selection: stepsPerSessionBinding) {
                        ForEach(AppSettings.stepsPerSessionOptions, id: \.self) { n in
                            Text("\(n)").tag(n)
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

                    if !piecesStatusLine.isEmpty {
                        SettingsSectionDivider()
                        Text(piecesStatusLine)
                            .font(.caption2)
                            .foregroundStyle(SettingsTheme.secondaryLabel)
                            .lineLimit(3)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 8)
                    }
                }
            }
            .padding(12)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Components

    private var settingsHero: some View {
        HStack(spacing: 10) {
            Image(systemName: "puzzlepiece.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text("Settings")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary.opacity(0.72))
                Text("PiecesTask")
                    .font(.caption2)
                    .foregroundStyle(Color.primary.opacity(0.38))
            }

            Text(appVersion)
                .font(.caption2)
                .foregroundStyle(Color.primary.opacity(0.32))

            Button(action: cancelAndClose) {
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

    private var settingsFooter: some View {
        HStack(spacing: 10) {
            Button("Cancel", action: cancelAndClose)
                .keyboardShortcut(.cancelAction)

            Spacer(minLength: 0)

            Button("Apply") {
                Task { await applyChanges(closeAfter: false) }
            }
            .disabled(!hasUnsavedChanges)

            Button("Save") {
                Task { await applyChanges(closeAfter: true) }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!hasUnsavedChanges)
        }
        .font(.system(size: 12.5))
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
        if ollamaConnected {
            if draft.ollamaSelectedModel.isEmpty { return "Pick a model" }
            return draft.ollamaSelectedModel
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
        Binding(get: { draft.launchAtLogin }, set: { draft.launchAtLogin = $0 })
    }

    private var refreshOnOpenBinding: Binding<Bool> {
        Binding(get: { draft.refreshOnPopoverOpen }, set: { draft.refreshOnPopoverOpen = $0 })
    }

    private var globalShortcutBinding: Binding<Bool> {
        Binding(get: { draft.globalShortcutEnabled }, set: { draft.globalShortcutEnabled = $0 })
    }

    private var ollamaBaseURLBinding: Binding<String> {
        Binding(get: { draft.ollamaBaseURL }, set: { draft.ollamaBaseURL = $0 })
    }

    private var ollamaModelBinding: Binding<String> {
        Binding(get: { draft.ollamaSelectedModel }, set: { draft.ollamaSelectedModel = $0 })
    }

    private var lookbackBinding: Binding<Int> {
        Binding(get: { draft.lookbackDays }, set: { draft.lookbackDays = $0 })
    }

    private var visibleLimitBinding: Binding<Int> {
        Binding(get: { draft.visibleItemLimit }, set: { draft.visibleItemLimit = $0 })
    }

    private var stepsPerSessionBinding: Binding<Int> {
        Binding(get: { draft.stepsPerSession }, set: { draft.stepsPerSession = $0 })
    }

    private func reloadDraftFromSaved() {
        let snapshot = SettingsDraft(from: appSettings)
        draft = snapshot
        savedSnapshot = snapshot
    }

    private func cancelAndClose() {
        onDismiss()
    }

    private func applyChanges(closeAfter: Bool) async {
        await draft.commit(to: appSettings, appState: appState)
        savedSnapshot = draft
        if closeAfter {
            onDismiss()
        }
    }

    private func testPiecesConnection() async {
        isTestingPieces = true
        defer { isTestingPieces = false }

        let info = await PiecesService.shared.checkConnectivity()
        appState.isPiecesConnected = info.isAvailable

        if info.isAvailable {
            let portText = info.port.map { "Port \($0)" } ?? "Port unknown"
            piecesTestResult = .success(
                title: "Connected to Pieces OS",
                detail: [info.baseURL, portText, info.message].compactMap { $0 }.joined(separator: "\n")
            )
        } else {
            piecesTestResult = .failure(title: "Pieces OS is offline", detail: info.message)
        }
    }

    private func testOllamaConnection() async {
        isTestingOllama = true
        defer { isTestingOllama = false }

        let outcome = await OllamaService.shared.checkConnectivity(baseURLString: draft.ollamaBaseURL)
        ollamaTestResult = outcome.result
        ollamaModels = outcome.models
        ollamaConnected = outcome.result.isConnected

        if outcome.result.isConnected {
            draft.ollamaSelectedModel = OllamaModelPreference.pickModelName(
                current: draft.ollamaSelectedModel,
                from: outcome.models
            )
        }
    }
}
