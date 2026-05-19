import Foundation

/// Result of a Settings connectivity test (Pieces OS or Ollama).
struct ServiceConnectivityResult: Sendable, Equatable {
    let isConnected: Bool
    let title: String
    let detail: String?
    let testedAt: Date

    static func success(title: String, detail: String? = nil) -> ServiceConnectivityResult {
        ServiceConnectivityResult(
            isConnected: true,
            title: title,
            detail: detail,
            testedAt: Date()
        )
    }

    static func failure(title: String, detail: String? = nil) -> ServiceConnectivityResult {
        ServiceConnectivityResult(
            isConnected: false,
            title: title,
            detail: detail,
            testedAt: Date()
        )
    }
}

struct PiecesConnectivityInfo: Sendable {
    let isAvailable: Bool
    let baseURL: String?
    let port: Int?
    let message: String
}

struct OllamaModelInfo: Sendable, Identifiable, Hashable {
    var id: String { name }
    let name: String
}
