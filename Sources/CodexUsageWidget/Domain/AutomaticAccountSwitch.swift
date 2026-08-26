import Foundation

enum AutomaticQuotaWindow: String, CaseIterable, Equatable {
    case fiveHour
    case sevenDay

    var displayName: String {
        switch self {
        case .fiveHour: return "5 小时"
        case .sevenDay: return "7 天"
        }
    }
}

struct AutomaticSwitchQuotaState: Equatable {
    let fiveHourRemaining: Double?
    let sevenDayRemaining: Double?

    init(fiveHourRemaining: Double?, sevenDayRemaining: Double?) {
        self.fiveHourRemaining = Self.valid(fiveHourRemaining)
        self.sevenDayRemaining = Self.valid(sevenDayRemaining)
    }

    init(snapshot: UsageSnapshot) {
        self.init(
            fiveHourRemaining: snapshot.fiveHourQuota?.remainingPercent,
            sevenDayRemaining: snapshot.sevenDayQuota?.remainingPercent
        )
    }

    func remaining(for window: AutomaticQuotaWindow) -> Double? {
        switch window {
        case .fiveHour: return fiveHourRemaining
        case .sevenDay: return sevenDayRemaining
        }
    }

    func triggeredWindows(threshold: Double = CodexAutomaticSwitchPolicy.triggerRemainingPercent) -> [AutomaticQuotaWindow] {
        AutomaticQuotaWindow.allCases.filter { window in
            guard let remaining = remaining(for: window) else { return false }
            return remaining < threshold
        }
    }

    private static func valid(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return max(0, min(100, value))
    }
}

enum CodexAutomaticSwitchPolicy {
    struct Candidate: Equatable {
        let profileID: String
        let quota: AutomaticSwitchQuotaState
    }

    static let enabledDefaultsKey = "CodexManagerNext.automaticAccountSwitch.enabled"
    static let lastAttemptDefaultsKey = "CodexManagerNext.automaticAccountSwitch.lastAttemptAt"
    static let lastSuccessDefaultsKey = "CodexManagerNext.automaticAccountSwitch.lastSucceededAt"
    static let triggerRemainingPercent = 10.0
    static let minimumCandidateRemainingPercent = 30.0
    static let failureRetryInterval: TimeInterval = 60 * 60
    static let successCooldown: TimeInterval = 30 * 60
    static let quotaSnapshotMaximumAge: TimeInterval = 45
    static let taskSnapshotMaximumAge: TimeInterval = 45
    static let codexInactivePeriod: TimeInterval = 2 * 60

    static func hasNoActiveTasks(
        _ snapshot: CodexTaskLiveSnapshot,
        legacyManagerRunning: Bool,
        now: Date = Date()
    ) -> Bool {
        guard !legacyManagerRunning,
              snapshot.connectionMode != .disconnected
        else { return false }
        let snapshotAge = now.timeIntervalSince(snapshot.refreshedAt)
        guard snapshotAge >= -5, snapshotAge <= taskSnapshotMaximumAge else { return false }
        return !snapshot.records.values.contains {
            switch $0.state {
            case .running, .waitingInput, .recorded, .disconnected:
                return true
            case .idle, .failed, .completed, .interrupted:
                return false
            }
        }
    }

    static func hasSafeTaskState(
        _ snapshot: CodexTaskLiveSnapshot,
        codexInactiveSince: Date?,
        legacyManagerRunning: Bool,
        now: Date = Date()
    ) -> Bool {
        guard let codexInactiveSince,
              now.timeIntervalSince(codexInactiveSince) >= codexInactivePeriod
        else { return false }
        return hasNoActiveTasks(
            snapshot,
            legacyManagerRunning: legacyManagerRunning,
            now: now
        )
    }

    static func shouldEvaluate(
        enabled: Bool,
        sourceQuota: AutomaticSwitchQuotaState,
        sourceRefreshedAt: Date,
        taskSnapshot: CodexTaskLiveSnapshot,
        codexInactiveSince: Date?,
        legacyManagerRunning: Bool,
        lastAttemptAt: Date?,
        lastSucceededAt: Date?,
        now: Date = Date()
    ) -> Bool {
        let quotaAge = now.timeIntervalSince(sourceRefreshedAt)
        guard enabled,
              quotaAge >= -5,
              quotaAge <= quotaSnapshotMaximumAge,
              !sourceQuota.triggeredWindows().isEmpty,
              hasSafeTaskState(
                taskSnapshot,
                codexInactiveSince: codexInactiveSince,
                legacyManagerRunning: legacyManagerRunning,
                now: now
              )
        else { return false }
        if let lastSucceededAt,
           now.timeIntervalSince(lastSucceededAt) < successCooldown {
            return false
        }
        if let lastAttemptAt,
           now.timeIntervalSince(lastAttemptAt) < failureRetryInterval {
            return false
        }
        return true
    }

    static func preferredCandidate(
        _ candidates: [Candidate],
        for triggeredWindows: [AutomaticQuotaWindow]
    ) -> Candidate? {
        guard !triggeredWindows.isEmpty else { return nil }
        return candidates.compactMap { candidate -> (Candidate, Double)? in
            let remaining = triggeredWindows.compactMap(candidate.quota.remaining(for:))
            guard remaining.count == triggeredWindows.count,
                  let score = remaining.min(),
                  score >= minimumCandidateRemainingPercent
            else { return nil }
            return (candidate, score)
        }.max { lhs, rhs in
            lhs.1 == rhs.1 ? lhs.0.profileID > rhs.0.profileID : lhs.1 < rhs.1
        }?.0
    }

    static func lowestTrigger(
        in sourceQuota: AutomaticSwitchQuotaState
    ) -> (window: AutomaticQuotaWindow, remaining: Double)? {
        sourceQuota.triggeredWindows().compactMap { window in
            sourceQuota.remaining(for: window).map { (window, $0) }
        }.min { $0.1 < $1.1 }
    }
}

enum CodexAutomaticSwitchPolicySelfTest {
    static func run() -> Bool {
        let now = Date(timeIntervalSince1970: 100_000)
        let idle = CodexTaskLiveSnapshot(connectionMode: .sharedDaemon, records: [:], refreshedAt: now)
        let active = CodexTaskLiveSnapshot(
            connectionMode: .sharedDaemon,
            records: [
                "task": TaskLiveRecord(
                    threadID: "task",
                    name: nil,
                    state: .running,
                    updatedAt: now,
                    turnID: nil,
                    connectionMode: .sharedDaemon
                )
            ],
            refreshedAt: now
        )
        let low = AutomaticSwitchQuotaState(fiveHourRemaining: 9, sevenDayRemaining: 55)
        let exactThreshold = AutomaticSwitchQuotaState(fiveHourRemaining: 10, sevenDayRemaining: 55)
        let safeSince = now.addingTimeInterval(-CodexAutomaticSwitchPolicy.codexInactivePeriod)
        let selected = CodexAutomaticSwitchPolicy.preferredCandidate([
            .init(profileID: "first", quota: .init(fiveHourRemaining: 65, sevenDayRemaining: 80)),
            .init(profileID: "second", quota: .init(fiveHourRemaining: 90, sevenDayRemaining: 45)),
            .init(profileID: "third", quota: .init(fiveHourRemaining: 20, sevenDayRemaining: 99))
        ], for: [.fiveHour])

        guard CodexAutomaticSwitchPolicy.hasNoActiveTasks(
            idle,
            legacyManagerRunning: false,
            now: now
        ),
        !CodexAutomaticSwitchPolicy.hasNoActiveTasks(
            active,
            legacyManagerRunning: false,
            now: now
        ),
        !CodexAutomaticSwitchPolicy.hasNoActiveTasks(
            .disconnected,
            legacyManagerRunning: false,
            now: now
        ),
        CodexAutomaticSwitchPolicy.shouldEvaluate(
            enabled: true,
            sourceQuota: low,
            sourceRefreshedAt: now,
            taskSnapshot: idle,
            codexInactiveSince: safeSince,
            legacyManagerRunning: false,
            lastAttemptAt: nil,
            lastSucceededAt: nil,
            now: now
        ),
        !CodexAutomaticSwitchPolicy.shouldEvaluate(
            enabled: true,
            sourceQuota: exactThreshold,
            sourceRefreshedAt: now,
            taskSnapshot: idle,
            codexInactiveSince: safeSince,
            legacyManagerRunning: false,
            lastAttemptAt: nil,
            lastSucceededAt: nil,
            now: now
        ),
        !CodexAutomaticSwitchPolicy.shouldEvaluate(
            enabled: true,
            sourceQuota: low,
            sourceRefreshedAt: now,
            taskSnapshot: active,
            codexInactiveSince: safeSince,
            legacyManagerRunning: false,
            lastAttemptAt: nil,
            lastSucceededAt: nil,
            now: now
        ),
        !CodexAutomaticSwitchPolicy.shouldEvaluate(
            enabled: true,
            sourceQuota: low,
            sourceRefreshedAt: now,
            taskSnapshot: .disconnected,
            codexInactiveSince: safeSince,
            legacyManagerRunning: false,
            lastAttemptAt: nil,
            lastSucceededAt: nil,
            now: now
        ),
        !CodexAutomaticSwitchPolicy.shouldEvaluate(
            enabled: true,
            sourceQuota: low,
            sourceRefreshedAt: now,
            taskSnapshot: idle,
            codexInactiveSince: safeSince,
            legacyManagerRunning: true,
            lastAttemptAt: nil,
            lastSucceededAt: nil,
            now: now
        ),
        !CodexAutomaticSwitchPolicy.shouldEvaluate(
            enabled: true,
            sourceQuota: low,
            sourceRefreshedAt: now,
            taskSnapshot: idle,
            codexInactiveSince: safeSince,
            legacyManagerRunning: false,
            lastAttemptAt: now.addingTimeInterval(-300),
            lastSucceededAt: nil,
            now: now
        ),
        !CodexAutomaticSwitchPolicy.shouldEvaluate(
            enabled: true,
            sourceQuota: low,
            sourceRefreshedAt: now.addingTimeInterval(-46),
            taskSnapshot: idle,
            codexInactiveSince: safeSince,
            legacyManagerRunning: false,
            lastAttemptAt: nil,
            lastSucceededAt: nil,
            now: now
        ),
        selected?.profileID == "second",
        CodexAutomaticSwitchPolicy.preferredCandidate([
            .init(profileID: "missing", quota: .init(fiveHourRemaining: 99, sevenDayRemaining: nil))
        ], for: [.fiveHour, .sevenDay]) == nil
        else {
            print("Codex automatic account switch policy self-test failed")
            return false
        }
        print("Codex automatic account switch policy self-test passed")
        return true
    }
}
