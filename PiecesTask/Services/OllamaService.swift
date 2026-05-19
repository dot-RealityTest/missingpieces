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

    func checkConnectivity(
        baseURLString: String,
        apiKey: String? = nil
    ) async -> (result: ServiceConnectivityResult, models: [OllamaModelInfo]) {
        let base = Self.normalizedBaseURL(baseURLString)

        guard let tagsURL = URL(string: "\(base)/api/tags") else {
            return (
                .failure(title: "Invalid Ollama URL", detail: "Use something like http://127.0.0.1:11434"),
                []
            )
        }

        var request = URLRequest(url: tagsURL)
        Self.applyAuthorization(to: &request, apiKey: apiKey)

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

    static func applyAuthorization(to request: inout URLRequest, apiKey: String?) {
        let trimmed = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return }
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
    }

    /// One-shot text generation for the popover summary (uses `/api/generate`, not streaming).
    /// Tries a merged prompt first (no separate `system` field); retries with `system` if that fails.
    func generateText(
        baseURLString: String,
        model: String,
        prompt: String,
        system: String? = nil,
        apiKey: String? = nil,
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
                apiKey: apiKey,
                maxTokens: maxTokens
            )
            if case .success = merged { return merged }
            return await performGenerate(
                baseURLString: baseURLString,
                model: model,
                prompt: prompt,
                system: trimmedSystem,
                apiKey: apiKey,
                maxTokens: maxTokens
            )
        }
        return await performGenerate(
            baseURLString: baseURLString,
            model: model,
            prompt: prompt,
            system: nil,
            apiKey: apiKey,
            maxTokens: maxTokens
        )
    }

    private func performGenerate(
        baseURLString: String,
        model: String,
        prompt: String,
        system: String?,
        apiKey: String?,
        maxTokens: Int
    ) async -> Result<String, OllamaGenerateError> {
        let base = Self.normalizedBaseURL(baseURLString)
        guard let url = URL(string: "\(base)/api/generate") else {
            return .failure(.invalidURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        Self.applyAuthorization(to: &request, apiKey: apiKey)
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
                let key = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if OllamaModelPreference.isCloudModel(model), key.isEmpty {
                    return .failure(.network("Cloud model returned no text — add your API key under Settings → Connections."))
                }
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
    /// Ollama cloud catalog models (need an API key from ollama.com).
    static func isCloudModel(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains(":cloud") || lower.hasSuffix("-cloud") || lower.contains("remote")
    }

    /// Models that are slow, huge, or remote — poor fit for one-line menu bar summaries.
    static func isHeavyModel(_ name: String) -> Bool {
        let lower = name.lowercased()
        let heavyMarkers = [
            "llama4", "llama-4", "scout", "cloud", "remote",
            "70b", "72b", "80b", "90b", "405b", "108b", "235b",
            "8x22", "8x7b", "mixtral:8x", "command-r-plus", "deepseek-r1",
        ]
        if heavyMarkers.contains(where: { lower.contains($0) }) { return true }
        if lower.range(of: #":([3-9]\d|[1-9]\d{2,})b"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }

    /// Higher score = better default for short summaries.
    static func summaryScore(for name: String) -> Int {
        if isHeavyModel(name) { return -1_000 }
        let lower = name.lowercased()
        let tiers: [(String, Int)] = [
            ("gemma3:270m", 95), ("gemma3:1b", 92),
            ("phi4", 94), ("phi3.5", 93), ("phi3", 92), ("phi:", 90), ("phi-", 90),
            ("gemma2:2b", 90), ("gemma2:2b-", 90),
            ("llama3.2:1b", 88), ("llama3.2:3b", 86),
            ("qwen2.5:0.5b", 90), ("qwen2.5:1.5b", 88), ("qwen2.5:3b", 85),
            ("qwen3:0.6b", 88), ("qwen3:1.7b", 86),
            ("mistral-small", 78), ("mistral:7b", 72), ("mistral-7b", 72),
            ("llama3.2", 80), ("gemma2", 75), ("gemma3", 74), ("qwen2.5", 70),
            (":1b", 55), (":2b", 58), (":3b", 50), ("-1b", 55), ("-2b", 58), ("-3b", 50),
            (":7b", 35), ("-7b", 35),
        ]
        var score = 10
        for (needle, points) in tiers where lower.contains(needle) {
            score = max(score, points)
        }
        if lower.contains("13b") || lower.contains("14b") { score -= 40 }
        if lower.contains("32b") || lower.contains("34b") { score -= 70 }
        if lower.contains("embed") { score -= 80 }
        if lower.contains("reasoning") || lower.contains("-reason") { score -= 25 }
        return score
    }

    static func sortedForSummary(_ models: [OllamaModelInfo]) -> [OllamaModelInfo] {
        models.sorted { lhs, rhs in
            let l = summaryScore(for: lhs.name)
            let r = summaryScore(for: rhs.name)
            if l != r { return l > r }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func bestModelName(from models: [OllamaModelInfo]) -> String? {
        sortedForSummary(models).first?.name
    }

    static func preferredLightModel(from models: [OllamaModelInfo]) -> String? {
        sortedForSummary(models).first { !isHeavyModel($0.name) }?.name
            ?? bestModelName(from: models)
    }
}
