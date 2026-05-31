import CryptoKit
import Foundation

enum FollowUpItemID {
    static func make(summaryID: String, stepText: String) -> String {
        let normalizedStep = stepText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let rawID = "\(summaryID)\n\(normalizedStep)"
        let digest = SHA256.hash(data: Data(rawID.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
