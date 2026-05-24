import Foundation

/// Local Ollama HTTP API (default port 11434).
final class OllamaService: @unchecked Sendable {
    static let shared = OllamaService()

    private let session: URLSession

    private let generateSession: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        self.session = URLSession(configuration: config)

        let generateConfig = URLSessionConfiguration.default
        generateConfig.timeoutIntervalForRequest = 90
        generateConfig.timeoutIntervalForResource = 120
        self.generateSession = URLSession(configuration: generateConfig)
    }

    func checkConnectivity(baseURLString: String) async -> (result: ServiceConnectivityResult, models: [OllamaModelInfo]) {
        let base = Self.normalizedBaseURL(baseURLString)

        guard let tagsURL = URL(string: "\(base)/api/tags") else {
            return (
                .failure(title: "Invalid Ollama URL", detail: "Use something like http://127.0.0.1:11434"),
                []
            )
        }

        var request = URLRequest(url: tagsURL)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (.failure(title: "No response from Ollama"), [])
            }
            guard (200..<300).contains(http.statusCode) else {
                return (
                    .failure(
                        title: "Ollama returned \(http.statusCode)",
                        detail: String((String(data: data, encoding: .utf8) ?? "").prefix(120))
                    ),
                    []
                )
            }

            let models = parseModels(from: data)
            let modelLine = models.isEmpty
                ? "Server is up but no models are installed yet."
                : "Found \(models.count) model\(models.count == 1 ? "" : "s")."

            return (
                .success(
                    title: "Connected to Ollama",
                    detail: "\(base)\n\(modelLine)"
                ),
                models
            )
        } catch {
            return (
                .failure(
                    title: "Can't reach Ollama",
                    detail: "Start Ollama on this Mac, then test again. (\(error.localizedDescription))"
                ),
                []
            )
        }
    }

    static func normalizedBaseURL(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = defaultBaseURL }
        if !s.contains("://") { s = "http://\(s)" }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    static let defaultBaseURL = "http://127.0.0.1:11434"

    func generateText(
        baseURLString: String,
        model: String,
        prompt: String,
        system: String? = nil,
        maxTokens: Int = 64
    ) async -> Result<String, OllamaGenerateError> {
        let trimmedSystem = system?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedSystem.isEmpty {
            let mergedPrompt = "\(trimmedSystem)\n\n\(prompt)"
            let merged = await performGenerate(
                baseURLString: baseURLString,
                model: model,
                prompt: mergedPrompt,
                system: nil,
                maxTokens: maxTokens
            )
            if case .success = merged { return merged }
            return await performGenerate(
                baseURLString: baseURLString,
                model: model,
                prompt: prompt,
                system: trimmedSystem,
                maxTokens: maxTokens
            )
        }
        return await performGenerate(
            baseURLString: baseURLString,
            model: model,
            prompt: prompt,
            system: nil,
            maxTokens: maxTokens
        )
    }

    private func performGenerate(
        baseURLString: String,
        model: String,
        prompt: String,
        system: String?,
        maxTokens: Int
    ) async -> Result<String, OllamaGenerateError> {
        let base = Self.normalizedBaseURL(baseURLString)
        guard let url = URL(string: "\(base)/api/generate") else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            // Reasoning/cloud models otherwise fill `thinking` and leave `response` empty.
            "think": false,
            "options": [
                "num_predict": max(32, min(maxTokens, 128)),
                "temperature": 0.15,
            ],
        ]
        if let system, !system.isEmpty {
            body["system"] = system
        }
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(.encodingFailed)
        }
        request.httpBody = httpBody

        do {
            let (data, response) = try await generateSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.badResponse)
            }
            guard (200..<300).contains(http.statusCode) else {
                let snippet = String((String(data: data, encoding: .utf8) ?? "").prefix(160))
                return .failure(.httpStatus(http.statusCode, snippet))
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure(.unexpectedResponse)
            }
            let trimmed = Self.extractGeneratedText(from: json)
            guard !trimmed.isEmpty else {
                return .failure(.emptyResponse)
            }
            return .success(trimmed)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                return .failure(.network("Ollama timed out — try a smaller model in Settings."))
            }
            return .failure(.network(error.localizedDescription))
        }
    }

    enum OllamaGenerateError: LocalizedError {
        case invalidURL
        case encodingFailed
        case badResponse
        case unexpectedResponse
        case emptyResponse
        case httpStatus(Int, String)
        case network(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Ollama URL."
            case .encodingFailed:
                return "Could not build the Ollama request."
            case .badResponse:
                return "No response from Ollama."
            case .unexpectedResponse:
                return "Unexpected response from Ollama."
            case .emptyResponse:
                return "Ollama returned an empty summary."
            case .httpStatus(let code, let body):
                return body.isEmpty ? "Ollama returned \(code)." : "Ollama returned \(code): \(body)"
            case .network(let message):
                return message
            }
        }
    }

    private static func extractGeneratedText(from json: [String: Any]) -> String {
        if let response = json["response"] as? String {
            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return stripThinkingMarkup(trimmed)
            }
        }
        if let thinking = json["thinking"] as? String {
            let trimmed = thinking.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return stripThinkingMarkup(trimmed)
            }
        }
        return ""
    }

    /// Remove chain-of-thought wrappers some models emit in `response`.
    private static func stripThinkingMarkup(_ text: String) -> String {
        var s = text
        if let regex = try? NSRegularExpression(
            pattern: #"(?is)<think>.*?</think>\s*"#
        ) {
            let range = NSRange(s.startIndex..., in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseModels(from data: Data) -> [OllamaModelInfo] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }

        let parsed = models.compactMap { entry -> OllamaModelInfo? in
            guard let name = entry["name"] as? String, !name.isEmpty else { return nil }
            return OllamaModelInfo(name: name)
        }
        return OllamaModelPreference.sortedForSummary(parsed)
    }
}

// MARK: - Summary model preference (light models first)

enum OllamaModelPreference {
    static func isHeavyModel(_ name: String) -> Bool {
        let lower = name.lowercased()
        let heavyMarkers = [
            "cloud", "remote", "70b", "72b", "80b", "90b", "405b",
            "8x22", "mixtral:8x", "deepseek-r1", "embed",
        ]
        if heavyMarkers.contains(where: { lower.contains($0) }) { return true }
        if lower.range(of: #":([3-9]\d|[1-9]\d{2,})b"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    static func sortedForSummary(_ models: [OllamaModelInfo]) -> [OllamaModelInfo] {
        models
            .filter { !isHeavyModel($0.name) }
            .sorted { lhs, rhs in
                let l = lightModelRank(lhs.name)
                let r = lightModelRank(rhs.name)
                if l != r { return l > r }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private static func lightModelRank(_ name: String) -> Int {
        let lower = name.lowercased()
        if lower.contains(":1b") || lower.contains("-1b") || lower.contains("270m") || lower.contains("0.5b") {
            return 3
        }
        if lower.contains(":2b") || lower.contains("-2b") || lower.contains(":3b") || lower.contains("-3b") {
            return 2
        }
        if lower.contains(":7b") || lower.contains("-7b") { return 1 }
        return 0
    }

    static func pickModelName(current: String, from models: [OllamaModelInfo]) -> String {
        let sorted = sortedForSummary(models)
        let pool = sorted.isEmpty ? models : sorted
        guard !pool.isEmpty else { return "" }
        let preferred = pool[0].name
        if current.isEmpty { return preferred }
        if !models.contains(where: { $0.name == current }) { return preferred }
        return current
    }
}
