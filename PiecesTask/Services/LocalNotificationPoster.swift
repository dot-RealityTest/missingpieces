import Foundation
import UserNotifications

/// Posts an immediate macOS user notification.
enum LocalNotificationPoster {
    @MainActor
    static func post(title: String, body: String, identifierPrefix: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix).\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
