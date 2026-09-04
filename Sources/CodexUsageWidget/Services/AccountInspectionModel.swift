import Foundation

struct AccountInspectionProfileConfiguration: Equatable {
    let model: String?
    let reasoningEffort: String?

    var matchesBaseline: Bool {
        model == AccountInspectionModel.baselineModel
            && reasoningEffort == AccountInspectionModel.baselineReasoningEffort
    }
}

struct AccountInspectionAccount: Identifiable, Equatable {
    let alias: String
    let profileID: String
    let planType: String?
    let maskedEmail: String?
    let configuration: AccountInspectionProfileConfiguration
    let fiveHourRemainingPercent: Double?
    let sevenDayRemainingPercent: Double?
    let snapshotFetchedAt: Date?
    let dispatchDisabled: Bool

    var id: String { alias }
}

struct AccountInspectionIssue: Identifiable, Equatable {
    enum Kind: Equatable {
        case staleSnapshot
        case lowQuota
        case configurationDrift
        case dispatchDisabled
    }

    let kind: Kind
    let accountAlias: String
    let detail: String

    var id: String { "\(accountAlias)-\(kind)-\(detail)" }
}

@MainActor
final class AccountInspectionModel: ObservableObject {
    nonisolated static let baselineModel = "gpt-5.6-sol"
    nonisolated static let baselineReasoningEffort = "high"
    nonisolated static let staleSnapshotInterval: TimeInterval = 30 * 60

    @Published private(set) var accounts: [AccountInspectionAccount] = []
    @Published private(set) var issues: [AccountInspectionIssue] = []
    @Published private(set) var refreshedAt: Date?
    @Published private(set) var configurationError: String?

    private struct AccountMapping: Decodable, Equatable {
        let alias: String
        let home: String
        let dispatchDisabled: Bool?
    }

    private struct HubConfiguration: Decodable {
        let accounts: [AccountMapping]
    }

    private struct LocalAccountSource: Equatable {
        let mapping: AccountMapping
        let profileID: String
        let configuration: AccountInspectionProfileConfiguration
    }

    private enum ConfigurationError: LocalizedError {
        case missingConfiguration

        var errorDescription: String? {
            "未配置巡检账号映射（inspection-config-v1.json / CAMNEXT_INSPECTION_CONFIG）"
        }
    }

    private var localSources: [LocalAccountSource] = []
    private var latestProfiles: [CodexProfile] = []

    func refresh(profiles: [CodexProfile]) {
        latestProfiles = profiles
        configurationError = nil

        do {
            localSources = try Self.loadLocalSources()
            rebuildAccounts(now: Date())
            refreshedAt = Date()
        } catch let error as ConfigurationError {
            localSources = []
            accounts = []
            issues = []
            configurationError = error.localizedDescription
        } catch {
            localSources = []
            accounts = []
            issues = []
            configurationError = "无法读取巡检账号映射"
        }
    }

    func updateProfiles(_ profiles: [CodexProfile]) {
        latestProfiles = profiles
        rebuildAccounts(now: Date())
    }

    private func rebuildAccounts(now: Date) {
        let profilesByID = Dictionary(uniqueKeysWithValues: latestProfiles.map { ($0.id, $0) })
        accounts = localSources.map { source in
            let snapshot = profilesByID[source.profileID]?.lastSnapshot
            return AccountInspectionAccount(
                alias: source.mapping.alias,
                profileID: source.profileID,
                planType: snapshot?.planType,
                maskedEmail: Self.maskEmail(snapshot?.email),
                configuration: source.configuration,
                fiveHourRemainingPercent: Self.remainingPercent(snapshot?.fiveHour),
                sevenDayRemainingPercent: Self.remainingPercent(snapshot?.sevenDay),
                snapshotFetchedAt: snapshot?.fetchedAt,
                dispatchDisabled: source.mapping.dispatchDisabled == true
            )
        }
        issues = Self.makeIssues(accounts: accounts, now: now)
    }

    private static func loadLocalSources(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> [LocalAccountSource] {
        let configURL = try hubConfigurationURL(fileManager: fileManager, environment: environment)
        guard fileManager.fileExists(atPath: configURL.path) else {
            throw ConfigurationError.missingConfiguration
        }
        let data = try Data(contentsOf: configURL)
        let payload = try JSONDecoder().decode(HubConfiguration.self, from: data)
        return payload.accounts.compactMap { mapping in
            let alias = mapping.alias.trimmingCharacters(in: .whitespacesAndNewlines)
            let home = URL(fileURLWithPath: mapping.home, isDirectory: true)
            let profileID = home.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !alias.isEmpty, !profileID.isEmpty else { return nil }
            let contents = try? String(
                contentsOf: home.appendingPathComponent("config.toml", isDirectory: false),
                encoding: .utf8
            )
            return LocalAccountSource(
                mapping: AccountMapping(
                    alias: alias,
                    home: mapping.home,
                    dispatchDisabled: mapping.dispatchDisabled
                ),
                profileID: profileID,
                configuration: parseProfileConfiguration(contents ?? "")
            )
        }
    }

    private static func hubConfigurationURL(
        fileManager: FileManager,
        environment: [String: String]
    ) throws -> URL {
        if let override = environment["CAMNEXT_INSPECTION_CONFIG"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: false)
        }
        guard let support = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { throw ConfigurationError.missingConfiguration }
        return support
            .appendingPathComponent("CodexAccountManagerNext", isDirectory: true)
            .appendingPathComponent("inspection-config-v1.json", isDirectory: false)
    }

    nonisolated static func parseProfileConfiguration(_ contents: String) -> AccountInspectionProfileConfiguration {
        var model: String?
        var effort: String?
        for rawLine in contents.split(whereSeparator: { $0.isNewline }) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.hasPrefix("#"), let separator = line.firstIndex(of: "=") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
            guard rawValue.first == "\"", let closingQuote = rawValue.dropFirst().firstIndex(of: "\"") else {
                continue
            }
            let value = String(rawValue[rawValue.index(after: rawValue.startIndex)..<closingQuote])
            if key == "model" { model = value }
            if key == "model_reasoning_effort" { effort = value }
        }
        return AccountInspectionProfileConfiguration(model: model, reasoningEffort: effort)
    }

    nonisolated static func maskEmail(_ email: String?) -> String? {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines),
              let at = email.firstIndex(of: "@"),
              at != email.startIndex,
              email.index(after: at) != email.endIndex
        else { return nil }
        return "\(email[email.startIndex])***@\(email[email.index(after: at)...])"
    }

    nonisolated static func remainingPercent(_ window: CodexQuotaWindowSnapshot?) -> Double? {
        guard let window else { return nil }
        return max(0, min(100, 100 - window.usedPercent))
    }

    nonisolated static func latestTasksByAlias(_ tasks: [HubTask]) -> [String: HubTask] {
        HubAccountTaskStatusResolver.latestTasksByAlias(tasks)
    }

    nonisolated static func makeIssues(
        accounts: [AccountInspectionAccount],
        now: Date
    ) -> [AccountInspectionIssue] {
        accounts.flatMap { account -> [AccountInspectionIssue] in
            var result: [AccountInspectionIssue] = []
            if let fetchedAt = account.snapshotFetchedAt,
               now.timeIntervalSince(fetchedAt) > staleSnapshotInterval {
                let minutes = max(31, Int(now.timeIntervalSince(fetchedAt) / 60))
                result.append(AccountInspectionIssue(
                    kind: .staleSnapshot,
                    accountAlias: account.alias,
                    detail: "额度快照已超过 30 分钟（\(minutes) 分钟前）"
                ))
            }
            if let remaining = account.fiveHourRemainingPercent, remaining < 20 {
                result.append(AccountInspectionIssue(
                    kind: .lowQuota,
                    accountAlias: account.alias,
                    detail: "5h 剩余低于 20%"
                ))
            }
            if let remaining = account.sevenDayRemainingPercent, remaining < 20 {
                result.append(AccountInspectionIssue(
                    kind: .lowQuota,
                    accountAlias: account.alias,
                    detail: "7d 剩余低于 20%"
                ))
            }
            if !account.configuration.matchesBaseline {
                result.append(AccountInspectionIssue(
                    kind: .configurationDrift,
                    accountAlias: account.alias,
                    detail: "模型配置偏离基线"
                ))
            }
            if account.dispatchDisabled {
                result.append(AccountInspectionIssue(
                    kind: .dispatchDisabled,
                    accountAlias: account.alias,
                    detail: "派单已停用"
                ))
            }
            return result
        }
    }
}

enum AccountInspectionSelfTest {
    static func run() -> Bool {
        let baseline = AccountInspectionModel.parseProfileConfiguration(
            "model = \"gpt-5.6-sol\"\nmodel_reasoning_effort = \"high\"\n"
        )
        let drift = AccountInspectionModel.parseProfileConfiguration(
            "model = \"another-model\" # comment\nmodel_reasoning_effort = \"medium\"\n"
        )
        let testEmail = ["alice", "example.com"].joined(separator: "@")
        let now = Date(timeIntervalSinceReferenceDate: 100_000)
        let issueAccount = AccountInspectionAccount(
            alias: "test-account",
            profileID: "test-profile",
            planType: "plus",
            maskedEmail: "a***@example.com",
            configuration: drift,
            fiveHourRemainingPercent: 19.9,
            sevenDayRemainingPercent: 20,
            snapshotFetchedAt: now.addingTimeInterval(-1_801),
            dispatchDisabled: true
        )
        let issueKinds = AccountInspectionModel.makeIssues(accounts: [issueAccount], now: now).map(\.kind)
        let task = { (alias: String, state: String, createdOffset: TimeInterval, updatedOffset: TimeInterval) in
            HubTask(
                accountAlias: alias,
                state: state,
                createdAt: now.addingTimeInterval(createdOffset),
                updatedAt: now.addingTimeInterval(updatedOffset)
            )
        }
        let stateMappingPassed = [
            ("awaiting_approval", "待批准"),
            ("starting", "准备中"),
            ("running", "工作进行中"),
            ("cancel_requested", "正在请求取消"),
            ("uncertain", "状态待确认"),
            ("succeeded", "任务成功"),
            ("failed", "任务失败")
        ].allSatisfy { state, label in
            HubAccountTaskStatusResolver.status(
                for: task("alpha", state, -20, -10),
                now: now
            ).localizedLabel == label
        }
        let busyStates = ["awaiting_approval", "starting", "running", "cancel_requested", "uncertain"]
        let busyPassed = busyStates.allSatisfy {
            HubAccountTaskStatusResolver.status(
                for: task("alpha", $0, -20, -10),
                now: now
            ).isBusy
        }
        let freshTerminal = HubAccountTaskStatusResolver.status(
            for: task("alpha", "succeeded", -20, -119),
            now: now
        )
        let expiredTerminal = HubAccountTaskStatusResolver.status(
            for: task("alpha", "succeeded", -200, -121),
            now: now
        )
        let staleActive = HubAccountTaskStatusResolver.status(
            for: task("alpha", "running", -200, -121),
            now: now
        )
        let newestByAlias = HubAccountTaskStatusResolver.latestTasksByAlias([
            task(" Alpha ", "running", -30, -2),
            task("alpha", "succeeded", -10, -3),
            task("beta", "starting", -5, -4)
        ], now: now)
        let expiredApproval = HubTask(
            accountAlias: "alpha",
            state: "awaiting_approval",
            createdAt: now.addingTimeInterval(-5),
            updatedAt: now.addingTimeInterval(-5),
            approvalExpiresAt: now.addingTimeInterval(-1),
            approvalExpired: true
        )
        let activeBeatsExpiredApproval = HubAccountTaskStatusResolver.latestTasksByAlias([
            task("alpha", "running", -30, -20),
            expiredApproval
        ], now: now)
        let newestTerminalByAlias = HubAccountTaskStatusResolver.latestTasksByAlias([
            task("gamma", "failed", -20, -10),
            task("gamma", "succeeded", -5, -4)
        ], now: now)
        let offline = HubAccountTaskStatusResolver.status(
            forAccountAlias: "alpha",
            tasksByAlias: newestByAlias,
            connectionState: .offline,
            lastSuccessfulRefreshAt: now,
            now: now
        )
        let staleOverview = HubAccountTaskStatusResolver.status(
            forAccountAlias: "alpha",
            tasksByAlias: newestByAlias,
            connectionState: .online,
            lastSuccessfulRefreshAt: now.addingTimeInterval(-31),
            now: now
        )
        let passed = baseline.matchesBaseline
            && !drift.matchesBaseline
            && AccountInspectionModel.maskEmail(testEmail) == "a***@example.com"
            && AccountInspectionModel.maskEmail("invalid") == nil
            && issueKinds == [.staleSnapshot, .lowQuota, .configurationDrift, .dispatchDisabled]
            && stateMappingPassed
            && busyPassed
            && freshTerminal.phase == .succeeded
            && expiredTerminal.phase == .idle
            && staleActive.phase == .running
            && staleActive.blocksLocalCLI
            && HubAccountTaskStatusResolver.status(for: expiredApproval, now: now).phase == .idle
            && newestByAlias["alpha"]?.state == "running"
            && newestByAlias["beta"]?.state == "starting"
            && activeBeatsExpiredApproval["alpha"]?.state == "running"
            && newestTerminalByAlias["gamma"]?.state == "succeeded"
            && offline.localizedLabel == "状态待确认"
            && offline.blocksLocalCLI
            && staleOverview.phase == .unavailable
            && staleOverview.blocksLocalCLI
        if !passed { print("Account inspection self-test failed") }
        return passed
    }
}
