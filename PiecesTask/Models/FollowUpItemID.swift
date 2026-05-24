import CryptoKit
import Foundation

enum FollowUpItemID {
    static func make(summaryID: String, stepText: String) -> String {
        let normalized = stepText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let digest = SHA256.hash(data: Data(normalized.utf8))
        let hex = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "\(summaryID)-\(hex)"
    }
}
