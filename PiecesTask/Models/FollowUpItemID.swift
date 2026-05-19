import Foundation

enum FollowUpItemID {
    static func make(summaryID: String, stepText: String) -> String {
        "\(summaryID)-\(stepText.hashValue)"
    }
}
