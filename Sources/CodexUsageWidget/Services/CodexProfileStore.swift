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
    let limitId: String?
    let limitName: String?
    let fiveHour: CodexQuotaWindowSnapshot?
    let sevenDay: CodexQuotaWindowSnapshot?
    let monthly: CodexQuotaWindowSnapshot?
    let fetchedAt: Date
    let appServerVersion: String?
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

enum CodexWarmUpPolicy {
    static let fallbackInterval: TimeInterval = 4 * 60 * 60 + 45 * 60
    static let failureRetryInterval: TimeInterval = 30 * 60
    static let minimumWeeklyRemaining = 5.0

    static func nextEligibleDate(for profile: CodexProfile, now: Date = Date()) -> Date? {
        if let activeUntil = profile.officialProfile?.subscriptionActiveUntil, activeUntil <= now {
            return nil
        }
        if let weekly = profile.lastSnapshot?.sevenDay,
           100 - weekly.usedPercent <= minimumWeeklyRemaining {
            return nil
        }
        if profile.lastWarmUpSucceeded == false, let attemptedAt = profile.lastWarmUpAt {
            return attemptedAt.addingTimeInterval(failureRetryInterval)
        }
        guard let window = profile.lastSnapshot?.fiveHour,
              let resetsAt = window.resetsAt,
              let duration = window.windowDurationMins,
              duration > 0
        else {
            return profile.lastWarmUpAt?.addingTimeInterval(fallbackInterval) ?? now
        }
        guard let lastWarmUpAt = profile.lastWarmUpAt else { return now }
        let windowStart = resetsAt.addingTimeInterval(-TimeInterval(duration * 60))
        if lastWarmUpAt < windowStart { return now }
        if resetsAt <= now { return lastWarmUpAt.addingTimeInterval(fallbackInterval) }
        return resetsAt
    }

    static func isDue(_ profile: CodexProfile, now: Date = Date()) -> Bool {
        nextEligibleDate(for: profile, now: now).map { $0 <= now } ?? false
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
              let accountID = tokens["account_id"] as? String,
              !accessToken.isEmpty,
              !accountID.isEmpty
        else { return nil }

        let idToken = tokens["id_token"] as? String
        let subscription = subscription(fromIDToken: idToken)
        var request = URLRequest(url: profileURL, timeoutInterval: 12)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
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
        guard let claims = claims(fromIDToken: idToken),
              let auth = claims["https://api.openai.com/auth"] as? [String: Any]
        else { return nil }
        return (
            nonEmpty(auth["chatgpt_plan_type"] as? String),
            parseDate(auth["chatgpt_subscription_active_until"] as? String)
        )
    }

    private static func email(fromIDToken idToken: String?) -> String? {
        nonEmpty(claims(fromIDToken: idToken)?["email"] as? String)
    }

    private static func claims(fromIDToken idToken: String?) -> [String: Any]? {
        guard let idToken else { return nil }
        let parts = idToken.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
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

final class CodexProfileStore {
    private struct State: Codable {
        let schemaVersion: Int
        var profiles: [CodexProfile]
        var selectedMonitorProfileID: String
        var selectedLaunchProfileID: String
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
        managedRootURL = home.appendingPathComponent(".codexu/p", isDirectory: true)
        let support = applicationSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? home.appendingPathComponent("Library/Application Support", isDirectory: true)
        stateURL = support
            .appendingPathComponent("CodexAccountManager", isDirectory: true)
            .appendingPathComponent("account-manager-0814v1.json")

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
    func preserveSystemLogin() throws -> CodexProfile {
        guard let systemIndex = state.profiles.firstIndex(where: \.isSystemProfile) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let system = state.profiles[systemIndex]
        guard system.lastSnapshot?.email?.isEmpty == false else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let sourceAuth = system.codexHomeURL.appendingPathComponent("auth.json")
        let authData = try Data(contentsOf: sourceAuth)
        if let existing = state.profiles.first(where: {
            !$0.isSystemProfile && $0.recordedAccountKey == system.recordedAccountKey
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
            lastSnapshot: system.lastSnapshot,
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
            !$0.isSystemProfile && $0.matchesRecordedAccount(email: system.lastSnapshot?.email)
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
        let accountChanged = !state.profiles[index].matchesRecordedAccount(email: snapshot.account?.email)
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
            limitId: snapshot.limitId,
            limitName: snapshot.limitName,
            fiveHour: snapshot.fiveHourQuota.map(CodexQuotaWindowSnapshot.init),
            sevenDay: snapshot.sevenDayQuota.map(CodexQuotaWindowSnapshot.init),
            monthly: snapshot.monthlyQuota.map(CodexQuotaWindowSnapshot.init),
            fetchedAt: snapshot.refreshedAt,
            appServerVersion: CodexExecutable.version()
        )
        state.profiles[index].lastSnapshot = record
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
            let systemAuth = Data("system-auth".utf8)
            try systemAuth.write(to: systemHome.appendingPathComponent("auth.json"))
            let preserved = try reordered.preserveSystemLogin()
            let preservedAuth = try Data(contentsOf: preserved.codexHomeURL.appendingPathComponent("auth.json"))
            let preservedAgain = try reordered.preserveSystemLogin()
            guard preserved.lastSnapshot?.email == "first@example.com",
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
            policyProfile.lastWarmUpAt = Date(timeIntervalSince1970: -100)
            guard CodexWarmUpPolicy.isDue(policyProfile, now: Date(timeIntervalSince1970: 1_000)) else {
                print("Codex profile store self-test failed: warm-up policy")
                return false
            }
            policyProfile.lastWarmUpAt = Date(timeIntervalSince1970: 1_000)
            guard !CodexWarmUpPolicy.isDue(policyProfile, now: Date(timeIntervalSince1970: 1_100)) else {
                print("Codex profile store self-test failed: duplicate warm-up")
                return false
            }
            policyProfile.lastWarmUpSucceeded = false
            guard !CodexWarmUpPolicy.isDue(policyProfile, now: Date(timeIntervalSince1970: 1_100)) else {
                print("Codex profile store self-test failed: warm-up retry cooldown")
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
}
