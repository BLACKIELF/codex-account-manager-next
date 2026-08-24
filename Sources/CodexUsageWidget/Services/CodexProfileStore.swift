import CryptoKit
import Foundation

struct CodexQuotaWindowSnapshot: Codable, Equatable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Date?

    init(_ window: RateWindow) {
        usedPercent = window.usedPercent
        windowDurationMins = window.windowDurationMins
        resetsAt = window.resetsAt
    }
}

struct CodexAccountSnapshot: Codable, Equatable {
    let accountType: String?
    let planType: String?
    let email: String?
    let accountID: String?
    let limitId: String?
    let limitName: String?
    let fiveHour: CodexQuotaWindowSnapshot?
    let sevenDay: CodexQuotaWindowSnapshot?
    let monthly: CodexQuotaWindowSnapshot?
    let fetchedAt: Date
    let appServerVersion: String?

    init(
        accountType: String?,
        planType: String?,
        email: String?,
        accountID: String? = nil,
        limitId: String?,
        limitName: String?,
        fiveHour: CodexQuotaWindowSnapshot?,
        sevenDay: CodexQuotaWindowSnapshot?,
        monthly: CodexQuotaWindowSnapshot?,
        fetchedAt: Date,
        appServerVersion: String?
    ) {
        self.accountType = accountType
        self.planType = planType
        self.email = email
        self.accountID = accountID
        self.limitId = limitId
        self.limitName = limitName
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.monthly = monthly
        self.fetchedAt = fetchedAt
        self.appServerVersion = appServerVersion
    }
}

struct CodexCredentialIdentity: Equatable {
    let email: String
    let accountID: String
}

struct CodexOfficialProfileSnapshot: Codable, Equatable {
    let accountEmail: String?
    let displayName: String?
    let username: String?
    let lifetimeTokens: Int64?
    let peakDailyTokens: Int64?
    let planType: String?
    let subscriptionActiveUntil: Date?
    let statsAsOf: Date?
    let fetchedAt: Date
}

struct CodexProfile: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var remark: String? = nil
    let codexHomePath: String
    let isSystemProfile: Bool
    let createdAt: Date
    var lastSnapshot: CodexAccountSnapshot?
    var officialProfile: CodexOfficialProfileSnapshot? = nil
    var lastWarmUpAt: Date? = nil
    var lastWarmUpSucceeded: Bool? = nil

    var codexHomeURL: URL {
        URL(fileURLWithPath: codexHomePath, isDirectory: true)
    }

    func matchesRecordedAccount(email: String?) -> Bool {
        guard let expected = Self.normalizedEmail(lastSnapshot?.email) else { return true }
        return Self.normalizedEmail(email) == expected
    }

    func matchesRecordedCredential(_ identity: CodexCredentialIdentity?) -> Bool {
        guard matchesRecordedAccount(email: identity?.email) else { return false }
        guard let expectedAccountID = lastSnapshot?.accountID else { return true }
        return identity?.accountID == expectedAccountID
    }

    var recordedAccountKey: String {
        Self.normalizedEmail(lastSnapshot?.email) ?? "profile:\(id)"
    }

    static func groupsByRecordedAccount(_ profiles: [CodexProfile]) -> [[CodexProfile]] {
        Array(Dictionary(grouping: profiles, by: \.recordedAccountKey).values)
    }

    private static func normalizedEmail(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalized.isEmpty ? nil : normalized
    }
}

struct CodexWarmUpSelection: Equatable {
    var fiveHour: Bool
    var sevenDay: Bool

    var isEnabled: Bool { fiveHour || sevenDay }

    static let none = CodexWarmUpSelection(fiveHour: false, sevenDay: false)

    private static let fiveHourKey = "CodexManagerNext.automaticWarmUp.fiveHour"
    private static let sevenDayKey = "CodexManagerNext.automaticWarmUp.sevenDay"
    private static let legacyKey = "CodexManagerNext.automaticWarmUp"

    static func load(from defaults: UserDefaults = .standard) -> CodexWarmUpSelection {
        if defaults.object(forKey: fiveHourKey) != nil || defaults.object(forKey: sevenDayKey) != nil {
            return CodexWarmUpSelection(
                fiveHour: defaults.bool(forKey: fiveHourKey),
                sevenDay: defaults.bool(forKey: sevenDayKey)
            )
        }
        let legacy = defaults.bool(forKey: legacyKey)
        let selection = CodexWarmUpSelection(fiveHour: false, sevenDay: legacy)
        if legacy { selection.save(to: defaults) }
        return selection
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(fiveHour, forKey: Self.fiveHourKey)
        defaults.set(sevenDay, forKey: Self.sevenDayKey)
        defaults.removeObject(forKey: Self.legacyKey)
    }
}

enum CodexWarmUpWindowKind: String, Equatable {
    case fiveHour
    case sevenDay
}

enum CodexWarmUpPolicy {
    static let failureRetryInterval: TimeInterval = 30 * 60
    static let resetGrace: TimeInterval = 8
    static let windowStartRetryInterval: TimeInterval = 45
    static let idleUsedPercentThreshold = 0.5
    static let unexpectedResetDrop = 8.0
    static let minimumWeeklyRemaining = 5.0
    static let resetStartTolerance: TimeInterval = 10 * 60

    static func isWindowIdle(_ window: CodexQuotaWindowSnapshot?, now: Date = Date()) -> Bool {
        guard let window else { return true }
        if let resetsAt = window.resetsAt, resetsAt > now {
            return false
        }
        return window.usedPercent < idleUsedPercentThreshold
    }

    static func didResetUnexpectedly(
        previous: CodexQuotaWindowSnapshot?,
        current: CodexQuotaWindowSnapshot?,
        now: Date = Date()
    ) -> Bool {
        guard let previous, !isWindowIdle(previous, now: now) else { return false }
        if isWindowIdle(current, now: now) { return true }
        guard let current else { return true }
        if current.usedPercent + unexpectedResetDrop <= previous.usedPercent {
            return true
        }
        if let previousReset = previous.resetsAt,
           let currentReset = current.resetsAt,
           abs(currentReset.timeIntervalSince(previousReset)) > 120,
           current.usedPercent + 3 <= previous.usedPercent {
            return true
        }
        return false
    }

    /// 重置卡口径：区分「官方提前/人工重置」与「窗口自然滚动」。
    /// 同一窗口内额度回落超过阈值计一次（官方随机恢复额度）；
    /// 出现新窗口时，新窗口起点（resetsAt - 时长）明显偏离原窗口终点计一次。
    static func didConsumeReset(
        previous: CodexQuotaWindowSnapshot?,
        current: CodexQuotaWindowSnapshot?,
        now: Date = Date()
    ) -> Bool {
        guard let previous, previous.usedPercent >= 1, let current else { return false }
        guard let previousReset = previous.resetsAt, let currentReset = current.resetsAt else {
            return false
        }
        if abs(currentReset.timeIntervalSince(previousReset)) <= 120 {
            return current.usedPercent + unexpectedResetDrop <= previous.usedPercent
        }
        guard let duration = current.windowDurationMins.map({ TimeInterval($0) * 60 }), duration > 0 else {
            return false
        }
        let impliedStart = currentReset.addingTimeInterval(-duration)
        return abs(impliedStart.timeIntervalSince(previousReset)) > resetStartTolerance
    }

    static func shouldSkipFiveHourToProtectWeekly(_ profile: CodexProfile, now: Date = Date()) -> Bool {
        guard let weekly = profile.lastSnapshot?.sevenDay, !isWindowIdle(weekly, now: now) else {
            return false
        }
        return 100 - weekly.usedPercent <= minimumWeeklyRemaining
    }

    static func nextEligibleDate(
        for profile: CodexProfile,
        selection: CodexWarmUpSelection,
        unexpected: Set<CodexWarmUpWindowKind> = [],
        now: Date = Date()
    ) -> Date? {
        guard selection.isEnabled else { return nil }
        guard let email = profile.lastSnapshot?.email, !email.isEmpty else { return nil }
        if let activeUntil = profile.officialProfile?.subscriptionActiveUntil, activeUntil <= now {
            return nil
        }
        if profile.lastWarmUpSucceeded == false, let attemptedAt = profile.lastWarmUpAt {
            return attemptedAt.addingTimeInterval(failureRetryInterval)
        }

        var dates: [Date] = []
        if selection.fiveHour, !shouldSkipFiveHourToProtectWeekly(profile, now: now) {
            if let date = nextDate(
                for: profile.lastSnapshot?.fiveHour,
                lastWarmUpAt: profile.lastWarmUpAt,
                lastWarmUpSucceeded: profile.lastWarmUpSucceeded,
                unexpected: unexpected.contains(.fiveHour),
                now: now
            ) {
                dates.append(date)
            }
        }
        if selection.sevenDay {
            if let date = nextDate(
                for: profile.lastSnapshot?.sevenDay,
                lastWarmUpAt: profile.lastWarmUpAt,
                lastWarmUpSucceeded: profile.lastWarmUpSucceeded,
                unexpected: unexpected.contains(.sevenDay),
                now: now
            ) {
                dates.append(date)
            }
        }
        return dates.min()
    }

    static func isDue(
        _ profile: CodexProfile,
        selection: CodexWarmUpSelection,
        unexpected: Set<CodexWarmUpWindowKind> = [],
        now: Date = Date()
    ) -> Bool {
        nextEligibleDate(for: profile, selection: selection, unexpected: unexpected, now: now)
            .map { $0 <= now } ?? false
    }

    static func nextScheduledResetDate(
        for profile: CodexProfile,
        selection: CodexWarmUpSelection,
        now: Date = Date()
    ) -> Date? {
        guard selection.isEnabled,
              profile.lastSnapshot?.email?.isEmpty == false,
              profile.officialProfile?.subscriptionActiveUntil.map({ $0 > now }) ?? true
        else { return nil }

        var dates: [Date] = []
        if selection.fiveHour,
           !shouldSkipFiveHourToProtectWeekly(profile, now: now),
           let resetsAt = profile.lastSnapshot?.fiveHour?.resetsAt,
           resetsAt > now {
            dates.append(resetsAt.addingTimeInterval(resetGrace))
        }
        if selection.sevenDay,
           let resetsAt = profile.lastSnapshot?.sevenDay?.resetsAt,
           resetsAt > now {
            dates.append(resetsAt.addingTimeInterval(resetGrace))
        }
        return dates.min()
    }

    private static func nextDate(
        for window: CodexQuotaWindowSnapshot?,
        lastWarmUpAt: Date?,
        lastWarmUpSucceeded: Bool?,
        unexpected: Bool,
        now: Date
    ) -> Date? {
        if unexpected { return now }
        if isWindowIdle(window, now: now) {
            if lastWarmUpSucceeded == true, let lastWarmUpAt {
                let retryAt = lastWarmUpAt.addingTimeInterval(windowStartRetryInterval)
                if retryAt > now { return retryAt }
            }
            return now
        }
        if let resetsAt = window?.resetsAt, resetsAt > now {
            return resetsAt.addingTimeInterval(resetGrace)
        }
        return nil
    }
}

enum CodexOfficialProfileReader {
    private static let profileURL = URL(string: "https://chatgpt.com/backend-api/wham/profiles/me")!

    static func load(codexHomeURL: URL, now: Date = Date()) -> CodexOfficialProfileSnapshot? {
        let authURL = codexHomeURL.appendingPathComponent("auth.json")
        guard let authData = try? Data(contentsOf: authURL),
              let auth = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
              let tokens = auth["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty,
              let identity = credentialIdentity(fromAuthData: authData)
        else { return nil }

        let idToken = tokens["id_token"] as? String
        let subscription = subscription(fromIDToken: idToken)
        var request = URLRequest(url: profileURL, timeoutInterval: 12)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(identity.accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("Codex Desktop", forHTTPHeaderField: "originator")
        request.setValue("CODEX", forHTTPHeaderField: "OAI-Product-Sku")

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var statusCode: Int?
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        let session = URLSession(configuration: configuration)
        let task = session.dataTask(with: request) { data, response, _ in
            responseData = data
            statusCode = (response as? HTTPURLResponse)?.statusCode
            semaphore.signal()
        }
        task.resume()
        guard semaphore.wait(timeout: .now() + 13) == .success else {
            task.cancel()
            session.invalidateAndCancel()
            return nil
        }
        session.finishTasksAndInvalidate()

        guard let responseData,
              let statusCode,
              (200..<300).contains(statusCode),
              let response = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let profile = response["profile"] as? [String: Any],
              let stats = response["stats"] as? [String: Any]
        else { return nil }

        let metadata = response["metadata"] as? [String: Any]
        return CodexOfficialProfileSnapshot(
            accountEmail: email(fromIDToken: idToken),
            displayName: nonEmpty(profile["display_name"] as? String),
            username: nonEmpty(profile["username"] as? String),
            lifetimeTokens: (stats["lifetime_tokens"] as? NSNumber)?.int64Value,
            peakDailyTokens: (stats["peak_daily_tokens"] as? NSNumber)?.int64Value,
            planType: subscription?.planType,
            subscriptionActiveUntil: subscription?.activeUntil,
            statsAsOf: parseDate(metadata?["stats_as_of"] as? String),
            fetchedAt: now
        )
    }

    static func subscription(fromIDToken idToken: String?) -> (planType: String?, activeUntil: Date?)? {
        guard let claims = claims(fromToken: idToken),
              let auth = claims["https://api.openai.com/auth"] as? [String: Any]
        else { return nil }
        return (
            nonEmpty(auth["chatgpt_plan_type"] as? String),
            parseDate(auth["chatgpt_subscription_active_until"] as? String)
        )
    }

    static func email(fromIDToken idToken: String?) -> String? {
        nonEmpty(claims(fromToken: idToken)?["email"] as? String)
    }

    static func credentialIdentity(codexHomeURL: URL) -> CodexCredentialIdentity? {
        guard let data = try? Data(contentsOf: codexHomeURL.appendingPathComponent("auth.json")) else {
            return nil
        }
        return credentialIdentity(fromAuthData: data)
    }

    static func credentialIdentity(fromAuthData data: Data) -> CodexCredentialIdentity? {
        guard let auth = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = auth["tokens"] as? [String: Any],
              let accessToken = nonEmpty(tokens["access_token"] as? String),
              let idToken = nonEmpty(tokens["id_token"] as? String),
              let idClaims = claims(fromToken: idToken),
              let email = normalizedEmail(idClaims["email"] as? String)
        else { return nil }

        let accessClaims = claims(fromToken: accessToken)
        let storedAccountID = nonEmpty(tokens["account_id"] as? String)
        let idTokenAccountID = accountID(in: idClaims)
        let accessTokenAccountID = accessClaims.flatMap(accountID(in:))
        guard let accountID = storedAccountID ?? idTokenAccountID ?? accessTokenAccountID,
              [storedAccountID, idTokenAccountID, accessTokenAccountID]
                .compactMap({ $0 })
                .allSatisfy({ $0 == accountID })
        else { return nil }
        if let accessEmail = normalizedEmail(accessClaims?["email"] as? String), accessEmail != email {
            return nil
        }
        return CodexCredentialIdentity(email: email, accountID: accountID)
    }

    private static func claims(fromToken token: String?) -> [String: Any]? {
        guard let token else { return nil }
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func accountID(in claims: [String: Any]) -> String? {
        let namespaced = claims["https://api.openai.com/auth"] as? [String: Any]
        return nonEmpty(namespaced?["chatgpt_account_id"] as? String)
            ?? nonEmpty(namespaced?["account_id"] as? String)
            ?? nonEmpty(claims["chatgpt_account_id"] as? String)
            ?? nonEmpty(claims["account_id"] as? String)
    }

    private static func normalizedEmail(_ value: String?) -> String? {
        nonEmpty(value)?.lowercased()
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        if value.count == 10 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: value)
        }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }
}

struct CodexAccountResetCounter: Codable, Equatable {
    var automaticCount: Int = 0
    var manualOffset: Int = 0
    var lastCountedResetAt: Date? = nil
    var cardExpiresAt: Date? = nil

    var total: Int { automaticCount + manualOffset }
}

final class CodexProfileStore {
    private struct State: Codable {
        let schemaVersion: Int
        var profiles: [CodexProfile]
        var selectedMonitorProfileID: String
        var selectedLaunchProfileID: String
        var resetCounters: [String: CodexAccountResetCounter]? = nil
        var resetBackfillCheckedAt: Date? = nil
    }

    private let fileManager: FileManager
    private let stateURL: URL
    private let managedRootURL: URL
    private var state: State

    init(
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil,
        applicationSupportDirectory: URL? = nil
    ) {
        self.fileManager = fileManager
        let home = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        managedRootURL = home.appendingPathComponent(".codex-account-manager-next/profiles", isDirectory: true)
        let support = applicationSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? home.appendingPathComponent("Library/Application Support", isDirectory: true)
        stateURL = support
            .appendingPathComponent("CodexAccountManagerNext", isDirectory: true)
            .appendingPathComponent("account-manager-next-v1.json")

        let systemProfile = CodexProfile(
            id: "system",
            name: "当前 Codex",
            codexHomePath: home.appendingPathComponent(".codex", isDirectory: true).path,
            isSystemProfile: true,
            createdAt: Date(),
            lastSnapshot: nil
        )
        let fallback = State(
            schemaVersion: 1,
            profiles: [systemProfile],
            selectedMonitorProfileID: systemProfile.id,
            selectedLaunchProfileID: systemProfile.id
        )
        if let data = try? Data(contentsOf: stateURL),
           let decoded = try? JSONDecoder().decode(State.self, from: data),
           Self.isValid(decoded, systemPath: systemProfile.codexHomePath, managedRoot: managedRootURL) {
            state = decoded
        } else {
            state = fallback
        }
        var shouldSave = backfillCredentialAccountIDs()
        if state.resetBackfillCheckedAt == nil {
            backfillResetCountersFromHistory()
            state.resetBackfillCheckedAt = Date()
            shouldSave = true
        }
        if shouldSave { try? save() }
    }

    /// 一次性回填：用账号组内存量快照还原部署计数功能之前的历史重置。
    /// 已产生过计数（含自动检测）的账号组跳过，避免重复累计。
    func backfillResetCountersFromHistory() {
        var additions: [(key: String, count: Int, lastCountedAt: Date, newestWindowEnd: Date?)] = []
        for group in CodexProfile.groupsByRecordedAccount(state.profiles) {
            let windows = group
                .compactMap { profile -> (fetchedAt: Date, window: CodexQuotaWindowSnapshot)? in
                    guard let snapshot = profile.lastSnapshot else { return nil }
                    guard let window = snapshot.sevenDay else { return nil }
                    return (snapshot.fetchedAt, window)
                }
                .sorted { $0.fetchedAt < $1.fetchedAt }
            guard windows.count >= 2,
                  let key = group.first?.recordedAccountKey,
                  state.resetCounters?[key]?.lastCountedResetAt == nil
            else { continue }
            var count = 0
            for (previous, current) in zip(windows, windows.dropFirst()) {
                if CodexWarmUpPolicy.didConsumeReset(
                    previous: previous.window,
                    current: current.window,
                    now: current.fetchedAt
                ) {
                    count += 1
                }
            }
            additions.append((
                key,
                count,
                windows.map(\.fetchedAt).max() ?? Date(),
                windows.compactMap { $0.window.resetsAt }.max()
            ))
        }
        guard !additions.isEmpty else { return }
        var counters = state.resetCounters ?? [:]
        for addition in additions where addition.count > 0 {
            var counter = counters[addition.key] ?? CodexAccountResetCounter()
            counter.automaticCount += addition.count
            counter.lastCountedResetAt = addition.lastCountedAt
            if let newestWindowEnd = addition.newestWindowEnd {
                counter.cardExpiresAt = newestWindowEnd
            }
            counters[addition.key] = counter
        }
        state.resetCounters = counters
    }

    var profiles: [CodexProfile] { state.profiles }
    var selectedMonitorProfileID: String { state.selectedMonitorProfileID }
    var selectedLaunchProfileID: String { state.selectedLaunchProfileID }

    var selectedMonitorProfile: CodexProfile {
        state.profiles.first { $0.id == state.selectedMonitorProfileID } ?? state.profiles[0]
    }

    func addManagedProfile(copyingRemarkFrom sourceProfileID: String? = nil) throws -> CodexProfile {
        let id = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).lowercased()
        let home = managedRootURL.appendingPathComponent(id, isDirectory: true)
        try fileManager.createDirectory(
            at: home,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: home.path)
        let profile = CodexProfile(
            id: id,
            name: "账号 \(state.profiles.count + 1)",
            remark: sourceProfileID.flatMap { sourceID in
                state.profiles.first(where: { $0.id == sourceID })?.remark
            },
            codexHomePath: home.path,
            isSystemProfile: false,
            createdAt: Date(),
            lastSnapshot: nil
        )
        if let sourceProfileID,
           let sourceIndex = state.profiles.firstIndex(where: { $0.id == sourceProfileID }) {
            state.profiles.insert(profile, at: sourceIndex)
        } else {
            state.profiles.append(profile)
        }
        try save()
        return profile
    }

    @discardableResult
    func preserveSystemLogin(
        expectedEmail: String? = nil,
        expectedAccountID: String? = nil,
        expectedAuthFingerprint: Data? = nil
    ) throws -> CodexProfile {
        guard let systemIndex = state.profiles.firstIndex(where: \.isSystemProfile) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let system = state.profiles[systemIndex]
        guard system.lastSnapshot?.email?.isEmpty == false else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let sourceAuth = system.codexHomeURL.appendingPathComponent("auth.json")
        let authData: Data
        do {
            authData = try Data(contentsOf: sourceAuth)
        } catch {
            throw NSError(
                domain: "CodexAccountManagerNext.ProfileStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法安全读取当前 Codex 凭据"]
            )
        }
        let boundEmail = (expectedEmail ?? system.lastSnapshot?.email)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let identity = CodexOfficialProfileReader.credentialIdentity(fromAuthData: authData)
        let boundAccountID = expectedAccountID ?? system.lastSnapshot?.accountID ?? identity?.accountID
        guard let boundEmail,
              !boundEmail.isEmpty,
              let boundAccountID,
              identity?.email == boundEmail,
              identity?.accountID == boundAccountID
        else {
            throw NSError(
                domain: "CodexAccountManagerNext.ProfileStore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "当前 Codex 凭据身份与系统账号记录不一致"]
            )
        }
        if let expectedAuthFingerprint {
            guard Data(SHA256.hash(data: authData)) == expectedAuthFingerprint else {
                throw NSError(
                    domain: "CodexAccountManagerNext.ProfileStore",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "保存前当前 Codex 凭据已变化"]
                )
            }
        }
        let boundSnapshot = system.lastSnapshot.map { Self.snapshot($0, accountID: boundAccountID) }
        if let existing = state.profiles.first(where: {
            !$0.isSystemProfile
                && $0.recordedAccountKey == system.recordedAccountKey
                && $0.lastSnapshot?.accountID == boundAccountID
        }) {
            try writeAuth(authData, to: existing.codexHomeURL)
            return existing
        }

        let previousState = state
        let id = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)).lowercased()
        let home = managedRootURL.appendingPathComponent(id, isDirectory: true)
        let preserved = CodexProfile(
            id: id,
            name: system.name,
            remark: system.remark,
            codexHomePath: home.path,
            isSystemProfile: false,
            createdAt: Date(),
            lastSnapshot: boundSnapshot,
            officialProfile: system.officialProfile,
            lastWarmUpAt: system.lastWarmUpAt,
            lastWarmUpSucceeded: system.lastWarmUpSucceeded
        )
        do {
            try writeAuth(authData, to: home)
            state.profiles.insert(preserved, at: systemIndex + 1)
            try save()
            return preserved
        } catch {
            state = previousState
            try? fileManager.removeItem(at: home)
            throw error
        }
    }

    func selectMonitor(_ id: String) throws {
        guard state.profiles.contains(where: { $0.id == id }) else { return }
        state.selectedMonitorProfileID = id
        try save()
    }

    @discardableResult
    func selectMonitorForSystemAccount() throws -> String {
        guard let system = state.profiles.first(where: \.isSystemProfile) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let target = state.profiles.first {
            !$0.isSystemProfile
                && $0.matchesRecordedAccount(email: system.lastSnapshot?.email)
                && $0.lastSnapshot?.accountID == system.lastSnapshot?.accountID
        } ?? system
        state.selectedMonitorProfileID = target.id
        try save()
        return target.id
    }

    func selectLaunch(_ id: String) throws {
        guard state.profiles.contains(where: { $0.id == id }) else { return }
        state.selectedLaunchProfileID = id
        try save()
    }

    func setRemark(_ remark: String, for id: String) throws {
        guard let index = state.profiles.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        state.profiles[index].remark = trimmed.isEmpty ? nil : String(trimmed.prefix(40))
        try save()
    }

    func moveProfile(_ id: String, relativeTo targetID: String, before: Bool) throws {
        guard id != targetID,
              let sourceIndex = state.profiles.firstIndex(where: { $0.id == id }),
              state.profiles.contains(where: { $0.id == targetID })
        else { return }
        let previousState = state
        let profile = state.profiles.remove(at: sourceIndex)
        guard let targetIndex = state.profiles.firstIndex(where: { $0.id == targetID }) else {
            state = previousState
            return
        }
        state.profiles.insert(profile, at: before ? targetIndex : targetIndex + 1)
        do {
            try save()
        } catch {
            state = previousState
            throw error
        }
    }

    func record(
        _ snapshot: UsageSnapshot,
        for profileID: String,
        allowAccountOnly: Bool = false,
        allowSystemAccountChange: Bool = false
    ) throws {
        let hasVerifiedAccount = snapshot.account?.email?.isEmpty == false
        guard (snapshot.quotaReadSucceeded || (allowAccountOnly && hasVerifiedAccount)),
              let index = state.profiles.firstIndex(where: { $0.id == profileID })
        else { return }
        let credentialIdentity = CodexOfficialProfileReader.credentialIdentity(
            codexHomeURL: state.profiles[index].codexHomeURL
        )
        let snapshotEmail = snapshot.account?.email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let identityMatchesSnapshot = credentialIdentity?.email == snapshotEmail
        let verifiedAccountID = identityMatchesSnapshot ? credentialIdentity?.accountID : nil
        let previousAccountID = state.profiles[index].lastSnapshot?.accountID
        let accountChanged = !state.profiles[index].matchesRecordedAccount(email: snapshot.account?.email)
            || (previousAccountID != nil && verifiedAccountID != nil && previousAccountID != verifiedAccountID)
        guard !accountChanged || (allowSystemAccountChange && state.profiles[index].isSystemProfile) else { return }
        if accountChanged {
            state.profiles[index].officialProfile = nil
            state.profiles[index].lastWarmUpAt = nil
            state.profiles[index].lastWarmUpSucceeded = nil
            if state.profiles[index].isSystemProfile {
                state.profiles[index].remark = nil
            }
        }
        let record = CodexAccountSnapshot(
            accountType: snapshot.account?.type,
            planType: snapshot.account?.planType,
            email: snapshot.account?.email,
            accountID: verifiedAccountID ?? (accountChanged ? nil : previousAccountID),
            limitId: snapshot.limitId,
            limitName: snapshot.limitName,
            fiveHour: snapshot.fiveHourQuota.map(CodexQuotaWindowSnapshot.init),
            sevenDay: snapshot.sevenDayQuota.map(CodexQuotaWindowSnapshot.init),
            monthly: snapshot.monthlyQuota.map(CodexQuotaWindowSnapshot.init),
            fetchedAt: snapshot.refreshedAt,
            appServerVersion: CodexExecutable.version()
        )
        let previousSevenDay = state.profiles[index].lastSnapshot?.sevenDay
        state.profiles[index].lastSnapshot = record
        if !accountChanged,
           CodexWarmUpPolicy.didConsumeReset(
            previous: previousSevenDay,
            current: record.sevenDay,
            now: snapshot.refreshedAt
           ),
           !resetAlreadyObservedInGroup(
            previous: previousSevenDay,
            current: record.sevenDay,
            excludingIndex: index
           ) {
            let key = state.profiles[index].recordedAccountKey
            var counters = state.resetCounters ?? [:]
            var counter = counters[key] ?? CodexAccountResetCounter()
            counter.automaticCount += 1
            counter.lastCountedResetAt = record.sevenDay?.resetsAt ?? record.fetchedAt
            if let newWindowEnd = record.sevenDay?.resetsAt {
                counter.cardExpiresAt = newWindowEnd
            }
            counters[key] = counter
            state.resetCounters = counters
        }
        if let email = record.email, !email.isEmpty {
            state.profiles[index].name = email
        }
        try save()
    }

    func recordOfficialProfile(_ snapshot: CodexOfficialProfileSnapshot, for profileID: String) throws {
        guard let index = state.profiles.firstIndex(where: { $0.id == profileID }) else { return }
        guard state.profiles[index].matchesRecordedAccount(email: snapshot.accountEmail) else { return }
        state.profiles[index].officialProfile = snapshot
        try save()
    }

    func recordWarmUp(at date: Date, succeeded: Bool, for profileID: String) throws {
        guard let index = state.profiles.firstIndex(where: { $0.id == profileID }) else { return }
        state.profiles[index].lastWarmUpAt = date
        state.profiles[index].lastWarmUpSucceeded = succeeded
        try save()
    }

    func resetCounter(accountKey: String) -> CodexAccountResetCounter {
        state.resetCounters?[accountKey] ?? CodexAccountResetCounter()
    }

    /// 系统登录与某管理卡是同一账号时，把系统家更新的登录凭据同步给该卡。
    /// 管理卡家目录没有进程续期 token，不同步会在 token 过期后额度抓取失效。
    func syncSystemAuthToMatchingManagedProfiles() throws {
        guard let system = state.profiles.first(where: \.isSystemProfile) else { return }
        let systemAuthURL = system.codexHomeURL.appendingPathComponent("auth.json")
        guard fileManager.fileExists(atPath: systemAuthURL.path),
              let systemAttributes = try? fileManager.attributesOfItem(atPath: systemAuthURL.path),
              let systemModified = systemAttributes[.modificationDate] as? Date
        else { return }
        let authData = try Data(contentsOf: systemAuthURL)
        guard let identity = CodexOfficialProfileReader.credentialIdentity(fromAuthData: authData),
              identity.email == system.recordedAccountKey,
              system.lastSnapshot?.accountID == identity.accountID
        else { return }
        let matching = state.profiles.filter {
            !$0.isSystemProfile
                && $0.recordedAccountKey == system.recordedAccountKey
                && $0.lastSnapshot?.accountID == identity.accountID
        }
        guard !matching.isEmpty else { return }
        for profile in matching {
            let managedAuthURL = profile.codexHomeURL.appendingPathComponent("auth.json")
            if let managedAttributes = try? fileManager.attributesOfItem(atPath: managedAuthURL.path),
               let managedModified = managedAttributes[.modificationDate] as? Date,
               managedModified >= systemModified {
                continue
            }
            try writeAuth(authData, to: profile.codexHomeURL)
        }
    }

    /// 同一账号组内其他卡是否已记录过这轮窗口状态；避免同一次重置被多张卡重复计数。
    private func resetAlreadyObservedInGroup(
        previous: CodexQuotaWindowSnapshot?,
        current: CodexQuotaWindowSnapshot?,
        excludingIndex index: Int
    ) -> Bool {
        guard let current,
              let currentReset = current.resetsAt,
              let previousReset = previous?.resetsAt
        else { return false }
        let key = state.profiles[index].recordedAccountKey
        let isNewWindow = abs(currentReset.timeIntervalSince(previousReset)) > 120
        for (otherIndex, other) in state.profiles.enumerated() where otherIndex != index {
            guard other.recordedAccountKey == key,
                  let otherReset = other.lastSnapshot?.sevenDay?.resetsAt,
                  abs(otherReset.timeIntervalSince(currentReset)) <= 120
            else { continue }
            if isNewWindow { return true }
            if let otherUsed = other.lastSnapshot?.sevenDay?.usedPercent,
               abs(otherUsed - current.usedPercent) <= 0.5 {
                return true
            }
        }
        return false
    }

    func adjustResetManualOffset(accountKey: String, delta: Int, fallbackExpiry: Date? = nil) throws {
        var counters = state.resetCounters ?? [:]
        var counter = counters[accountKey] ?? CodexAccountResetCounter()
        counter.manualOffset = max(-counter.automaticCount, counter.manualOffset + delta)
        if delta > 0, let fallbackExpiry {
            if let current = counter.cardExpiresAt {
                if fallbackExpiry > current {
                    counter.cardExpiresAt = fallbackExpiry
                }
            } else {
                counter.cardExpiresAt = fallbackExpiry
            }
        }
        counters[accountKey] = counter
        state.resetCounters = counters
        try save()
    }

    func setResetCardExpiry(accountKey: String, date: Date?) throws {
        var counters = state.resetCounters ?? [:]
        var counter = counters[accountKey] ?? CodexAccountResetCounter()
        counter.cardExpiresAt = date
        counters[accountKey] = counter
        state.resetCounters = counters
        try save()
    }

    func discardUnverifiedManagedProfiles() throws {
        let discarded = state.profiles.filter { !$0.isSystemProfile && $0.lastSnapshot == nil }
        guard !discarded.isEmpty else { return }
        let discardedIDs = Set(discarded.map(\.id))
        state.profiles.removeAll { discardedIDs.contains($0.id) }
        let fallbackID = state.profiles.first(where: \.isSystemProfile)?.id ?? state.profiles[0].id
        if discardedIDs.contains(state.selectedMonitorProfileID) {
            state.selectedMonitorProfileID = fallbackID
        }
        if discardedIDs.contains(state.selectedLaunchProfileID) {
            state.selectedLaunchProfileID = fallbackID
        }
        try save()
        for profile in discarded {
            let authURL = profile.codexHomeURL.appendingPathComponent("auth.json")
            if !fileManager.fileExists(atPath: authURL.path) {
                try? fileManager.removeItem(at: profile.codexHomeURL)
            }
        }
    }

    func discardManagedProfile(_ id: String) throws {
        guard let profile = try removeManagedProfileRecord(id) else { return }
        let authURL = profile.codexHomeURL.appendingPathComponent("auth.json")
        if !fileManager.fileExists(atPath: authURL.path) {
            try? fileManager.removeItem(at: profile.codexHomeURL)
        }
    }

    func removeManagedProfile(_ id: String) throws {
        guard let profile = state.profiles.first(where: { $0.id == id && !$0.isSystemProfile }) else { return }
        var trashedURL: NSURL?
        if fileManager.fileExists(atPath: profile.codexHomePath) {
            try fileManager.trashItem(at: profile.codexHomeURL, resultingItemURL: &trashedURL)
        }
        do {
            _ = try removeManagedProfileRecord(id)
        } catch {
            if let trashedURL {
                try? fileManager.moveItem(at: trashedURL as URL, to: profile.codexHomeURL)
            }
            throw error
        }
    }

    private func removeManagedProfileRecord(_ id: String) throws -> CodexProfile? {
        guard let index = state.profiles.firstIndex(where: { $0.id == id && !$0.isSystemProfile }) else { return nil }
        let previousState = state
        let profile = state.profiles.remove(at: index)
        let fallbackID = state.profiles.first(where: \.isSystemProfile)?.id ?? state.profiles[0].id
        if state.selectedMonitorProfileID == id { state.selectedMonitorProfileID = fallbackID }
        if state.selectedLaunchProfileID == id { state.selectedLaunchProfileID = fallbackID }
        do {
            try save()
        } catch {
            state = previousState
            throw error
        }
        return profile
    }

    private func save() throws {
        let directory = stateURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: stateURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stateURL.path)
    }

    @discardableResult
    private func backfillCredentialAccountIDs() -> Bool {
        var changed = false
        for index in state.profiles.indices {
            guard let current = state.profiles[index].lastSnapshot,
                  let identity = CodexOfficialProfileReader.credentialIdentity(
                    codexHomeURL: state.profiles[index].codexHomeURL
                  ),
                  state.profiles[index].matchesRecordedAccount(email: identity.email),
                  current.accountID != identity.accountID
            else { continue }
            state.profiles[index].lastSnapshot = Self.snapshot(current, accountID: identity.accountID)
            changed = true
        }
        return changed
    }

    private static func snapshot(_ snapshot: CodexAccountSnapshot, accountID: String?) -> CodexAccountSnapshot {
        CodexAccountSnapshot(
            accountType: snapshot.accountType,
            planType: snapshot.planType,
            email: snapshot.email,
            accountID: accountID,
            limitId: snapshot.limitId,
            limitName: snapshot.limitName,
            fiveHour: snapshot.fiveHour,
            sevenDay: snapshot.sevenDay,
            monthly: snapshot.monthly,
            fetchedAt: snapshot.fetchedAt,
            appServerVersion: snapshot.appServerVersion
        )
    }

    private func writeAuth(_ data: Data, to home: URL) throws {
        try fileManager.createDirectory(
            at: home,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let authURL = home.appendingPathComponent("auth.json")
        try data.write(to: authURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: authURL.path)
    }

    private static func isValid(_ state: State, systemPath: String, managedRoot: URL) -> Bool {
        guard state.schemaVersion == 1,
              !state.profiles.isEmpty,
              Set(state.profiles.map(\.id)).count == state.profiles.count,
              state.profiles.contains(where: { $0.id == state.selectedMonitorProfileID }),
              state.profiles.contains(where: { $0.id == state.selectedLaunchProfileID })
        else { return false }

        let root = managedRoot.standardizedFileURL.path + "/"
        return state.profiles.allSatisfy { profile in
            let path = profile.codexHomeURL.standardizedFileURL.path
            return profile.isSystemProfile ? path == systemPath : path.hasPrefix(root)
        }
    }
}

enum CodexProfileStoreSelfTest {
    static func run() -> Bool {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("codex-profile-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        do {
            let home = root.appendingPathComponent("home", isDirectory: true)
            let support = root.appendingPathComponent("support", isDirectory: true)
            try fileManager.createDirectory(at: home, withIntermediateDirectories: true)
            let first = CodexProfileStore(
                fileManager: fileManager,
                homeDirectory: home,
                applicationSupportDirectory: support
            )
            _ = try first.addManagedProfile()
            try first.discardUnverifiedManagedProfiles()
            guard first.profiles.count == 1 else {
                print("Codex profile store self-test failed: unverified cleanup")
                return false
            }
            try first.setRemark("🍃", for: "system")
            let detached = try first.addManagedProfile(copyingRemarkFrom: "system")
            guard first.profiles.first?.id == detached.id, detached.remark == "🍃" else {
                print("Codex profile store self-test failed: independent login placeholder")
                return false
            }
            try first.discardManagedProfile(detached.id)
            try first.setRemark("", for: "system")
            let added = try first.addManagedProfile()
            try first.selectMonitor(added.id)
            try first.selectLaunch(added.id)
            let firstSnapshot = testSnapshot(email: "first@example.com", usedPercent: 11, at: Date(timeIntervalSince1970: 100))
            let secondSnapshot = testSnapshot(email: "second@example.com", usedPercent: 22, at: Date(timeIntervalSince1970: 200))
            let managedSnapshot = testSnapshot(email: "managed@example.com", usedPercent: 33, at: Date(timeIntervalSince1970: 300))
            try first.record(managedSnapshot, for: added.id)
            let official = CodexOfficialProfileSnapshot(
                accountEmail: "managed@example.com",
                displayName: "Managed",
                username: "managed",
                lifetimeTokens: 667_817_039,
                peakDailyTokens: 147_276_193,
                planType: "plus",
                subscriptionActiveUntil: Date(timeIntervalSince1970: 400),
                statsAsOf: Date(timeIntervalSince1970: 300),
                fetchedAt: Date(timeIntervalSince1970: 350)
            )
            try first.recordOfficialProfile(official, for: added.id)
            try first.recordWarmUp(at: Date(timeIntervalSince1970: 360), succeeded: true, for: added.id)
            try first.setRemark(" 工作账号 ", for: added.id)
            try first.record(managedSnapshot, for: added.id)
            try first.record(firstSnapshot, for: "system")
            try first.record(secondSnapshot, for: "system")
            guard first.profiles.first(where: { $0.id == "system" })?.lastSnapshot?.email == "first@example.com" else {
                print("Codex profile store self-test failed: account identity overwrite")
                return false
            }
            let systemOfficial = CodexOfficialProfileSnapshot(
                accountEmail: "first@example.com",
                displayName: "System",
                username: "system",
                lifetimeTokens: 100,
                peakDailyTokens: 50,
                planType: "plus",
                subscriptionActiveUntil: Date(timeIntervalSince1970: 400),
                statsAsOf: Date(timeIntervalSince1970: 300),
                fetchedAt: Date(timeIntervalSince1970: 350)
            )
            try first.recordOfficialProfile(systemOfficial, for: "system")
            try first.recordWarmUp(at: Date(timeIntervalSince1970: 360), succeeded: true, for: "system")
            try first.setRemark("旧账号", for: "system")
            try first.record(secondSnapshot, for: "system", allowSystemAccountChange: true)
            guard let reboundSystem = first.profiles.first(where: { $0.id == "system" }),
                  reboundSystem.lastSnapshot?.email == "second@example.com",
                  reboundSystem.remark == nil,
                  reboundSystem.officialProfile == nil,
                  reboundSystem.lastWarmUpAt == nil,
                  reboundSystem.lastWarmUpSucceeded == nil
            else {
                print("Codex profile store self-test failed: explicit system account rebind")
                return false
            }
            try first.record(managedSnapshot, for: "system", allowSystemAccountChange: true)
            guard try first.selectMonitorForSystemAccount() == added.id else {
                print("Codex profile store self-test failed: current account monitor match")
                return false
            }
            try first.record(firstSnapshot, for: "system", allowSystemAccountChange: true)
            guard try first.selectMonitorForSystemAccount() == "system" else {
                print("Codex profile store self-test failed: current account monitor fallback")
                return false
            }
            try first.selectMonitor(added.id)
            let permissions = (try fileManager.attributesOfItem(atPath: added.codexHomePath)[.posixPermissions] as? NSNumber)?.intValue
            guard permissions == 0o700 else {
                print("Codex profile store self-test failed: directory permissions")
                return false
            }
            let restored = CodexProfileStore(
                fileManager: fileManager,
                homeDirectory: home,
                applicationSupportDirectory: support
            )
            guard restored.profiles.count == 2,
                  restored.selectedMonitorProfileID == added.id,
                  restored.selectedLaunchProfileID == added.id,
                  restored.profiles.first(where: { $0.id == added.id })?.remark == "工作账号",
                  restored.profiles.first(where: { $0.id == added.id })?.officialProfile == official,
                  restored.profiles.first(where: { $0.id == added.id })?.lastWarmUpSucceeded == true,
                  restored.profiles[0].matchesRecordedAccount(email: "FIRST@example.com"),
                  !restored.profiles[0].matchesRecordedAccount(email: "other@example.com"),
                  CodexProfile.groupsByRecordedAccount([
                      restored.profiles[0], restored.profiles[1], restored.profiles[0]
                  ]).count == 2
            else {
                print("Codex profile store self-test failed: persistence")
                return false
            }
            try restored.moveProfile(added.id, relativeTo: "system", before: true)
            let reordered = CodexProfileStore(
                fileManager: fileManager,
                homeDirectory: home,
                applicationSupportDirectory: support
            )
            guard reordered.profiles.map(\.id) == [added.id, "system"] else {
                print("Codex profile store self-test failed: profile ordering")
                return false
            }
            let systemHome = home.appendingPathComponent(".codex", isDirectory: true)
            try fileManager.createDirectory(at: systemHome, withIntermediateDirectories: true)
            let systemAuthPayload = Data(#"{"email":"first@example.com","https://api.openai.com/auth":{"chatgpt_account_id":"acct-first"}}"#.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            let systemAuth = Data(#"{"tokens":{"access_token":"test-only","account_id":"acct-first","id_token":"e30.\#(systemAuthPayload).sig"}}"#.utf8)
            try systemAuth.write(to: systemHome.appendingPathComponent("auth.json"))
            let preserved = try reordered.preserveSystemLogin()
            let preservedAuth = try Data(contentsOf: preserved.codexHomeURL.appendingPathComponent("auth.json"))
            let preservedAgain = try reordered.preserveSystemLogin()
            guard preserved.lastSnapshot?.email == "first@example.com",
                  preserved.lastSnapshot?.accountID == "acct-first",
                  preservedAuth == systemAuth,
                  preservedAgain.id == preserved.id,
                  reordered.profiles.count == 3
            else {
                print("Codex profile store self-test failed: preserve system login")
                return false
            }
            var policyProfile = restored.profiles.first { $0.id == added.id }!
            policyProfile.officialProfile = nil
            policyProfile.lastSnapshot = CodexAccountSnapshot(
                accountType: "chatgpt",
                planType: "plus",
                email: "managed@example.com",
                limitId: "codex",
                limitName: nil,
                fiveHour: CodexQuotaWindowSnapshot(RateWindow(
                    usedPercent: 1,
                    windowDurationMins: 300,
                    resetsAt: Date(timeIntervalSince1970: 18_000)
                )),
                sevenDay: CodexQuotaWindowSnapshot(RateWindow(
                    usedPercent: 20,
                    windowDurationMins: 10_080,
                    resetsAt: nil
                )),
                monthly: nil,
                fetchedAt: Date(timeIntervalSince1970: 100),
                appServerVersion: nil
            )
            let now = Date(timeIntervalSince1970: 1_000)
            let fiveHourReset = Date(timeIntervalSince1970: 18_000)
            let sevenDayReset = Date(timeIntervalSince1970: 80_000)
            policyProfile.lastWarmUpAt = nil
            policyProfile.lastWarmUpSucceeded = nil
            let sevenDayOnly = CodexWarmUpSelection(fiveHour: false, sevenDay: true)
            let fiveHourOnly = CodexWarmUpSelection(fiveHour: true, sevenDay: false)
            let bothWindows = CodexWarmUpSelection(fiveHour: true, sevenDay: true)
            policyProfile.lastSnapshot = CodexAccountSnapshot(
                accountType: "chatgpt",
                planType: "plus",
                email: "managed@example.com",
                limitId: "codex",
                limitName: nil,
                fiveHour: CodexQuotaWindowSnapshot(RateWindow(
                    usedPercent: 12,
                    windowDurationMins: 300,
                    resetsAt: fiveHourReset
                )),
                sevenDay: CodexQuotaWindowSnapshot(RateWindow(
                    usedPercent: 20,
                    windowDurationMins: 10_080,
                    resetsAt: sevenDayReset
                )),
                monthly: nil,
                fetchedAt: Date(timeIntervalSince1970: 100),
                appServerVersion: nil
            )
            guard CodexWarmUpPolicy.nextEligibleDate(for: policyProfile, selection: sevenDayOnly, now: now)
                    == sevenDayReset.addingTimeInterval(CodexWarmUpPolicy.resetGrace) else {
                print("Codex profile store self-test failed: 7-day switch waits for weekly reset")
                return false
            }
            guard CodexWarmUpPolicy.nextEligibleDate(for: policyProfile, selection: fiveHourOnly, now: now)
                    == fiveHourReset.addingTimeInterval(CodexWarmUpPolicy.resetGrace) else {
                print("Codex profile store self-test failed: 5-hour switch waits for 5-hour reset")
                return false
            }
            guard CodexWarmUpPolicy.nextEligibleDate(for: policyProfile, selection: bothWindows, now: now)
                    == fiveHourReset.addingTimeInterval(CodexWarmUpPolicy.resetGrace) else {
                print("Codex profile store self-test failed: both switches use the earliest reset")
                return false
            }
            guard CodexWarmUpPolicy.nextScheduledResetDate(
                for: policyProfile,
                selection: bothWindows,
                now: now
            ) == fiveHourReset.addingTimeInterval(CodexWarmUpPolicy.resetGrace) else {
                print("Codex profile store self-test failed: one-shot schedule uses the earliest known reset")
                return false
            }
            guard !CodexWarmUpPolicy.isDue(policyProfile, selection: sevenDayOnly, now: now) else {
                print("Codex profile store self-test failed: active 7-day window is not due")
                return false
            }
            var idleWeek = policyProfile
            idleWeek.lastSnapshot = CodexAccountSnapshot(
                accountType: "chatgpt",
                planType: "plus",
                email: "managed@example.com",
                limitId: "codex",
                limitName: nil,
                fiveHour: CodexQuotaWindowSnapshot(RateWindow(
                    usedPercent: 0,
                    windowDurationMins: 300,
                    resetsAt: Date(timeIntervalSince1970: 500)
                )),
                sevenDay: CodexQuotaWindowSnapshot(RateWindow(
                    usedPercent: 0,
                    windowDurationMins: 10_080,
                    resetsAt: Date(timeIntervalSince1970: 500)
                )),
                monthly: nil,
                fetchedAt: Date(timeIntervalSince1970: 100),
                appServerVersion: nil
            )
            guard CodexWarmUpPolicy.isDue(idleWeek, selection: sevenDayOnly, now: now) else {
                print("Codex profile store self-test failed: idle 7-day window should warm immediately")
                return false
            }
            guard CodexWarmUpPolicy.isDue(idleWeek, selection: fiveHourOnly, now: now) else {
                print("Codex profile store self-test failed: idle 5-hour window should warm immediately")
                return false
            }
            guard CodexWarmUpPolicy.nextScheduledResetDate(
                for: idleWeek,
                selection: bothWindows,
                now: now
            ) == nil else {
                print("Codex profile store self-test failed: past reset must not create an automatic retry timer")
                return false
            }
            var unknownWeek = policyProfile
            unknownWeek.lastSnapshot = CodexAccountSnapshot(
                accountType: "chatgpt",
                planType: "plus",
                email: "managed@example.com",
                limitId: "codex",
                limitName: nil,
                fiveHour: CodexQuotaWindowSnapshot(RateWindow(
                    usedPercent: 12,
                    windowDurationMins: 300,
                    resetsAt: fiveHourReset
                )),
                sevenDay: CodexQuotaWindowSnapshot(RateWindow(
                    usedPercent: 20,
                    windowDurationMins: 10_080,
                    resetsAt: nil
                )),
                monthly: nil,
                fetchedAt: Date(timeIntervalSince1970: 100),
                appServerVersion: nil
            )
            guard CodexWarmUpPolicy.nextEligibleDate(for: unknownWeek, selection: sevenDayOnly, now: now) == nil else {
                print("Codex profile store self-test failed: unknown weekly reset should wait for a drop")
                return false
            }
            let previousWeek = unknownWeek.lastSnapshot?.sevenDay
            let droppedWeek = CodexQuotaWindowSnapshot(RateWindow(
                usedPercent: 0,
                windowDurationMins: 10_080,
                resetsAt: nil
            ))
            guard CodexWarmUpPolicy.didResetUnexpectedly(previous: previousWeek, current: droppedWeek, now: now) else {
                print("Codex profile store self-test failed: weekly used-percent drop is an unexpected reset")
                return false
            }
            var afterDrop = unknownWeek
            afterDrop.lastSnapshot = CodexAccountSnapshot(
                accountType: "chatgpt",
                planType: "plus",
                email: "managed@example.com",
                limitId: "codex",
                limitName: nil,
                fiveHour: unknownWeek.lastSnapshot?.fiveHour,
                sevenDay: droppedWeek,
                monthly: nil,
                fetchedAt: Date(timeIntervalSince1970: 100),
                appServerVersion: nil
            )
            guard CodexWarmUpPolicy.isDue(afterDrop, selection: sevenDayOnly, now: now) else {
                print("Codex profile store self-test failed: idle 7-day window after a drop should warm immediately")
                return false
            }
            guard !CodexWarmUpPolicy.isDue(afterDrop, selection: fiveHourOnly, now: now) else {
                print("Codex profile store self-test failed: 5-hour switch must ignore a 7-day-only drop")
                return false
            }
            var lowWeekly = policyProfile
            lowWeekly.lastSnapshot = CodexAccountSnapshot(
                accountType: "chatgpt",
                planType: "plus",
                email: "managed@example.com",
                limitId: "codex",
                limitName: nil,
                fiveHour: CodexQuotaWindowSnapshot(RateWindow(
                    usedPercent: 0,
                    windowDurationMins: 300,
                    resetsAt: Date(timeIntervalSince1970: 500)
                )),
                sevenDay: CodexQuotaWindowSnapshot(RateWindow(
                    usedPercent: 97,
                    windowDurationMins: 10_080,
                    resetsAt: sevenDayReset
                )),
                monthly: nil,
                fetchedAt: Date(timeIntervalSince1970: 100),
                appServerVersion: nil
            )
            guard CodexWarmUpPolicy.shouldSkipFiveHourToProtectWeekly(lowWeekly, now: now) else {
                print("Codex profile store self-test failed: 5-hour warm-up should yield to low weekly remaining")
                return false
            }
            guard CodexWarmUpPolicy.nextEligibleDate(for: lowWeekly, selection: fiveHourOnly, now: now) == nil else {
                print("Codex profile store self-test failed: 5-hour switch pauses when weekly remaining is low")
                return false
            }
            guard CodexWarmUpPolicy.nextEligibleDate(for: lowWeekly, selection: sevenDayOnly, now: now)
                    == sevenDayReset.addingTimeInterval(CodexWarmUpPolicy.resetGrace) else {
                print("Codex profile store self-test failed: 7-day switch still waits when remaining is low")
                return false
            }
            policyProfile.lastWarmUpAt = Date(timeIntervalSince1970: 1_000)
            policyProfile.lastWarmUpSucceeded = false
            guard !CodexWarmUpPolicy.isDue(policyProfile, selection: sevenDayOnly, now: Date(timeIntervalSince1970: 1_100)) else {
                print("Codex profile store self-test failed: warm-up retry cooldown")
                return false
            }
            idleWeek.lastWarmUpAt = Date(timeIntervalSince1970: 980)
            idleWeek.lastWarmUpSucceeded = true
            guard CodexWarmUpPolicy.nextEligibleDate(for: idleWeek, selection: sevenDayOnly, now: now)
                    == Date(timeIntervalSince1970: 1_025) else {
                print("Codex profile store self-test failed: window-start retry interval")
                return false
            }
            let payload = try JSONSerialization.data(withJSONObject: [
                "https://api.openai.com/auth": [
                    "chatgpt_plan_type": "plus",
                    "chatgpt_subscription_active_until": "2026-08-18T09:29:34+00:00"
                ]
            ])
            let encoded = payload.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            let subscription = CodexOfficialProfileReader.subscription(fromIDToken: "x.\(encoded).y")
            guard subscription?.planType == "plus", subscription?.activeUntil != nil else {
                print("Codex profile store self-test failed: subscription claims")
                return false
            }
            let identityClaims = try JSONSerialization.data(withJSONObject: [
                "email": "identity@example.com",
                "https://api.openai.com/auth": ["chatgpt_account_id": "acct-identity"]
            ])
            let identityPayload = identityClaims.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            let identityToken = "x.\(identityPayload).y"
            let validIdentityAuth = try JSONSerialization.data(withJSONObject: [
                "tokens": [
                    "access_token": identityToken,
                    "id_token": identityToken,
                    "account_id": "acct-identity"
                ]
            ])
            let mismatchedIdentityAuth = try JSONSerialization.data(withJSONObject: [
                "tokens": [
                    "access_token": identityToken,
                    "id_token": identityToken,
                    "account_id": "acct-other"
                ]
            ])
            guard CodexOfficialProfileReader.credentialIdentity(fromAuthData: validIdentityAuth)
                    == CodexCredentialIdentity(email: "identity@example.com", accountID: "acct-identity"),
                  CodexOfficialProfileReader.credentialIdentity(fromAuthData: mismatchedIdentityAuth) == nil
            else {
                print("Codex profile store self-test failed: stable account identity binding")
                return false
            }
            // 重置卡计数：自然滚动不计；同窗口额度回落与提前开新窗口计次；手动校正后系统卡与管理卡共享
            let resetHome = root.appendingPathComponent("reset-home", isDirectory: true)
            let resetSupport = root.appendingPathComponent("reset-support", isDirectory: true)
            let resetStore = CodexProfileStore(
                fileManager: fileManager,
                homeDirectory: resetHome,
                applicationSupportDirectory: resetSupport
            )
            let resetAccount = try resetStore.addManagedProfile()
            let week: TimeInterval = 604_800
            let base = Date(timeIntervalSince1970: 1_000_000)
            try resetStore.record(testResetSnapshot(
                email: "reset@example.com",
                usedPercent: 80,
                resetsAt: base.addingTimeInterval(week),
                fetchedAt: base
            ), for: resetAccount.id)
            try resetStore.record(testResetSnapshot(
                email: "reset@example.com",
                usedPercent: 50,
                resetsAt: base.addingTimeInterval(week * 2),
                fetchedAt: base.addingTimeInterval(week + 60)
            ), for: resetAccount.id)
            func resetCounterOf(_ store: CodexProfileStore) -> CodexAccountResetCounter {
                let key = store.profiles.first { $0.id == resetAccount.id }?.recordedAccountKey ?? ""
                return store.resetCounter(accountKey: key)
            }
            guard resetCounterOf(resetStore).automaticCount == 0 else {
                print("Codex profile store self-test failed: natural rollover must not count as reset")
                return false
            }
            try resetStore.record(testResetSnapshot(
                email: "reset@example.com",
                usedPercent: 5,
                resetsAt: base.addingTimeInterval(week * 2),
                fetchedAt: base.addingTimeInterval(week + 120)
            ), for: resetAccount.id)
            guard resetCounterOf(resetStore).automaticCount == 1 else {
                print("Codex profile store self-test failed: same-window quota restore should count")
                return false
            }
            try resetStore.record(testResetSnapshot(
                email: "reset@example.com",
                usedPercent: 90,
                resetsAt: base.addingTimeInterval(week * 2),
                fetchedAt: base.addingTimeInterval(week + 180)
            ), for: resetAccount.id)
            try resetStore.record(testResetSnapshot(
                email: "reset@example.com",
                usedPercent: 3,
                resetsAt: base.addingTimeInterval(week * 2 - 86_400 + week),
                fetchedAt: base.addingTimeInterval(week * 2 - 86_400)
            ), for: resetAccount.id)
            guard resetCounterOf(resetStore).automaticCount == 2 else {
                print("Codex profile store self-test failed: early new window should count")
                return false
            }
            guard resetCounterOf(resetStore).cardExpiresAt
                    == base.addingTimeInterval(week * 2 - 86_400 + week) else {
                print("Codex profile store self-test failed: counted reset should capture window end as expiry")
                return false
            }
            try resetStore.record(testResetSnapshot(
                email: "reset@example.com",
                usedPercent: 70,
                resetsAt: base.addingTimeInterval(week * 2 - 86_400 + week),
                fetchedAt: base.addingTimeInterval(week * 2 - 86_400 + 60)
            ), for: resetAccount.id)
            let resetKey = resetStore.profiles.first { $0.id == resetAccount.id }!.recordedAccountKey
            try resetStore.adjustResetManualOffset(accountKey: resetKey, delta: 1)
            guard resetStore.resetCounter(accountKey: resetKey).total == 3 else {
                print("Codex profile store self-test failed: manual offset should add to total")
                return false
            }
            try resetStore.adjustResetManualOffset(accountKey: resetKey, delta: -1)
            try resetStore.record(testResetSnapshot(
                email: "reset@example.com",
                usedPercent: 70,
                resetsAt: base.addingTimeInterval(week * 2 - 86_400 + week),
                fetchedAt: base.addingTimeInterval(week * 2 - 86_400 + 120)
            ), for: "system")
            guard resetStore.resetCounter(accountKey: resetKey).total == 2 else {
                print("Codex profile store self-test failed: counter must be shared by account, not by card")
                return false
            }
            try resetStore.record(testResetSnapshot(
                email: "reset@example.com",
                usedPercent: 4,
                resetsAt: base.addingTimeInterval(week * 2 - 86_400 + week),
                fetchedAt: base.addingTimeInterval(week * 2 - 86_400 + 180)
            ), for: "system")
            guard resetStore.resetCounter(accountKey: resetKey).total == 3 else {
                print("Codex profile store self-test failed: reset recorded via system card must land on shared counter")
                return false
            }
            let expiry = Date(timeIntervalSince1970: 1_900_000_000)
            try resetStore.setResetCardExpiry(accountKey: resetKey, date: expiry)
            guard resetStore.resetCounter(accountKey: resetKey).cardExpiresAt == expiry else {
                print("Codex profile store self-test failed: reset card expiry roundtrip")
                return false
            }
            try resetStore.setResetCardExpiry(accountKey: resetKey, date: nil)
            guard resetStore.resetCounter(accountKey: resetKey).cardExpiresAt == nil else {
                print("Codex profile store self-test failed: reset card expiry clear")
                return false
            }
            let manualExpiry = Date(timeIntervalSince1970: 1_950_000_000)
            try resetStore.adjustResetManualOffset(
                accountKey: resetKey,
                delta: 1,
                fallbackExpiry: manualExpiry
            )
            guard resetStore.resetCounter(accountKey: resetKey).cardExpiresAt == manualExpiry else {
                print("Codex profile store self-test failed: manual adjustment should fill expiry fallback")
                return false
            }
            // 回填：还原部署计数功能之前的历史重置，幂等且不误计自然滚动
            let backfillHome = root.appendingPathComponent("backfill-home", isDirectory: true)
            let backfillSupport = root.appendingPathComponent("backfill-support", isDirectory: true)
            let backfillStore = CodexProfileStore(
                fileManager: fileManager,
                homeDirectory: backfillHome,
                applicationSupportDirectory: backfillSupport
            )
            let backfillAccount = try backfillStore.addManagedProfile()
            let backfillWeek: TimeInterval = 604_800
            let backfillBase = Date(timeIntervalSince1970: 2_000_000)
            try backfillStore.record(testResetSnapshot(
                email: "backfill@example.com",
                usedPercent: 100,
                resetsAt: backfillBase.addingTimeInterval(backfillWeek),
                fetchedAt: backfillBase
            ), for: backfillAccount.id)
            try backfillStore.record(testResetSnapshot(
                email: "backfill@example.com",
                usedPercent: 23,
                resetsAt: backfillBase.addingTimeInterval(backfillWeek * 2 + 15_885),
                fetchedAt: backfillBase.addingTimeInterval(backfillWeek + 15_885)
            ), for: "system")
            let backfillKey = backfillStore.profiles
                .first { $0.id == backfillAccount.id }!
                .recordedAccountKey
            guard backfillStore.resetCounter(accountKey: backfillKey).total == 0 else {
                print("Codex profile store self-test failed: setup snapshots must not trigger live counting")
                return false
            }
            backfillStore.backfillResetCountersFromHistory()
            guard backfillStore.resetCounter(accountKey: backfillKey).total == 1 else {
                print("Codex profile store self-test failed: backfill should restore the historical reset")
                return false
            }
            backfillStore.backfillResetCountersFromHistory()
            guard backfillStore.resetCounter(accountKey: backfillKey).total == 1 else {
                print("Codex profile store self-test failed: backfill must be idempotent")
                return false
            }
            // 同组另一张卡已观察到的新窗口，live 记录不得再计一次
            try backfillStore.record(testResetSnapshot(
                email: "backfill@example.com",
                usedPercent: 23,
                resetsAt: backfillBase.addingTimeInterval(backfillWeek * 2 + 15_885),
                fetchedAt: backfillBase.addingTimeInterval(backfillWeek + 16_000)
            ), for: backfillAccount.id)
            guard backfillStore.resetCounter(accountKey: backfillKey).total == 1 else {
                print("Codex profile store self-test failed: window already observed by group must not double count")
                return false
            }
            let naturalAccount = try backfillStore.addManagedProfile()
            try backfillStore.record(testResetSnapshot(
                email: "natural@example.com",
                usedPercent: 80,
                resetsAt: backfillBase.addingTimeInterval(backfillWeek),
                fetchedAt: backfillBase
            ), for: naturalAccount.id)
            try backfillStore.record(testResetSnapshot(
                email: "natural@example.com",
                usedPercent: 5,
                resetsAt: backfillBase.addingTimeInterval(backfillWeek * 2),
                fetchedAt: backfillBase.addingTimeInterval(backfillWeek + 60)
            ), for: "system", allowSystemAccountChange: true)
            backfillStore.backfillResetCountersFromHistory()
            let naturalKey = backfillStore.profiles
                .first { $0.id == naturalAccount.id }!
                .recordedAccountKey
            guard backfillStore.resetCounter(accountKey: naturalKey).total == 0 else {
                print("Codex profile store self-test failed: natural rollover must stay at zero after backfill")
                return false
            }
            // 同账号同步只接受身份匹配的系统凭据，避免登录切换竞态污染管理卡。
            let syncHome = root.appendingPathComponent("sync-home", isDirectory: true)
            let syncSupport = root.appendingPathComponent("sync-support", isDirectory: true)
            let syncStore = CodexProfileStore(
                fileManager: fileManager,
                homeDirectory: syncHome,
                applicationSupportDirectory: syncSupport
            )
            let syncManaged = try syncStore.addManagedProfile()
            let syncSnapshot = testSnapshot(
                email: "sync@example.com",
                usedPercent: 10,
                at: Date(timeIntervalSince1970: 10_000)
            )
            try syncStore.record(syncSnapshot, for: syncManaged.id)
            try syncStore.record(syncSnapshot, for: "system", allowSystemAccountChange: true)
            let syncSystemHome = syncHome.appendingPathComponent(".codex", isDirectory: true)
            try fileManager.createDirectory(at: syncSystemHome, withIntermediateDirectories: true)
            let managedAuthURL = syncManaged.codexHomeURL.appendingPathComponent("auth.json")
            let systemAuthURL = syncSystemHome.appendingPathComponent("auth.json")
            let oldManagedAuth = try testAuthData(email: "sync@example.com", accessToken: "old")
            let freshSystemAuth = try testAuthData(email: "sync@example.com", accessToken: "fresh")
            try oldManagedAuth.write(to: managedAuthURL)
            try fileManager.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: 10_000)],
                ofItemAtPath: managedAuthURL.path
            )
            try freshSystemAuth.write(to: systemAuthURL)
            try fileManager.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: 20_000)],
                ofItemAtPath: systemAuthURL.path
            )
            try syncStore.record(syncSnapshot, for: syncManaged.id)
            try syncStore.record(syncSnapshot, for: "system", allowSystemAccountChange: true)
            try syncStore.syncSystemAuthToMatchingManagedProfiles()
            guard try Data(contentsOf: managedAuthURL) == freshSystemAuth else {
                print("Codex profile store self-test failed: matching system auth sync")
                return false
            }
            let mismatchedSystemAuth = try testAuthData(email: "other@example.com", accessToken: "wrong")
            try mismatchedSystemAuth.write(to: systemAuthURL)
            try fileManager.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: 30_000)],
                ofItemAtPath: systemAuthURL.path
            )
            try syncStore.syncSystemAuthToMatchingManagedProfiles()
            guard try Data(contentsOf: managedAuthURL) == freshSystemAuth else {
                print("Codex profile store self-test failed: mismatched system auth must not sync")
                return false
            }
            try restored.discardManagedProfile(added.id)
            guard restored.profiles.count == 1,
                  restored.selectedMonitorProfileID == "system",
                  restored.selectedLaunchProfileID == "system"
            else {
                print("Codex profile store self-test failed: removal")
                return false
            }
            print("Codex profile store self-test passed")
            return true
        } catch {
            print("Codex profile store self-test failed: \(error)")
            return false
        }
    }

    private static func testSnapshot(email: String, usedPercent: Double, at date: Date) -> UsageSnapshot {
        UsageSnapshot(
            refreshedAt: date,
            account: AccountInfo(type: "chatgpt", planType: "plus", emailPresent: true, email: email),
            limitId: "codex",
            limitName: nil,
            quotaReadSucceeded: true,
            fiveHourQuota: nil,
            sevenDayQuota: RateWindow(usedPercent: usedPercent, windowDurationMins: 10_080, resetsAt: nil),
            monthlyQuota: nil,
            credits: nil,
            cloudLifetimeTokens: nil,
            local: nil,
            taskBoard: nil,
            messages: []
        )
    }

    private static func testAuthData(email: String, accessToken: String) throws -> Data {
        let accountID = "acct-" + email.lowercased()
        let payload = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "https://api.openai.com/auth": ["chatgpt_account_id": accountID]
        ])
        let encoded = payload.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return try JSONSerialization.data(withJSONObject: [
            "tokens": [
                "access_token": accessToken,
                "id_token": "x.\(encoded).y",
                "account_id": accountID
            ]
        ])
    }

    private static func testResetSnapshot(
        email: String,
        usedPercent: Double,
        resetsAt: Date,
        fetchedAt: Date
    ) -> UsageSnapshot {
        UsageSnapshot(
            refreshedAt: fetchedAt,
            account: AccountInfo(type: "chatgpt", planType: "plus", emailPresent: true, email: email),
            limitId: "codex",
            limitName: nil,
            quotaReadSucceeded: true,
            fiveHourQuota: nil,
            sevenDayQuota: RateWindow(usedPercent: usedPercent, windowDurationMins: 10_080, resetsAt: resetsAt),
            monthlyQuota: nil,
            credits: nil,
            cloudLifetimeTokens: nil,
            local: nil,
            taskBoard: nil,
            messages: []
        )
    }
}
