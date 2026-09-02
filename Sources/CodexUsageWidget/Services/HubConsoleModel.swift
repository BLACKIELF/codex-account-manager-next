import Foundation

struct HubTask: Identifiable, Codable, Equatable {
    let id: String
    let version: Int
    let agent: String
    let project: String
    let accountAlias: String?
    let state: String
    let actionHash: String?
    let canResume: Bool
    let reasonCode: String?
    let createdAt: Date
    let updatedAt: Date
    let approvalExpiresAt: Date?
    let resultNote: String?

    private static let accountBusyStates: Set<String> = [
        "awaiting_approval", "starting", "running", "cancel_requested", "uncertain"
    ]

    static func blocksAccountWarmUp(state: String) -> Bool {
        accountBusyStates.contains(state)
    }

    var blocksAccountWarmUp: Bool {
        Self.blocksAccountWarmUp(state: state)
    }

    private enum CodingKeys: String, CodingKey {
        case id, version, agent, project, accountAlias, state, actionHash, canResume, reasonCode
        case createdAt, updatedAt, approvalExpiresAt, resultNote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        version = try container.decode(Int.self, forKey: .version)
        agent = try container.decode(String.self, forKey: .agent)
        project = try container.decode(String.self, forKey: .project)
        accountAlias = try container.decodeIfPresent(String.self, forKey: .accountAlias)
        state = try container.decode(String.self, forKey: .state)
        actionHash = try container.decodeIfPresent(String.self, forKey: .actionHash)
        canResume = try container.decode(Bool.self, forKey: .canResume)
        reasonCode = try container.decodeIfPresent(String.self, forKey: .reasonCode)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        resultNote = try? container.decodeIfPresent(String.self, forKey: .resultNote)

        let rawExpiry = try? container.decodeIfPresent(String.self, forKey: .approvalExpiresAt)
        if let rawExpiry,
           rawExpiry != "0001-01-01T00:00:00Z",
           let parsed = HubDateParsing.parse(rawExpiry),
           Calendar(identifier: .iso8601).component(.year, from: parsed) > 1 {
            approvalExpiresAt = parsed
        } else {
            approvalExpiresAt = nil
        }
    }
}

struct HubObserverStatus: Codable, Equatable {
    var mode: String?
    var code: String?
    var updatedAt: Date?
}

struct HubThread: Identifiable, Codable, Equatable {
    var id: String { publicRef }
    let publicRef: String
    let title: String?
    let sourceKind: String?
    let projectAlias: String?
    let runtimeState: String?
    let aggregateState: String?
    let latestTurnState: String?
    let reviewState: String?
    let updatedAt: Date?
    let isSubagent: Bool?
    let rootPublicRef: String?
}

struct HubOverview: Codable, Equatable {
    var agents: [String]?
    var accounts: [String]?
    var projects: [String]?
    var tasks: [HubTask]?
}

struct HubCodexOverview: Codable, Equatable {
    var observer: HubObserverStatus?
    var threads: [HubThread]?
}

private struct HubErrorBody: Codable {
    var error: String?
}

enum HubConnectionState: Equatable {
    case idle
    case online
    case offline(String)
}

enum HubWarmUpAvailability: Equatable {
    case idle
    case busy
    case unavailable
}

enum HubConsoleError: LocalizedError {
    case badURL
    case http(status: Int, code: String?)
    case decoding

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "hub 地址不对，去设置里检查"
        case .http(let status, let code):
            switch (status, code) {
            case (401, _):
                return "内网 hub 拒绝连接，请检查服务配置"
            case (403, _):
                return "hub 拒绝了请求来源"
            case (400, _):
                return "hub 认为请求不合法"
            case (404, _):
                return "hub 上找不到这个任务或线程"
            case (409, _):
                return "任务状态刚变化，刷新后重试"
            case (503, _):
                return "hub 的 Codex 看板还没就绪"
            default:
                return "hub 返回 \(status)\(code.map { "（\($0)）" } ?? "")"
            }
        case .decoding:
            return "hub 返回的数据格式不对"
        }
    }
}

@MainActor
final class HubConsoleModel: ObservableObject {
    static let defaultBaseURL = "http://127.0.0.1:8787"
    static let baseURLKey = "CodexManagerNext.hub.baseURL"
    static let enabledKey = "CodexManagerNext.hub.console.enabled"
    static let pollInterval: TimeInterval = 5

    @Published private(set) var tasks: [HubTask] = []
    @Published private(set) var threads: [HubThread] = []
    @Published private(set) var accounts: [String] = []
    @Published private(set) var projects: [String] = []
    @Published private(set) var observerMode: String?
    @Published private(set) var observerCode: String?
    @Published private(set) var connectionState: HubConnectionState = .idle
    @Published private(set) var isRefreshing = false
    @Published private(set) var inFlightActions: Set<String> = []
    @Published private(set) var lastActionMessage: String?
    @Published private(set) var lastRefreshedAt: Date?
    @Published private(set) var isEnabled: Bool
    @Published private(set) var baseURL: String

    private var pollingTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        let storedBaseURL = defaults.string(forKey: Self.baseURLKey)
        baseURL = Self.normalizedBaseURL(storedBaseURL ?? Self.defaultBaseURL)
        defaults.removeObject(forKey: "CodexManagerNext.hub.token")
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    var isOnline: Bool {
        if case .online = connectionState { return true }
        return false
    }

    var connectionLabel: String {
        switch connectionState {
        case .idle:
            return "还没连接"
        case .online:
            return "已连接"
        case .offline(let message):
            return message
        }
    }

    var observerLabel: String? {
        guard isOnline else { return nil }
        if observerMode == "shared_live" {
            return "已连上 Mac 的 Codex"
        }
        return "还没连上 Mac 的 Codex（只能看历史）"
    }

    func startPolling() {
        guard isEnabled, pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshAll()
                let interval = Self.pollInterval * 1_000_000_000
                try? await Task.sleep(nanoseconds: UInt64(interval))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refreshNow() {
        Task { await refreshAll() }
    }

    func refreshAll() async {
        guard isEnabled else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let overview = try await fetch(HubOverview.self, path: "/api/overview")
            tasks = (overview.tasks ?? []).sorted { $0.createdAt > $1.createdAt }
            accounts = overview.accounts ?? []
            projects = overview.projects ?? []
            connectionState = .online
            lastRefreshedAt = Date()
        } catch {
            connectionState = .offline(Self.message(for: error))
        }
        do {
            let codexOverview = try await fetch(HubCodexOverview.self, path: "/api/codex/overview")
            threads = (codexOverview.threads ?? []).sorted {
                ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
            }
            observerMode = codexOverview.observer?.mode
            observerCode = codexOverview.observer?.code
        } catch {
            threads = []
            observerMode = nil
            observerCode = nil
        }
    }

    func approveTask(_ task: HubTask) {
        guard task.actionHash != nil else {
            lastActionMessage = "这个任务缺少审批凭据，去网页端处理"
            return
        }
        performAction(id: "approve-\(task.id)", successMessage: "已批准，任务开始执行") {
            _ = try await self.post(
                path: "/api/tasks/\(task.id)/approve",
                body: ["requestId": UUID().uuidString, "actionHash": task.actionHash ?? ""]
            )
        }
    }

    func cancelTask(_ task: HubTask) {
        performAction(id: "cancel-\(task.id)", successMessage: "已请求取消") {
            _ = try await self.post(
                path: "/api/tasks/\(task.id)/cancel",
                body: ["requestId": UUID().uuidString, "expectedVersion": task.version]
            )
        }
    }

    func reviewThread(_ thread: HubThread, accepted: Bool) {
        let state = accepted ? "accepted" : "blocked"
        performAction(id: "review-\(thread.id)", successMessage: accepted ? "已标记通过" : "已标记有问题") {
            _ = try await self.post(
                path: "/api/codex/threads/\(thread.publicRef)/review",
                body: ["state": state]
            )
        }
    }

    func openThread(_ thread: HubThread) {
        performAction(id: "open-\(thread.id)", successMessage: "已在 Codex 里打开") {
            _ = try await self.post(path: "/api/codex/threads/\(thread.publicRef)/open", body: nil)
        }
    }

    func updateSettings(baseURL newBaseURL: String, enabled newEnabled: Bool) {
        let defaults = UserDefaults.standard
        let normalized = Self.normalizedBaseURL(newBaseURL)
        defaults.set(normalized, forKey: Self.baseURLKey)
        defaults.set(newEnabled, forKey: Self.enabledKey)
        baseURL = normalized
        let wasEnabled = isEnabled
        isEnabled = newEnabled
        if newEnabled {
            if !wasEnabled || pollingTask == nil {
                refreshNow()
                startPolling()
            }
        } else {
            stopPolling()
            connectionState = .idle
        }
    }

    private func performAction(id: String, successMessage: String, operation: @escaping () async throws -> Void) {
        guard inFlightActions.contains(id) == false else { return }
        inFlightActions.insert(id)
        lastActionMessage = nil
        Task {
            defer { inFlightActions.remove(id) }
            do {
                try await operation()
                lastActionMessage = successMessage
                await refreshAll()
            } catch {
                lastActionMessage = Self.message(for: error)
            }
        }
    }

    private func fetch<T: Decodable>(_ type: T.Type, path: String) async throws -> T {
        let data = try await request(path: path, method: "GET", body: nil)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw HubConsoleError.decoding
        }
    }

    private func post(path: String, body: [String: Any]?) async throws -> Data {
        let data = try await request(path: path, method: "POST", body: body)
        return data
    }

    private func request(path: String, method: String, body: [String: Any]?) async throws -> Data {
        try await Self.request(baseURL: baseURL, path: path, method: method, body: body)
    }

    static func warmUpAvailability(for accountAlias: String) async -> HubWarmUpAvailability {
        let alias = accountAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !alias.isEmpty else { return .unavailable }
        let storedBaseURL = UserDefaults.standard.string(forKey: Self.baseURLKey)
        let baseURL = normalizedBaseURL(storedBaseURL ?? defaultBaseURL)
        do {
            let data = try await request(baseURL: baseURL, path: "/api/overview", method: "GET", body: nil)
            let overview = try decoder.decode(HubOverview.self, from: data)
            let busy = (overview.tasks ?? []).contains {
                $0.accountAlias?.caseInsensitiveCompare(alias) == .orderedSame && $0.blocksAccountWarmUp
            }
            return busy ? .busy : .idle
        } catch {
            return .unavailable
        }
    }

    static func fetchInspectionOverview() async throws -> HubOverview {
        let data = try await request(
            baseURL: defaultBaseURL,
            path: "/api/overview",
            method: "GET",
            body: nil
        )
        return try decoder.decode(HubOverview.self, from: data)
    }

    private static func request(
        baseURL: String,
        path: String,
        method: String,
        body: [String: Any]?
    ) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw HubConsoleError.badURL }
        var request = URLRequest(url: url, timeoutInterval: 6)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError
        where error.code == .cannotConnectToHost || error.code == .cannotFindHost
            || error.code == .timedOut || error.code == .cannotParseResponse
            || error.code == .notConnectedToInternet || error.code == .networkConnectionLost
            || error.code == .dnsLookupFailed {
            throw HubConsoleError.http(status: -1, code: error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw HubConsoleError.http(status: -1, code: nil)
        }
        guard (200..<300).contains(http.statusCode) else {
            let errorBody = try? JSONDecoder().decode(HubErrorBody.self, from: data)
            throw HubConsoleError.http(status: http.statusCode, code: errorBody?.error)
        }
        return data
    }

    static func message(for error: Error) -> String {
        if let hubError = error as? HubConsoleError, let description = hubError.errorDescription {
            if case .http(-1, let underlying) = hubError, let underlying {
                return "连不上 hub（\(underlying)）"
            }
            return description
        }
        return error.localizedDescription
    }

    static func normalizedBaseURL(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { trimmed = defaultBaseURL }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if !trimmed.contains("://") {
            trimmed = "http://" + trimmed
        }
        return trimmed
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = HubDateParsing.parse(raw) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解析时间 \(raw)")
            }
            return date
        }
        return decoder
    }()

    static func parseHubDate(_ raw: String) -> Date? {
        HubDateParsing.parse(raw)
    }
}

enum HubWarmUpGateSelfTest {
    static func run() -> Bool {
        let blocking = ["awaiting_approval", "starting", "running", "cancel_requested", "uncertain"]
        let terminal = ["succeeded", "failed", "cancelled", "blocked_configuration"]
        let passed = blocking.allSatisfy { HubTask.blocksAccountWarmUp(state: $0) }
            && terminal.allSatisfy { !HubTask.blocksAccountWarmUp(state: $0) }
        if !passed { print("Hub warm-up gate self-test failed") }
        return passed
    }
}

private enum HubDateParsing {
    static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let plainSecondsFormatter = ISO8601DateFormatter()

    static func parse(_ raw: String) -> Date? {
        if let date = fractionalSecondsFormatter.date(from: raw) { return date }
        return plainSecondsFormatter.date(from: raw)
    }
}
