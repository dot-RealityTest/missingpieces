import AppKit
import Foundation
import UserNotifications

/// Schedules macOS notifications with short follow-up summaries.
@MainActor
final class SummaryNotificationService: NSObject {
    static let shared = SummaryNotificationService()

    private var loopTask: Task<Void, Never>?
    private weak var appState: AppState?

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
    }

    func configure(appState: AppState) {
        self.appState = appState
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Ask for notification permission. Returns whether alerts are allowed.
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    /// Use before any reminder type is enabled.
    func ensureAuthorized() async -> Bool {
        await refreshAuthorizationStatus()
        if authorizationStatus == .authorized { return true }
        return await requestAuthorization()
    }

    /// Turn reminders on (requests permission) or off, then reschedule.
    @discardableResult
    func applySchedule(_ schedule: SummaryReminderSchedule, sendSoon: Bool = false) async -> Bool {
        AppSettings.shared.summaryReminderSchedule = schedule

        guard schedule != .off else {
            stop()
            return true
        }

        guard await ensureAuthorized() else {
            AppSettings.shared.summaryReminderSchedule = .off
            stop()
            return false
        }

        reschedule(sendSoon: sendSoon)
        return true
    }

    func reschedule(sendSoon: Bool = false) {
        stop()

        guard let seconds = AppSettings.shared.summaryReminderSchedule.intervalSeconds,
              seconds > 0,
              let appState else {
            return
        }

        let state = appState
        loopTask = Task {
            if sendSoon {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { return }
                await deliverReminder(using: state)
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                await deliverReminder(using: state)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Delivery

    private func deliverReminder(using appState: AppState) async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized else { return }

        await appState.refreshMissingFromPiecesIfNeeded()

        guard appState.hasNextStepsOnly, appState.attentionCount > 0 else { return }

        let body: String
        if let summary = await appState.makeFollowUpSummaryText() {
            body = summary
        } else if let fallback = appState.fallbackReminderText() {
            body = fallback
        } else {
            return
        }

        await LocalNotificationPoster.post(
            title: Self.notificationTitle(for: appState.attentionCount),
            body: body,
            identifierPrefix: "piecestask.summary"
        )
    }

    private static func notificationTitle(for count: Int) -> String {
        let titles = [
            "What you're missing",
            "Still on your plate",
            "Quick nudge",
            "Follow-ups waiting",
        ]
        if count == 1 {
            return "One thing to pick up"
        }
        return titles.randomElement() ?? "What you're missing"
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension SummaryNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
