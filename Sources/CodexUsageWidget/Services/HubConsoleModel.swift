import Foundation

struct HubTask: Decodable, Equatable {
    let accountAlias: String?
    let state: String
    let createdAt: Date
    let updatedAt: Date
    var approvalExpiresAt: Date? = nil
    var approvalExpired: Bool? = nil

    private static let accountBusyStates: Set<String> = [
        "awaiting_approval", "starting", "running", "cancel_requested", "uncertain"
    ]

    static func blocksAccountWarmUp(state: String) -> Bool {
        accountBusyStates.contains(state.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    var blocksAccountWarmUp: Bool {
        Self.blocksAccountWarmUp(state: state)
    }
}

struct HubOverview: Decodable {
    let tasks: [HubTask]?
}

enum HubWarmUpAvailability: Equatable {
    case idle
    case busy
    case unavailable
}

enum HubConnectionState: Equatable {
    case loading
    case online
    case offline
}

enum HubAccountTaskPhase: Equatable {
    case idle
    case awaitingApproval
    case starting
    case running
    case cancelRequested
    case uncertain
    case succeeded
    case failed
    case cancelled
    case unavailable
}

struct HubAccountTaskStatus: Equatable {
    let phase: HubAccountTaskPhase
    let updatedAt: Date?

    var localizedLabel: String {
        switch phase {
        case .idle: return "未运行"
        case .awaitingApproval: return "待批准"
        case .starting: return "准备中"
        case .running: return "工作进行中"
        case .cancelRequested: return "正在请求取消"
        case .uncertain, .unavailable: return "状态待确认"
        case .succeeded: return "任务成功"
        case .failed: return "任务失败"
        case .cancelled: return "任务已取消"
        }
    }

    /// Hub 明确报告的占用状态。连接不可用另由 `blocksLocalCLI` fail-closed。
    var isBusy: Bool {
        switch phase {
        case .awaitingApproval, .starting, .running, .cancelRequested, .uncertain:
            return true
        case .idle, .succeeded, .failed, .cancelled, .unavailable:
            return false
        }
    }

    /// 可信映射和新鲜概览存在，且同别名没有活跃任务时才开放 CLI。
    var blocksLocalCLI: Bool {
        isBusy || phase == .unavailable
    }
}

enum HubAccountTaskStatusResolver {
    static let terminalFeedbackTTL: TimeInterval = 2 * 60
    static let overviewFreshnessTTL: TimeInterval = 30

    static func canonicalAlias(_ alias: String) -> String {
        alias.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func latestTasksByAlias(_ tasks: [HubTask], now: Date = Date()) -> [String: HubTask] {
        var result: [String: HubTask] = [:]
        for task in tasks {
            guard let rawAlias = task.accountAlias else { continue }
            let alias = canonicalAlias(rawAlias)
            guard !alias.isEmpty else { continue }
            if let current = result[alias] {
                let taskIsBusy = status(for: task, now: now).isBusy
                let currentIsBusy = status(for: current, now: now).isBusy
                if taskIsBusy != currentIsBusy {
                    if taskIsBusy { result[alias] = task }
                } else if task.createdAt > current.createdAt
                    || (task.createdAt == current.createdAt && task.updatedAt > current.updatedAt) {
                    result[alias] = task
                }
            } else {
                result[alias] = task
            }
        }
        return result
    }

    static func status(for task: HubTask?, now: Date) -> HubAccountTaskStatus {
        guard let task else {
            return HubAccountTaskStatus(phase: .idle, updatedAt: nil)
        }

        let rawState = task.state.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let age = max(0, now.timeIntervalSince(task.updatedAt))
        switch rawState {
        case "awaiting_approval":
            if task.approvalExpired == true
                || task.approvalExpiresAt.map({ $0 <= now }) == true {
                return HubAccountTaskStatus(phase: .idle, updatedAt: nil)
            }
            return activeStatus(.awaitingApproval, task: task)
        case "starting":
            return activeStatus(.starting, task: task)
        case "running":
            return activeStatus(.running, task: task)
        case "cancel_requested":
            return activeStatus(.cancelRequested, task: task)
        case "uncertain":
            return HubAccountTaskStatus(phase: .uncertain, updatedAt: task.updatedAt)
        case "succeeded", "completed", "success":
            return terminalStatus(.succeeded, task: task, age: age)
        case "failed", "error", "blocked_configuration":
            return terminalStatus(.failed, task: task, age: age)
        case "cancelled", "canceled":
            return terminalStatus(.cancelled, task: task, age: age)
        default:
            return HubAccountTaskStatus(phase: .uncertain, updatedAt: task.updatedAt)
        }
    }

    static func status(
        forAccountAlias accountAlias: String?,
        tasksByAlias: [String: HubTask],
        connectionState: HubConnectionState,
        lastSuccessfulRefreshAt: Date?,
        now: Date
    ) -> HubAccountTaskStatus {
        guard connectionState == .online,
              let lastSuccessfulRefreshAt,
              now.timeIntervalSince(lastSuccessfulRefreshAt) <= overviewFreshnessTTL,
              let accountAlias,
              !canonicalAlias(accountAlias).isEmpty
        else {
            return HubAccountTaskStatus(phase: .unavailable, updatedAt: nil)
        }
        return status(for: tasksByAlias[canonicalAlias(accountAlias)], now: now)
    }

    private static func activeStatus(
        _ phase: HubAccountTaskPhase,
        task: HubTask
    ) -> HubAccountTaskStatus {
        return HubAccountTaskStatus(phase: phase, updatedAt: task.updatedAt)
    }

    private static func terminalStatus(
        _ phase: HubAccountTaskPhase,
        task: HubTask,
        age: TimeInterval
    ) -> HubAccountTaskStatus {
        guard age <= terminalFeedbackTTL else {
            return HubAccountTaskStatus(phase: .idle, updatedAt: nil)
        }
        return HubAccountTaskStatus(phase: phase, updatedAt: task.updatedAt)
    }
}

@MainActor
final class HubAccountTaskStatusModel: ObservableObject {
    static let pollingInterval: TimeInterval = 10

    @Published private(set) var connectionState: HubConnectionState = .loading
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastSuccessfulRefreshAt: Date?

    private var tasksByAlias: [String: HubTask] = [:]
    private var pollingTask: Task<Void, Never>?

    deinit {
        pollingTask?.cancel()
    }

    func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self != nil else { return }
                await self?.refresh()
                guard !Task.isCancelled else { return }
                do {
                    try await Task.sleep(nanoseconds: UInt64(Self.pollingInterval * 1_000_000_000))
                } catch {
                    return
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func restartPolling() {
        stopPolling()
        startPolling()
    }

    func status(forAccountAlias accountAlias: String?, now: Date = Date()) -> HubAccountTaskStatus {
        HubAccountTaskStatusResolver.status(
            forAccountAlias: accountAlias,
            tasksByAlias: tasksByAlias,
            connectionState: connectionState,
            lastSuccessfulRefreshAt: lastSuccessfulRefreshAt,
            now: now
        )
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let overview = try await HubConsoleModel.fetchInspectionOverview()
            guard !Task.isCancelled else { return }
            tasksByAlias = HubAccountTaskStatusResolver.latestTasksByAlias(overview.tasks ?? [])
            lastSuccessfulRefreshAt = Date()
            connectionState = .online
        } catch {
            guard !Task.isCancelled else { return }
            tasksByAlias = [:]
            connectionState = .offline
        }
    }
}

enum HubConsoleModel {
    private static let overviewURL = URL(string: "http://127.0.0.1:8787/api/overview")!

    static func warmUpAvailability(for accountAlias: String) async -> HubWarmUpAvailability {
        let alias = HubAccountTaskStatusResolver.canonicalAlias(accountAlias)
        guard !alias.isEmpty else { return .unavailable }
        do {
            let overview = try await fetchInspectionOverview()
            let tasks = HubAccountTaskStatusResolver.latestTasksByAlias(overview.tasks ?? [])
            let status = HubAccountTaskStatusResolver.status(for: tasks[alias], now: Date())
            if status.phase == .unavailable { return .unavailable }
            return status.blocksLocalCLI ? .busy : .idle
        } catch {
            return .unavailable
        }
    }

    static func fetchInspectionOverview() async throws -> HubOverview {
        var request = URLRequest(url: overviewURL, timeoutInterval: 6)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode)
        else { throw URLError(.badServerResponse) }
        return try decoder.decode(HubOverview.self, from: data)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = HubDateParsing.parse(raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "无法解析 Hub 时间"
                )
            }
            return date
        }
        return decoder
    }()
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
        fractionalSecondsFormatter.date(from: raw) ?? plainSecondsFormatter.date(from: raw)
    }
}
