import Foundation
import UserNotifications

/// Nudges the user with one small follow-up about every 30 minutes.
@MainActor
final class QuickWinNotificationService {
    static let shared = QuickWinNotificationService()

    /// Default cadence (~30 minutes).
    static let intervalSeconds: TimeInterval = 30 * 60

    private var loopTask: Task<Void, Never>?
    private weak var appState: AppState?

    private init() {}

    func configure(appState: AppState) {
        self.appState = appState
    }

    @discardableResult
    func setEnabled(_ enabled: Bool, sendSoon: Bool = false) async -> Bool {
        AppSettings.shared.quickWinRemindersEnabled = enabled

        guard enabled else {
            stop()
            return true
        }

        guard await SummaryNotificationService.shared.ensureAuthorized() else {
            AppSettings.shared.quickWinRemindersEnabled = false
            stop()
            return false
        }

        reschedule(sendSoon: sendSoon)
        return true
    }

    func reschedule(sendSoon: Bool = false) {
        stop()

        guard AppSettings.shared.quickWinRemindersEnabled, let appState else { return }

        let state = appState
        loopTask = Task {
            if sendSoon {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { return }
                await deliverQuickWin(using: state)
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.intervalSeconds))
                guard !Task.isCancelled else { return }
                await deliverQuickWin(using: state)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    private func deliverQuickWin(using appState: AppState) async {
        await SummaryNotificationService.shared.refreshAuthorizationStatus()
        guard SummaryNotificationService.shared.authorizationStatus == .authorized else { return }

        await appState.refreshMissingFromPiecesIfNeeded()

        guard appState.hasNextStepsOnly,
              let win = QuickWinPicker.bestQuickWin(from: appState.followUpItems) else {
            return
        }

        await LocalNotificationPoster.post(
            title: QuickWinPicker.notificationTitle(),
            body: QuickWinPicker.notificationBody(for: win),
            identifierPrefix: "piecestask.quickwin"
        )
    }
}
