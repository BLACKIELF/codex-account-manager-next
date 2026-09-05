import Foundation

struct HubTask: Decodable, Equatable {
    let accountAlias: String?
    let state: String
    let createdAt: Date
    let updatedAt: Date
    var approvalExpiresAt: Date? = nil
    var approvalExpired: Bool? = nil

    private static let accountBusyStates: Set<String> = [
        "awaiting_approval", "approved", "queued", "starting", "running", "cancel_requested", "uncertain",
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
    static let maximumFutureClockSkew: TimeInterval = 5

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
                    || (task.createdAt == current.createdAt && task.updatedAt > current.updatedAt)
                {
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
        let signedAge = now.timeIntervalSince(task.updatedAt)
        guard signedAge >= -maximumFutureClockSkew else {
            return HubAccountTaskStatus(phase: .uncertain, updatedAt: task.updatedAt)
        }
        let age = max(0, signedAge)
        switch rawState {
        case "awaiting_approval":
            if task.approvalExpired == true
                || task.approvalExpiresAt.map({ $0 <= now }) == true
            {
                return HubAccountTaskStatus(phase: .idle, updatedAt: nil)
            }
            return activeStatus(.awaitingApproval, task: task)
        case "approved", "queued", "starting":
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
            (-maximumFutureClockSkew...overviewFreshnessTTL).contains(now.timeIntervalSince(lastSuccessfulRefreshAt)),
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
        return try makeDecoder().decode(HubOverview.self, from: data)
    }

    /// `JSONDecoder` is mutable and not safe to share across concurrent refresh requests.
    private static func makeDecoder() -> JSONDecoder {
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
    }
}

enum HubWarmUpGateSelfTest {
    static func run() -> Bool {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var failures: [String] = []

        func task(
            alias: String? = "account-a",
            state: String,
            createdAt: Date? = nil,
            updatedAt: Date? = nil,
            approvalExpiresAt: Date? = nil,
            approvalExpired: Bool? = nil
        ) -> HubTask {
            HubTask(
                accountAlias: alias,
                state: state,
                createdAt: createdAt ?? now.addingTimeInterval(-20),
                updatedAt: updatedAt ?? now.addingTimeInterval(-10),
                approvalExpiresAt: approvalExpiresAt,
                approvalExpired: approvalExpired
            )
        }

        func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
            if !condition() { failures.append(name) }
        }

        let busyStates: [(String, HubAccountTaskPhase)] = [
            ("awaiting_approval", .awaitingApproval),
            ("approved", .starting),
            ("queued", .starting),
            ("starting", .starting),
            ("running", .running),
            ("cancel_requested", .cancelRequested),
            ("uncertain", .uncertain),
        ]
        for (rawState, expectedPhase) in busyStates {
            let status = HubAccountTaskStatusResolver.status(for: task(state: rawState), now: now)
            expect(HubTask.blocksAccountWarmUp(state: rawState), "busy predicate: \(rawState)")
            expect(status.phase == expectedPhase, "busy phase: \(rawState)")
            expect(status.blocksLocalCLI, "busy blocks local CLI: \(rawState)")
        }

        let unknown = HubAccountTaskStatusResolver.status(for: task(state: "future_state"), now: now)
        expect(unknown.phase == .uncertain && unknown.blocksLocalCLI, "unknown state fails closed")

        let expiredByDate = HubAccountTaskStatusResolver.status(
            for: task(state: "awaiting_approval", approvalExpiresAt: now.addingTimeInterval(-1)),
            now: now
        )
        let expiredByFlag = HubAccountTaskStatusResolver.status(
            for: task(state: "awaiting_approval", approvalExpired: true),
            now: now
        )
        expect(expiredByDate.phase == .idle && !expiredByDate.blocksLocalCLI, "expired approval date is idle")
        expect(expiredByFlag.phase == .idle && !expiredByFlag.blocksLocalCLI, "expired approval flag is idle")

        for terminalState in ["succeeded", "failed", "cancelled", "blocked_configuration"] {
            let recent = HubAccountTaskStatusResolver.status(for: task(state: terminalState), now: now)
            let expired = HubAccountTaskStatusResolver.status(
                for: task(
                    state: terminalState,
                    updatedAt: now.addingTimeInterval(-HubAccountTaskStatusResolver.terminalFeedbackTTL - 1)
                ),
                now: now
            )
            expect(!recent.blocksLocalCLI && recent.phase != .idle, "recent terminal feedback: \(terminalState)")
            expect(expired.phase == .idle && !expired.blocksLocalCLI, "expired terminal feedback: \(terminalState)")
        }

        let freshRefresh = now.addingTimeInterval(-1)
        let offline = HubAccountTaskStatusResolver.status(
            forAccountAlias: "account-a",
            tasksByAlias: [:],
            connectionState: .offline,
            lastSuccessfulRefreshAt: freshRefresh,
            now: now
        )
        let stale = HubAccountTaskStatusResolver.status(
            forAccountAlias: "account-a",
            tasksByAlias: [:],
            connectionState: .online,
            lastSuccessfulRefreshAt: now.addingTimeInterval(-HubAccountTaskStatusResolver.overviewFreshnessTTL - 1),
            now: now
        )
        let missingAlias = HubAccountTaskStatusResolver.status(
            forAccountAlias: "  \n ",
            tasksByAlias: [:],
            connectionState: .online,
            lastSuccessfulRefreshAt: freshRefresh,
            now: now
        )
        for (name, status) in [("offline", offline), ("stale overview", stale), ("missing alias", missingAlias)] {
            expect(status.phase == .unavailable && status.blocksLocalCLI, "\(name) is unavailable")
        }

        let futureTask = HubAccountTaskStatusResolver.status(
            for: task(
                state: "succeeded",
                updatedAt: now.addingTimeInterval(HubAccountTaskStatusResolver.maximumFutureClockSkew + 1)
            ),
            now: now
        )
        let futureOverview = HubAccountTaskStatusResolver.status(
            forAccountAlias: "account-a",
            tasksByAlias: [:],
            connectionState: .online,
            lastSuccessfulRefreshAt: now.addingTimeInterval(HubAccountTaskStatusResolver.maximumFutureClockSkew + 1),
            now: now
        )
        expect(futureTask.phase == .uncertain && futureTask.blocksLocalCLI, "future task timestamp fails closed")
        expect(futureOverview.phase == .unavailable && futureOverview.blocksLocalCLI, "future overview timestamp fails closed")

        let olderBusy = task(
            alias: " Account-A ",
            state: "running",
            createdAt: now.addingTimeInterval(-100),
            updatedAt: now.addingTimeInterval(-5)
        )
        let newerTerminal = task(
            alias: "account-a",
            state: "succeeded",
            createdAt: now.addingTimeInterval(-20),
            updatedAt: now.addingTimeInterval(-1)
        )
        let latest = HubAccountTaskStatusResolver.latestTasksByAlias([olderBusy, newerTerminal], now: now)
        expect(latest["account-a"] == olderBusy, "busy task wins over newer terminal task")
        expect(HubAccountTaskStatusResolver.canonicalAlias("  AcCoUnT-A\n") == "account-a", "alias normalization")
        let normalizedStatus = HubAccountTaskStatusResolver.status(
            forAccountAlias: " ACCOUNT-A ",
            tasksByAlias: latest,
            connectionState: .online,
            lastSuccessfulRefreshAt: freshRefresh,
            now: now
        )
        expect(normalizedStatus.phase == .running && normalizedStatus.blocksLocalCLI, "normalized alias lookup")

        if failures.isEmpty {
            print("Hub warm-up gate self-test passed")
            return true
        }
        print("Hub warm-up gate self-test failed: \(failures.joined(separator: ", "))")
        return false
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
