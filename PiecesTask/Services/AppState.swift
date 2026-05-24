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

    var dismissedFollowUpCount: Int = 0

    private var refreshTask: Task<Void, Never>?

    private init() {}

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

    func dismissFollowUp(id: String) {
        guard !id.isEmpty else { return }
        AppSettings.shared.dismissFollowUp(id: id)
        removeFollowUpFromSections(id: id)
    }

    func restoreDismissedFollowUps() async {
        AppSettings.shared.restoreAllDismissedFollowUps()
        await refreshMissingFromPieces()
    }

    func probePiecesConnection() async {
        isPiecesConnected = await PiecesService.shared.isAvailable()
    }

    private func performRefreshMissingFromPieces() async {
        isLoading = true
        lastPiecesError = nil
        dismissedFollowUpCount = 0
        defer {
            isLoading = false
            if refreshTask?.isCancelled == true {
                refreshTask = nil
            }
        }

        guard !Task.isCancelled else { return }

        PiecesService.shared.clearConnectivityCache()
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
                            copyText: "Pieces OS isn't running",
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
            let fetchCount = min(24, settings.visibleItemLimit + settings.dismissedFollowUpCount)
            let steps = try await PiecesService.shared.fetchNextSteps(
                lookbackDays: settings.lookbackDays,
                maxSummaries: 6,
                maxStepsPerSummary: 3,
                maxTotal: fetchCount
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
                            copyText: "Couldn't load next steps from Pieces",
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
                    title: PiecesNextStepsParser.displayTitle(from: step.stepText),
                    copyText: step.stepText,
                    reason: .nextStep,
                    detail: PiecesNextStepsParser.displaySubtitle(from: step.stepText)
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
}
