import Foundation

/// Read-only “what you're missing” — all data comes from Pieces OS.
@MainActor
@Observable
final class AppState {
    var attentionSections: [AttentionSection] = []
    var isPiecesConnected: Bool = false
    var isLoading: Bool = false
    var lastPiecesCheckDate: Date?
    var lastPiecesError: String?
    private var lastListRefreshDate: Date?

    // MARK: - Connectivity (Settings)

    var piecesConnectivityTest: ServiceConnectivityResult?
    var ollamaConnectivityTest: ServiceConnectivityResult?
    var ollamaModels: [OllamaModelInfo] = []
    var isTestingPiecesConnectivity = false
    var isTestingOllamaConnectivity = false
    var isOllamaConnected = false

    // MARK: - Ollama summary (popover)

    var ollamaSummary: String?
    var ollamaSummaryError: String?
    var isGeneratingOllamaSummary = false
    var isOllamaSummaryExpanded = false

    private var refreshTask: Task<Void, Never>?
    private var summaryTask: Task<Void, Never>?

    /// Steps found in Pieces but not shown in the popover (cap keeps the list glanceable).
    var hiddenNextStepsCount: Int = 0
    /// Follow-ups hidden by the user in this app (not sent to Pieces).
    var dismissedFollowUpCount: Int = 0

    var attentionCount: Int {
        attentionSections.reduce(0) { $0 + $1.items.count }
    }

    var hasProblemItems: Bool {
        attentionSections.contains { section in
            section.items.contains { $0.reason.isProblem }
        }
    }

    var hasNextStepsOnly: Bool {
        attentionCount > 0 && !hasProblemItems
    }

    var followUpItems: [AttentionItem] {
        attentionSections.flatMap(\.items).filter { $0.reason == .nextStep }
    }

    /// Re-check Pieces and rebuild the missing list (popover open and “Check again”).
    func refreshMissingFromPieces() async {
        refreshTask?.cancel()
        let task = Task {
            await performRefreshMissingFromPieces()
        }
        refreshTask = task
        await task.value
    }

    /// Skips work if the list was refreshed recently (background reminders share one fetch).
    func refreshMissingFromPiecesIfNeeded(minimumInterval: TimeInterval = 120) async {
        if let last = lastListRefreshDate,
           Date().timeIntervalSince(last) < minimumInterval {
            return
        }
        await refreshMissingFromPieces()
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        isLoading = false
    }

    func cancelSummary() {
        summaryTask?.cancel()
        summaryTask = nil
        isGeneratingOllamaSummary = false
    }

    /// Hide a follow-up in this app only. Pieces is unchanged.
    func dismissFollowUp(id: String) {
        guard !id.isEmpty else { return }
        AppSettings.shared.dismissFollowUp(id: id)
        removeFollowUpFromSections(id: id)
        ollamaSummary = nil
        ollamaSummaryError = nil
    }

    func restoreDismissedFollowUps() async {
        AppSettings.shared.restoreAllDismissedFollowUps()
        await refreshMissingFromPieces()
    }

    /// Short AI summary of the visible follow-ups (Ollama on this Mac).
    func summarizeFollowUps() async {
        summaryTask?.cancel()
        let task = Task {
            await performSummarizeFollowUps()
        }
        summaryTask = task
        await task.value
    }

    func clearOllamaSummary() {
        ollamaSummary = nil
        ollamaSummaryError = nil
    }

    /// Light status check for Settings — does not replace the popover list.
    func probePiecesConnection() async {
        isPiecesConnected = await PiecesService.shared.isAvailable()
    }

    private func performRefreshMissingFromPieces() async {
        isLoading = true
        lastPiecesError = nil
        hiddenNextStepsCount = 0
        dismissedFollowUpCount = 0
        defer {
            isLoading = false
            lastListRefreshDate = Date()
            if refreshTask?.isCancelled == true {
                refreshTask = nil
            }
        }

        guard !Task.isCancelled else { return }

        isPiecesConnected = await PiecesService.shared.isAvailable()
        lastPiecesCheckDate = Date()

        guard !Task.isCancelled else { return }

        guard isPiecesConnected else {
            attentionSections = [
                AttentionSection(
                    id: "pieces-unavailable",
                    sessionName: "",
                    items: [
                        AttentionItem(
                            id: "pieces-unavailable",
                            title: "Pieces OS isn't running",
                            reason: .piecesUnavailable,
                            detail: "Open Pieces OS so recent work summaries can be read."
                        ),
                    ]
                ),
            ]
            lastPiecesError = "Pieces OS is not running."
            return
        }

        do {
            let settings = AppSettings.shared
            let steps = try await PiecesService.shared.fetchNextSteps(
                lookbackDays: settings.lookbackDays,
                maxSummaries: 6,
                maxStepsPerSummary: settings.stepsPerSession,
                maxTotal: settings.fetchTotalLimit
            )
            guard !Task.isCancelled else { return }
            applyNextSteps(steps, visibleLimit: settings.visibleItemLimit)
            lastPiecesError = nil
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            lastPiecesError = error.localizedDescription
            attentionSections = [
                AttentionSection(
                    id: "pieces-fetch-failed",
                    sessionName: "",
                    items: [
                        AttentionItem(
                            id: "pieces-fetch-failed",
                            title: "Couldn't load next steps from Pieces",
                            reason: .fetchFailed,
                            detail: error.localizedDescription
                        ),
                    ]
                ),
            ]
        }
    }

    func checkPiecesConnection() async {
        await probePiecesConnection()
    }

    /// Full Pieces connectivity test for Settings (rediscovers port).
    func testPiecesConnectivity() async {
        isTestingPiecesConnectivity = true
        defer { isTestingPiecesConnectivity = false }

        let info = await PiecesService.shared.checkConnectivity()
        isPiecesConnected = info.isAvailable

        if info.isAvailable {
            let portText = info.port.map { "Port \($0)" } ?? "Port unknown"
            piecesConnectivityTest = .success(
                title: "Connected to Pieces OS",
                detail: [info.baseURL, portText, info.message].compactMap { $0 }.joined(separator: "\n")
            )
            lastPiecesError = nil
        } else {
            piecesConnectivityTest = .failure(title: "Pieces OS is offline", detail: info.message)
            lastPiecesError = info.message
        }
    }

    /// Ollama connectivity test + model list for Settings.
    func testOllamaConnectivity() async {
        isTestingOllamaConnectivity = true
        defer { isTestingOllamaConnectivity = false }

        let settings = AppSettings.shared
        let outcome = await OllamaService.shared.checkConnectivity(
            baseURLString: settings.ollamaBaseURL,
            apiKey: settings.ollamaCloudAPIKey
        )
        ollamaConnectivityTest = outcome.result
        ollamaModels = outcome.models
        isOllamaConnected = outcome.result.isConnected

        if outcome.result.isConnected {
            AppSettings.shared.pickOllamaModel(from: outcome.models)
        }
    }

    private func applyNextSteps(_ steps: [PiecesNextStep], visibleLimit: Int) {
        let settings = AppSettings.shared
        let active = steps.filter { step in
            let id = FollowUpItemID.make(summaryID: step.summaryID, stepText: step.stepText)
            return !settings.isDismissedFollowUp(id: id)
        }
        dismissedFollowUpCount = steps.count - active.count

        let visible = Array(active.prefix(visibleLimit))
        hiddenNextStepsCount = max(0, active.count - visible.count)

        var sections: [AttentionSection] = []
        var currentSummaryID: String?
        var currentSessionName = ""
        var currentItems: [AttentionItem] = []

        func flushSection() {
            guard let summaryID = currentSummaryID, !currentItems.isEmpty else { return }
            sections.append(
                AttentionSection(
                    id: summaryID,
                    sessionName: currentSessionName,
                    items: currentItems
                )
            )
            currentItems = []
        }

        for step in visible {
            if step.summaryID != currentSummaryID {
                flushSection()
                currentSummaryID = step.summaryID
                currentSessionName = step.sessionName
            }
            currentItems.append(
                AttentionItem(
                    id: FollowUpItemID.make(summaryID: step.summaryID, stepText: step.stepText),
                    title: step.stepText,
                    reason: .nextStep,
                    detail: step.sessionName
                )
            )
        }
        flushSection()

        attentionSections = sections
    }

    private func removeFollowUpFromSections(id: String) {
        var updated: [AttentionSection] = []
        for section in attentionSections {
            let items = section.items.filter { $0.id != id }
            guard !items.isEmpty else { continue }
            updated.append(
                AttentionSection(
                    id: section.id,
                    sessionName: section.sessionName,
                    items: items
                )
            )
        }
        attentionSections = updated
        dismissedFollowUpCount = AppSettings.shared.dismissedFollowUpCount
    }

    /// Strip model filler ("Here is a summary…") and keep one short sentence.
    private static func sanitizeSummary(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstLine = text.split(whereSeparator: \.isNewline).first {
            text = String(firstLine).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        text = stripWrappingQuotes(text)
        text = stripThinkingMarkupFromSummary(text)

        let preamblePatterns = [
            #"(?i)^here'?s (a )?summary[^:]*:\s*"#,
            #"(?i)^here is (a )?summary[^:]*:\s*"#,
            #"(?i)^summary[^:]*:\s*"#,
            #"(?i)^(the )?follow-ups?[^:]*one (short )?sentence[^:]*:\s*"#,
            #"(?i)^in one (short )?sentence[^:]*:\s*"#,
            #"(?i)^one (short )?sentence[^:]*:\s*"#,
        ]
        var stripped = true
        while stripped {
            stripped = false
            for pattern in preamblePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                      let range = Range(match.range, in: text) else { continue }
                text = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                stripped = true
            }
        }

        let lower = text.lowercased()
        if text.contains(":"),
           ["summary", "sentence", "follow-up", "follow up", "here is", "here's"].contains(where: { lower.contains($0) }),
           let tail = text.split(separator: ":", maxSplits: 16, omittingEmptySubsequences: false).last {
            let candidate = String(tail).trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.count >= 12 { text = candidate }
        }

        text = firstSentence(text)
        return clampSummary(text)
    }

    private static func stripThinkingMarkupFromSummary(_ text: String) -> String {
        var s = text
        if let regex = try? NSRegularExpression(
            pattern: #"(?is)<think>.*?</think>\s*"#
        ) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripWrappingQuotes(_ text: String) -> String {
        var s = text
        let wrappers: [(String, String)] = [("\"", "\""), ("'", "'"), ("“", "”")]
        for (open, close) in wrappers {
            if s.hasPrefix(open), s.hasSuffix(close), s.count > open.count + close.count {
                s = String(s.dropFirst(open.count).dropLast(close.count))
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// First sentence only so we do not show rambling multi-sentence output.
    private static func firstSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 24 else { return trimmed }

        var index = trimmed.startIndex
        var seenNonSpace = 0
        while index < trimmed.endIndex {
            let ch = trimmed[index]
            if !ch.isWhitespace { seenNonSpace += 1 }
            if [".", "!", "?"].contains(ch), seenNonSpace >= 16 {
                let end = trimmed.index(after: index)
                return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            index = trimmed.index(after: index)
        }
        return trimmed
    }

    /// Hard cap so the popover stays glanceable even if the model runs long.
    private static func clampSummary(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let maxChars = 200
        guard cleaned.count > maxChars else { return cleaned }
        let cut = cleaned.prefix(maxChars)
        if let lastSpace = cut.lastIndex(of: " ") {
            return String(cut[..<lastSpace])
        }
        return String(cut)
    }

    /// Short summary for notifications (Ollama when configured, otherwise plain text).
    func makeFollowUpSummaryText() async -> String? {
        let followUps = attentionSections.flatMap(\.items).filter { $0.reason == .nextStep }
        guard !followUps.isEmpty else { return nil }

        let settings = AppSettings.shared
        if settings.canUseOllamaSummary {
            if let text = await Self.generateOllamaSummary(
                followUps: followUps,
                settings: settings
            ).text {
                return text
            }
        }
        return Self.plainSummary(from: followUps)
    }

    /// Plain reminder when Ollama is off or unavailable.
    func fallbackReminderText() -> String? {
        let followUps = attentionSections.flatMap(\.items).filter { $0.reason == .nextStep }
        guard !followUps.isEmpty else { return nil }
        return Self.plainSummary(from: followUps)
    }

    private func performSummarizeFollowUps() async {
        let settings = AppSettings.shared
        guard settings.canUseOllamaSummary else {
            ollamaSummaryError = "Pick an Ollama model under Settings → Connections."
            return
        }

        let followUps = attentionSections.flatMap(\.items).filter { $0.reason == .nextStep }
        guard !followUps.isEmpty else {
            ollamaSummaryError = "No follow-ups to summarize yet."
            return
        }

        isGeneratingOllamaSummary = true
        ollamaSummaryError = nil
        isOllamaSummaryExpanded = false
        defer {
            isGeneratingOllamaSummary = false
            if summaryTask?.isCancelled == true {
                summaryTask = nil
            }
        }

        guard !Task.isCancelled else { return }

        let outcome = await Self.generateOllamaSummary(followUps: followUps, settings: settings)
        if let text = outcome.text {
            ollamaSummary = text
            ollamaSummaryError = nil
            let check = await OllamaService.shared.checkConnectivity(
                baseURLString: settings.ollamaBaseURL,
                apiKey: settings.ollamaCloudAPIKey
            )
            isOllamaConnected = check.result.isConnected
            if check.result.isConnected {
                ollamaModels = check.models
            }
        } else {
            ollamaSummary = nil
            ollamaSummaryError = outcome.error ?? "Could not get a summary from Ollama."
        }
    }

    private struct OllamaSummaryOutcome: Sendable {
        let text: String?
        let error: String?
    }

    private static func generateOllamaSummary(
        followUps: [AttentionItem],
        settings: AppSettings
    ) async -> OllamaSummaryOutcome {
        if OllamaModelPreference.isCloudModel(settings.ollamaSelectedModel),
           !settings.hasOllamaCloudAPIKey {
            return OllamaSummaryOutcome(
                text: nil,
                error: "Add your Ollama cloud API key in Settings → Connections."
            )
        }

        let bulletLines = followUps.prefix(6).map { "- \($0.title)" }.joined(separator: "\n")
        let system = """
        You write exactly one short sentence. No preamble, labels, or meta text (never say "here is", "summary", or "in one sentence"). \
        Start with a verb. Name the single best next task using words from the list. Max 14 words. No lists. No ellipsis.
        """
        let prompt = """
        Pick the one best next task from these follow-ups:

        \(bulletLines)
        """

        let result = await OllamaService.shared.generateText(
            baseURLString: settings.ollamaBaseURL,
            model: settings.ollamaSelectedModel,
            prompt: prompt,
            system: system,
            apiKey: settings.ollamaCloudAPIKey,
            maxTokens: 72
        )

        switch result {
        case .success(let text):
            let sanitized = sanitizeSummary(text)
            if !sanitized.isEmpty {
                return OllamaSummaryOutcome(text: sanitized, error: nil)
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return OllamaSummaryOutcome(text: clampSummary(trimmed), error: nil)
            }
            return OllamaSummaryOutcome(text: plainSummary(from: followUps), error: nil)
        case .failure(let err):
            return OllamaSummaryOutcome(text: nil, error: err.localizedDescription)
        }
    }

    private static func plainSummary(from followUps: [AttentionItem]) -> String {
        let count = followUps.count
        let lead = followUps.prefix(2).map(\.title).joined(separator: " · ")
        if count == 1 {
            return lead
        }
        return "\(count) follow-ups — start with: \(lead)"
    }
}
