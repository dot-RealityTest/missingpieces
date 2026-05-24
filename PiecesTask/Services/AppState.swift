import AppKit
import Foundation

/// Read-only “what you're missing” — all data comes from Pieces OS.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    var attentionSections: [AttentionSection] = []
    var isPiecesConnected: Bool = false
    var isLoading: Bool = false
    var lastPiecesCheckDate: Date?
    var lastPiecesError: String?

    var ollamaSummaryBrief: String?
    var ollamaSummaryError: String?
    var isGeneratingOllamaSummary = false
    var isOllamaSummaryExpanded = false

    var hiddenNextStepsCount: Int = 0
    var dismissedFollowUpCount: Int = 0
    var undoOffer: FollowUpUndoOffer?

    private var refreshTask: Task<Void, Never>?
    private var summaryTask: Task<Void, Never>?
    private var undoClearTask: Task<Void, Never>?

    private init() {}

    var ollamaSummaryIsExpandable: Bool {
        summaryFollowUpTitles.count > 1
    }

    func toggleOllamaSummaryExpanded() {
        guard ollamaSummaryIsExpandable else { return }
        isOllamaSummaryExpanded.toggle()
    }

    var summaryFollowUpTitles: [String] {
        followUpItems.prefix(6).map(\.title)
    }

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

    func refreshMissingFromPieces() async {
        refreshTask?.cancel()
        let task = Task { await performRefreshMissingFromPieces() }
        refreshTask = task
        await task.value
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

    func dismissFollowUp(id: String, title: String, sessionName: String) {
        guard !id.isEmpty else { return }
        offerUndo(id: id, title: title, sessionName: sessionName)
        AppSettings.shared.dismissFollowUp(id: id)
        removeFollowUpFromSections(id: id)
        clearSummaryIfNeeded()
    }

    func performUndo() async {
        guard let offer = undoOffer else { return }
        clearUndoOffer()
        AppSettings.shared.restoreDismissedFollowUp(id: offer.id)
        await refreshMissingFromPieces()
    }

    func dismissUndoOffer() {
        clearUndoOffer()
    }

    @discardableResult
    func copyAllVisibleFollowUpsToPasteboard() -> Int {
        let items = followUpItems
        guard !items.isEmpty else { return 0 }

        let lines = items.map { item in
            if let detail = item.detail, !detail.isEmpty {
                return "- \(item.title) (\(detail))"
            }
            return "- \(item.title)"
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
        return items.count
    }

    func restoreDismissedFollowUps() async {
        AppSettings.shared.restoreAllDismissedFollowUps()
        await refreshMissingFromPieces()
    }

    func summarizeFollowUps() async {
        summaryTask?.cancel()
        let task = Task { await performSummarizeFollowUps() }
        summaryTask = task
        await task.value
    }

    func clearOllamaSummary() {
        ollamaSummaryBrief = nil
        ollamaSummaryError = nil
        isOllamaSummaryExpanded = false
    }

    func probePiecesConnection() async {
        isPiecesConnected = await PiecesService.shared.isAvailable()
    }

    private func offerUndo(id: String, title: String, sessionName: String) {
        undoClearTask?.cancel()
        undoOffer = FollowUpUndoOffer(id: id, title: title, sessionName: sessionName)
        undoClearTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled, undoOffer?.id == id else { return }
            undoOffer = nil
        }
    }

    private func clearUndoOffer() {
        undoClearTask?.cancel()
        undoClearTask = nil
        undoOffer = nil
    }

    private func clearSummaryIfNeeded() {
        ollamaSummaryBrief = nil
        ollamaSummaryError = nil
        isOllamaSummaryExpanded = false
    }

    private func performRefreshMissingFromPieces() async {
        isLoading = true
        lastPiecesError = nil
        hiddenNextStepsCount = 0
        dismissedFollowUpCount = 0
        defer {
            isLoading = false
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

    private func applyNextSteps(_ steps: [PiecesNextStep], visibleLimit: Int) {
        let settings = AppSettings.shared
        let active = steps.filter { step in
            let id = FollowUpItemID.make(summaryID: step.summaryID, stepText: step.stepText)
            return !settings.isDismissedFollowUp(id: id)
        }
        dismissedFollowUpCount = settings.dismissedFollowUpCount

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
        attentionSections = attentionSections.compactMap { section in
            let items = section.items.filter { $0.id != id }
            guard !items.isEmpty else { return nil }
            return AttentionSection(
                id: section.id,
                sessionName: section.sessionName,
                items: items
            )
        }
        dismissedFollowUpCount = AppSettings.shared.dismissedFollowUpCount
    }

    private func performSummarizeFollowUps() async {
        let settings = AppSettings.shared
        guard settings.canUseOllamaSummary else {
            ollamaSummaryError = "Pick an Ollama model under Settings → Connections."
            return
        }

        let followUps = followUpItems
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
            ollamaSummaryBrief = text
            ollamaSummaryError = nil
        } else {
            ollamaSummaryBrief = nil
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
        let bulletLines = followUps.prefix(6).map { "• \($0.title)" }.joined(separator: "\n")
        let system = """
        You write one line for a macOS menu bar popover. The user will glance at it for one second.

        Output rules (strict):
        - Exactly one short sentence, 6–10 words
        - Start with a verb (Reply, Fix, Ship, Review, Call, Send, Finish…)
        - Name the single highest-impact task using words from the list
        - Plain language, direct, calm — not urgent
        - No preamble, labels, quotes, colons, bullets, or meta text
        - Never say: summary, follow-up, here is, you should, there are
        """
        let prompt = """
        Pick the one best next action from these follow-ups:

        \(bulletLines)

        Next action:
        """

        let result = await OllamaService.shared.generateText(
            baseURLString: settings.ollamaBaseURL,
            model: settings.ollamaSelectedModel,
            prompt: prompt,
            system: system,
            maxTokens: 40
        )

        switch result {
        case .success(let text):
            let line = cleanSummaryLine(text, maxChars: 100)
            if !line.isEmpty {
                return OllamaSummaryOutcome(text: line, error: nil)
            }
            return OllamaSummaryOutcome(text: plainSummary(from: followUps), error: nil)
        case .failure(let err):
            return OllamaSummaryOutcome(text: nil, error: err.localizedDescription)
        }
    }

    private static func cleanSummaryLine(_ raw: String, maxChars: Int = 120) -> String {
        var text = raw
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = text.split(whereSeparator: \.isNewline).first {
            text = String(firstLine).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let regex = try? NSRegularExpression(
            pattern: #"(?is)<think>.*?</think>\s*"#
        ) {
            let range = NSRange(text.startIndex..., in: text)
            text = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard text.count > maxChars else { return text }
        let cut = text.prefix(maxChars)
        if let lastSpace = cut.lastIndex(of: " ") {
            return String(cut[..<lastSpace])
        }
        return String(cut)
    }

    private static func plainSummary(from followUps: [AttentionItem]) -> String? {
        guard let first = followUps.first?.title else { return nil }
        if followUps.count == 1 { return first }
        return "\(followUps.count) follow-ups — \(first)"
    }
}
