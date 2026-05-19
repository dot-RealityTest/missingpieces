import Foundation

/// Picks a follow-up that looks small and doable — for “quick win” nudges.
enum QuickWinPicker {
    private static let boostKeywords = [
        "fix", "reply", "email", "send", "review", "check", "test", "update",
        "add", "copy", "rename", "toggle", "verify", "confirm", "draft",
        "polish", "tweak", "clean", "doc", "note", "comment",
    ]

    private static let heavyKeywords = [
        "migrate", "migration", "refactor", "architecture", "redesign",
        "implement full", "transition the", "multi-week", "from scratch",
        "rebuild", "rewrite",
    ]

    static func bestQuickWin(from items: [AttentionItem]) -> AttentionItem? {
        items
            .filter { $0.reason == .nextStep }
            .max(by: { score($0) < score($1) })
    }

    static func notificationTitle() -> String {
        [
            "Quick win",
            "Easy one",
            "Small win",
            "Five-minute task",
        ].randomElement() ?? "Quick win"
    }

    static func notificationBody(for item: AttentionItem) -> String {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = title.count > 160 ? String(title.prefix(157)) + "…" : title
        let lead = [
            "Knock this out:",
            "Try this next:",
            "You could finish:",
            "Low-hanging fruit:",
        ].randomElement() ?? "Try this:"
        if let session = item.detail, !session.isEmpty, session.count < 40 {
            return "\(lead) \(clipped) (\(session))"
        }
        return "\(lead) \(clipped)"
    }

    private static func score(_ item: AttentionItem) -> Int {
        let text = item.title.lowercased()
        let words = text.split(whereSeparator: { $0.isWhitespace }).count

        var points = 80
        points -= min(words * 6, 48)
        points -= min(text.count / 12, 36)

        for keyword in boostKeywords where text.contains(keyword) {
            points += 10
        }
        for keyword in heavyKeywords where text.contains(keyword) {
            points -= 18
        }

        if words <= 6 { points += 8 }
        if text.count <= 60 { points += 6 }

        return points
    }
}
