import Foundation

/// Read-only Pieces OS client: recent workstream summaries → “Next Steps” bullets.
final class PiecesService: @unchecked Sendable {
    static let shared = PiecesService()

    private let applicationID = "app.missingpieces"
    private let healthSession: URLSession
    private let fetchSession: URLSession
    private var cachedBaseURL: String?
    private let portCacheKey = "piecesOSPort"

    private static let candidatePorts = [39300, 1000]

    private init() {
        let healthConfig = URLSessionConfiguration.ephemeral
        healthConfig.timeoutIntervalForRequest = 2.5
        healthConfig.timeoutIntervalForResource = 3
        self.healthSession = URLSession(configuration: healthConfig)

        let fetchConfig = URLSessionConfiguration.ephemeral
        fetchConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        fetchConfig.urlCache = nil
        fetchConfig.httpCookieStorage = nil
        fetchConfig.timeoutIntervalForRequest = 8
        fetchConfig.timeoutIntervalForResource = 20
        self.fetchSession = URLSession(configuration: fetchConfig)
    }

    func isAvailable() async -> Bool {
        await resolveBaseURL() != nil
    }

    func clearConnectivityCache() {
        cachedBaseURL = nil
    }

    func fetchNextSteps(
        lookbackDays: Int = 7,
        maxSummaries: Int = 6,
        maxStepsPerSummary: Int = 2,
        maxTotal: Int = 12
    ) async throws -> [PiecesNextStep] {
        try await withTimeout(seconds: 18) {
            try await self.fetchNextStepsWork(
                lookbackDays: lookbackDays,
                maxSummaries: maxSummaries,
                maxStepsPerSummary: maxStepsPerSummary,
                maxTotal: maxTotal
            )
        }
    }

    private func fetchNextStepsWork(
        lookbackDays: Int,
        maxSummaries: Int,
        maxStepsPerSummary: Int,
        maxTotal: Int
    ) async throws -> [PiecesNextStep] {
        guard await resolveBaseURL() != nil else { throw PiecesError.notAvailable }

        let fromDate = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date()
        let fromISO = ISO8601DateFormatter().string(from: fromDate)

        let summaryIDs = try await listRecentSummaryIDs(fromISO: fromISO, limit: maxSummaries)
        var results: [PiecesNextStep] = []
        var seenSteps = Set<String>()
        var seenSessions = Set<String>()

        for summaryID in summaryIDs {
            try Task.checkCancellation()
            guard results.count < maxTotal else { break }

            let summary = try await getWorkstreamSummary(id: summaryID)
            let sessionName = (summary["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = sessionName?.isEmpty == false ? sessionName! : "Recent work session"
            let sessionKey = title.lowercased()
            guard seenSessions.insert(sessionKey).inserted else { continue }

            var stepsFromSummary = 0
            for annotationID in annotationIDsNewestFirst(from: summary) {
                try Task.checkCancellation()
                guard results.count < maxTotal, stepsFromSummary < maxStepsPerSummary else { break }

                let annotation = try await getAnnotation(id: annotationID)
                guard (annotation["type"] as? String) == "SUMMARY",
                      let text = annotation["text"] as? String else { continue }

                for step in PiecesNextStepsParser.parse(from: text) {
                    guard stepsFromSummary < maxStepsPerSummary, results.count < maxTotal else { break }
                    let key = step.lowercased()
                    guard seenSteps.insert(key).inserted else { continue }
                    results.append(
                        PiecesNextStep(
                            summaryID: summaryID,
                            sessionName: title,
                            stepText: step
                        )
                    )
                    stepsFromSummary += 1
                }

                // Only trust the newest SUMMARY annotation for this work session.
                break
            }
        }

        return results
    }

    // MARK: - Workstream summaries

    private func listRecentSummaryIDs(fromISO: String, limit: Int) async throws -> [String] {
        let payload: [String: Any] = [
            "material_type": "WORKSTREAM_SUMMARIES",
            "limit": limit,
            "updated": ["from": fromISO],
        ]
        let data = try await postJSON("/materials/identifiers", body: payload)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids = json["identifiers"] as? [String] else {
            throw PiecesError.unexpectedResponse
        }
        return ids
    }

    private func getWorkstreamSummary(id: String) async throws -> [String: Any] {
        try await getJSON("/workstream_summary/\(id)")
    }

    private func getAnnotation(id: String) async throws -> [String: Any] {
        try await getJSON("/annotation/\(id)")
    }

    private func annotationIDsNewestFirst(from summary: [String: Any]) -> [String] {
        guard let annotations = summary["annotations"] as? [String: Any],
              let indices = annotations["indices"] as? [String: Any] else {
            return []
        }

        return indices.compactMap { id, indexValue -> (String, Int)? in
            guard let index = indexValue as? Int else { return nil }
            return (id, index)
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)
    }

    // MARK: - Port discovery

    private func resolveBaseURL() async -> String? {
        if let cached = cachedBaseURL, await healthOK(baseURL: cached) {
            return cached
        }
        cachedBaseURL = nil

        var ports: [Int] = []
        if let savedPort = UserDefaults.standard.object(forKey: portCacheKey) as? Int {
            ports.append(savedPort)
        }
        ports.append(contentsOf: Self.candidatePorts)

        let uniquePorts = Array(Set(ports))
        let found = await firstHealthyBaseURL(ports: uniquePorts)
        if let found, let port = URL(string: found)?.port {
            cacheBaseURL(found, port: port)
        }
        return found
    }

    private func firstHealthyBaseURL(ports: [Int]) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            for port in ports {
                group.addTask {
                    let candidate = Self.baseURL(port: port)
                    if await self.healthOK(baseURL: candidate) {
                        return candidate
                    }
                    return nil
                }
            }

            for await match in group {
                if let match {
                    group.cancelAll()
                    return match
                }
            }
            return nil
        }
    }

    private func cacheBaseURL(_ url: String, port: Int) {
        cachedBaseURL = url
        UserDefaults.standard.set(port, forKey: portCacheKey)
    }

    private static func baseURL(port: Int) -> String {
        "http://127.0.0.1:\(port)"
    }

    private func healthOK(baseURL: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/.well-known/health") else { return false }
        do {
            let (_, response) = try await healthSession.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // MARK: - HTTP

    private func getJSON(_ path: String) async throws -> [String: Any] {
        guard let base = await resolveBaseURL() else { throw PiecesError.notAvailable }
        guard let url = URL(string: "\(base)\(path)") else { throw PiecesError.invalidURL }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(applicationID, forHTTPHeaderField: "X-Application-ID")
        let (data, response) = try await fetchSession.data(for: request)
        try validateHTTP(response, data: data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PiecesError.unexpectedResponse
        }
        return json
    }

    private func postJSON(_ path: String, body: [String: Any]) async throws -> Data {
        guard let base = await resolveBaseURL() else { throw PiecesError.notAvailable }
        guard let url = URL(string: "\(base)\(path)") else { throw PiecesError.invalidURL }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(applicationID, forHTTPHeaderField: "X-Application-ID")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await fetchSession.data(for: request)
        try validateHTTP(response, data: data)
        return data
    }

    private func validateHTTP(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw PiecesError.requestFailed
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw PiecesError.httpStatus(http.statusCode, body: body)
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw PiecesError.timedOut
            }
            guard let value = try await group.next() else {
                throw PiecesError.timedOut
            }
            group.cancelAll()
            return value
        }
    }

    enum PiecesError: LocalizedError {
        case invalidURL
        case notAvailable
        case requestFailed
        case unexpectedResponse
        case timedOut
        case httpStatus(Int, body: String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid Pieces OS URL."
            case .notAvailable:
                return "Pieces OS is not reachable. Open Pieces OS and try again."
            case .requestFailed:
                return "Pieces OS request failed."
            case .unexpectedResponse:
                return "Unexpected response from Pieces OS."
            case .timedOut:
                return "Pieces took too long to respond. Try again."
            case .httpStatus(let code, let body):
                let snippet = body.prefix(120)
                return "Pieces OS returned \(code)\(snippet.isEmpty ? "" : ": \(snippet)")"
            }
        }
    }
}
