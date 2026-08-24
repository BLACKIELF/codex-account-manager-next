import Foundation

enum LeadershipWorkerKind: String, Codable, CaseIterable, Equatable {
    case main
    case subagent
    case automation
}

enum LeadershipEvidenceQuality: String, Codable, Equatable {
    case fact
    case derived
    case estimated

    var confidence: Double {
        switch self {
        case .fact: 1
        case .derived: 0.9
        case .estimated: 0.6
        }
    }

    var isScorable: Bool { self != .estimated }
}

struct LeadershipWorker: Codable, Equatable {
    let id: String
    let runtime: RuntimeScope
    let kind: LeadershipWorkerKind
    let projectID: String
    let projectName: String
    let parentID: String?
}

struct LeadershipInterval: Codable, Equatable {
    let id: String
    let workerID: String
    let runtime: RuntimeScope
    let workerKind: LeadershipWorkerKind
    let projectID: String
    let startAt: Date
    let endAt: Date
    let quality: LeadershipEvidenceQuality
    let isAutonomous: Bool

    var duration: TimeInterval { max(0, endAt.timeIntervalSince(startAt)) }
}

enum LeadershipPeriod: String, Codable, CaseIterable, Identifiable, Equatable {
    case today
    case sevenDays
    case twentyEightDays

    var id: String { rawValue }

    var dayCount: Int {
        switch self {
        case .today: 1
        case .sevenDays: 7
        case .twentyEightDays: 28
        }
    }
}

enum LeadershipDimensionKind: String, Codable, CaseIterable, Identifiable, Equatable {
    case span
    case leverage
    case orchestration
    case autonomy

    var id: String { rawValue }

    var weight: Double {
        switch self {
        case .span, .leverage: 0.30
        case .orchestration: 0.25
        case .autonomy: 0.15
        }
    }
}

struct LeadershipDimension: Codable, Identifiable, Equatable {
    let kind: LeadershipDimensionKind
    let score: Double
    let confidence: Double
    let summaryValue: Double

    var id: String { kind.rawValue }
}

struct LeadershipTitle: Codable, Equatable {
    let level: Int
    let name: String
    let lowerBound: Int
    let upperBound: Int

    var englishName: String {
        switch level {
        case 1: "Carbon Laborer"
        case 2: "Cyber Overseer"
        case 3: "Clone Captain"
        case 4: "Silicon Lord"
        case 5: "Silicon Marshal"
        case 6: "Super Individual"
        default: "Humanity's Apex"
        }
    }
}

struct LeadershipDayPoint: Codable, Identifiable, Equatable {
    let day: Date
    let agentCount: Int
    let aiHours: Double
    let peakConcurrency: Int

    var id: Date { day }
}

struct LeadershipProjectContribution: Codable, Identifiable, Equatable {
    let projectID: String
    let projectName: String
    let agentCount: Int
    let aiHours: Double
    let autonomousHours: Double

    var id: String { projectID }
}

struct LeadershipReport: Codable, Identifiable, Equatable {
    let period: LeadershipPeriod
    let score: Int?
    let coreScore: Double?
    let title: LeadershipTitle?
    let dimensions: [LeadershipDimension]
    let maturity: Double
    let evidenceCoverage: Double
    let activeDayCount: Int
    let agentCount: Int?
    let aiHours: Double?
    let autonomousHours: Double?
    let averageParallelism: Double?
    let peakConcurrency: Int?
    let projectCount: Int
    let dailyPoints: [LeadershipDayPoint]
    let projects: [LeadershipProjectContribution]

    var id: String { period.rawValue }
}

struct LeadershipDashboardSnapshot: Equatable {
    let modelVersion: String
    let refreshedAt: Date
    let reports: [LeadershipReport]

    static let empty = LeadershipDashboardSnapshot(
        modelVersion: LeadershipScoreModel.version,
        refreshedAt: Date(),
        reports: []
    )

    func report(period: LeadershipPeriod) -> LeadershipReport? {
        reports.first { $0.period == period }
    }

    var defaultReport: LeadershipReport? {
        report(period: .twentyEightDays)
    }

    var todayReport: LeadershipReport? {
        report(period: .today)
    }
}

enum LeadershipScoreModel {
    static let version = "1.3"
    static let minimumEvidenceCoverage = 0.70
    static let normalEvidenceCoverage = 0.90

    private static let effectiveWorkerReference = 12.0
    private static let peakConcurrencyReference = 6.0
    private static let dailyAIHoursReference = 8.0
    private static let averageParallelismReference = 3.0
    private static let delegatedShareReference = 0.60
    private static let parallelShareReference = 0.50
    private static let multiProjectShareReference = 0.35
    private static let autonomousShareReference = 0.60
    private static let longestAutonomousHoursReference = 2.0
    private static let autonomousDayShareReference = 0.70

    static func dimensions(
        effectiveWorkers: Double,
        peakConcurrency: Int,
        dailyAIHours: Double,
        averageParallelism: Double,
        delegatedShare: Double,
        parallelShare: Double,
        multiProjectShare: Double,
        autonomousShare: Double,
        longestAutonomousHours: Double,
        autonomousDayShare: Double,
        confidence: Double
    ) -> [LeadershipDimension] {
        let span = 100 * (
            0.70 * normalize(effectiveWorkers, reference: effectiveWorkerReference)
                + 0.30 * normalize(Double(peakConcurrency), reference: peakConcurrencyReference)
        )
        let leverage = 100 * (
            0.70 * normalize(dailyAIHours, reference: dailyAIHoursReference)
                + 0.30 * normalize(averageParallelism, reference: averageParallelismReference)
        )
        let orchestration = 100 * (
            0.45 * normalizeLinear(delegatedShare, reference: delegatedShareReference)
                + 0.35 * normalizeLinear(parallelShare, reference: parallelShareReference)
                + 0.20 * normalizeLinear(multiProjectShare, reference: multiProjectShareReference)
        )
        let autonomy = 100 * (
            0.50 * normalizeLinear(autonomousShare, reference: autonomousShareReference)
                + 0.30 * normalize(longestAutonomousHours, reference: longestAutonomousHoursReference)
                + 0.20 * normalizeLinear(autonomousDayShare, reference: autonomousDayShareReference)
        )

        return [
            LeadershipDimension(kind: .span, score: bounded(span), confidence: confidence, summaryValue: effectiveWorkers),
            LeadershipDimension(kind: .leverage, score: bounded(leverage), confidence: confidence, summaryValue: dailyAIHours),
            LeadershipDimension(kind: .orchestration, score: bounded(orchestration), confidence: confidence, summaryValue: delegatedShare),
            LeadershipDimension(kind: .autonomy, score: bounded(autonomy), confidence: confidence, summaryValue: autonomousShare)
        ]
    }

    static func coreScore(_ dimensions: [LeadershipDimension]) -> Double? {
        guard dimensions.count == LeadershipDimensionKind.allCases.count else { return nil }
        let byKind = Dictionary(uniqueKeysWithValues: dimensions.map { ($0.kind, $0.score) })
        guard LeadershipDimensionKind.allCases.allSatisfy({ byKind[$0] != nil }) else { return nil }
        let exponent = LeadershipDimensionKind.allCases.reduce(0.0) { partial, kind in
            let score = max(byKind[kind] ?? 0, 1) / 100
            return partial + kind.weight * log(score)
        }
        return bounded(100 * exp(exponent))
    }

    static func maturity(activeDays: Int) -> Double {
        guard activeDays > 0 else { return 0 }
        if activeDays >= 28 { return 1 }
        return min(1, 0.2 + 0.8 * (1 - exp(-Double(activeDays) / 6)))
    }

    static func finalScore(
        dimensions: [LeadershipDimension],
        activeDays: Int,
        evidenceCoverage: Double
    ) -> (score: Int, core: Double)? {
        guard evidenceCoverage >= minimumEvidenceCoverage,
              let core = coreScore(dimensions),
              activeDays > 0
        else { return nil }
        var score = Int((core * maturity(activeDays: activeDays)).rounded())
        score = min(max(score, 0), 100)
        if score == 100, (activeDays < 28 || evidenceCoverage < 0.95) {
            score = 99
        }
        return (score, core)
    }

    static func title(for score: Int) -> LeadershipTitle {
        switch score {
        case 93...: LeadershipTitle(level: 7, name: "人类最强者", lowerBound: 93, upperBound: 100)
        case 80...92: LeadershipTitle(level: 6, name: "超级个体", lowerBound: 80, upperBound: 92)
        case 65...79: LeadershipTitle(level: 5, name: "硅基统帅", lowerBound: 65, upperBound: 79)
        case 50...64: LeadershipTitle(level: 4, name: "硅基领主", lowerBound: 50, upperBound: 64)
        case 35...49: LeadershipTitle(level: 3, name: "分身队长", lowerBound: 35, upperBound: 49)
        case 20...34: LeadershipTitle(level: 2, name: "赛博监工", lowerBound: 20, upperBound: 34)
        default: LeadershipTitle(level: 1, name: "碳基牛马", lowerBound: 0, upperBound: 19)
        }
    }

    static func nextTitle(after title: LeadershipTitle) -> LeadershipTitle? {
        guard title.level < 7 else { return nil }
        let nextScore: Int
        switch title.level {
        case 1: nextScore = 20
        case 2: nextScore = 35
        case 3: nextScore = 50
        case 4: nextScore = 65
        case 5: nextScore = 80
        default: nextScore = 93
        }
        return self.title(for: nextScore)
    }

    private static func normalize(_ value: Double, reference: Double) -> Double {
        guard value > 0, reference > 0 else { return 0 }
        return min(1, log1p(value) / log1p(reference))
    }

    private static func normalizeLinear(_ value: Double, reference: Double) -> Double {
        guard reference > 0 else { return 0 }
        return min(max(value / reference, 0), 1)
    }

    private static func bounded(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

struct LeadershipAggregator {
    func makeDashboard(
        workers: [LeadershipWorker],
        intervals: [LeadershipInterval],
        now: Date,
        calendar: Calendar
    ) -> LeadershipDashboardSnapshot {
        let reports = LeadershipPeriod.allCases.map { period in
            makeReport(
                workers: workers,
                intervals: intervals,
                period: period,
                now: now,
                calendar: calendar
            )
        }
        return LeadershipDashboardSnapshot(
            modelVersion: LeadershipScoreModel.version,
            refreshedAt: now,
            reports: reports
        )
    }

    private func makeReport(
        workers: [LeadershipWorker],
        intervals: [LeadershipInterval],
        period: LeadershipPeriod,
        now: Date,
        calendar: Calendar
    ) -> LeadershipReport {
        let end = now
        let todayStart = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(period.dayCount - 1), to: todayStart) ?? todayStart
        let filtered = intervals.filter { interval in
            interval.quality.isScorable
                && interval.endAt > start
                && interval.startAt < end
        }.compactMap { clip($0, start: start, end: end) }
        let merged = mergePerWorker(filtered)
        let metrics = timelineMetrics(merged)
        let activeWorkerIDs = Set(merged.map(\.workerID))
        let activeWorkers = workers.filter { activeWorkerIDs.contains($0.id) }
        let dayPoints = makeDayPoints(intervals: merged, start: start, now: now, calendar: calendar)
        let activeDayCount = dayPoints.filter { point in
            point.aiHours >= 0.25 || point.agentCount > 0 && hasAutonomousInterval(on: point.day, intervals: merged, calendar: calendar)
        }.count
        let aiHours = merged.reduce(0.0) { $0 + $1.duration } / 3600
        let autonomousIntervals = merged.filter(\.isAutonomous)
        let autonomousHours = autonomousIntervals.reduce(0.0) { $0 + $1.duration } / 3600
        let workerHours = Dictionary(grouping: merged, by: \.workerID).mapValues { values in
            values.reduce(0.0) { $0 + $1.duration } / 3600
        }
        let effectiveWorkers = workerHours.values.reduce(0.0) { $0 + min($1, 1) }
        let dailyAIHours = activeDayCount > 0 ? aiHours / Double(activeDayCount) : 0
        let delegatedHours = merged.filter { $0.workerKind == .subagent }.reduce(0.0) { $0 + $1.duration } / 3600
        let delegatedShare = aiHours > 0 ? delegatedHours / aiHours : 0
        let autonomousShare = aiHours > 0 ? autonomousHours / aiHours : 0
        let longestAutonomousHours = autonomousIntervals.map(\.duration).max().map { $0 / 3600 } ?? 0
        let autonomousDayCount = Set(autonomousIntervals.map { calendar.startOfDay(for: $0.startAt) }).count
        let autonomousDayShare = activeDayCount > 0 ? Double(autonomousDayCount) / Double(activeDayCount) : 0
        let confidence = durationWeightedConfidence(merged)
        let dimensions = activeDayCount > 0 ? LeadershipScoreModel.dimensions(
            effectiveWorkers: effectiveWorkers,
            peakConcurrency: metrics.peakConcurrency,
            dailyAIHours: dailyAIHours,
            averageParallelism: metrics.averageParallelism,
            delegatedShare: delegatedShare,
            parallelShare: metrics.activeWindow > 0 ? metrics.parallelWindow / metrics.activeWindow : 0,
            multiProjectShare: metrics.activeWindow > 0 ? metrics.multiProjectWindow / metrics.activeWindow : 0,
            autonomousShare: autonomousShare,
            longestAutonomousHours: longestAutonomousHours,
            autonomousDayShare: autonomousDayShare,
            confidence: confidence
        ) : []
        let evidenceCoverage = dimensions.reduce(0.0) { $0 + $1.kind.weight * $1.confidence }
        let final = LeadershipScoreModel.finalScore(
            dimensions: dimensions,
            activeDays: activeDayCount,
            evidenceCoverage: evidenceCoverage
        )
        let projectContributions = makeProjectContributions(
            workers: activeWorkers,
            intervals: merged
        )

        return LeadershipReport(
            period: period,
            score: final?.score,
            coreScore: final?.core,
            title: final.map { LeadershipScoreModel.title(for: $0.score) },
            dimensions: dimensions,
            maturity: LeadershipScoreModel.maturity(activeDays: activeDayCount),
            evidenceCoverage: evidenceCoverage,
            activeDayCount: activeDayCount,
            agentCount: merged.isEmpty ? nil : activeWorkerIDs.count,
            aiHours: merged.isEmpty ? nil : aiHours,
            autonomousHours: merged.isEmpty ? nil : autonomousHours,
            averageParallelism: merged.isEmpty ? nil : metrics.averageParallelism,
            peakConcurrency: merged.isEmpty ? nil : metrics.peakConcurrency,
            projectCount: Set(merged.map(\.projectID)).count,
            dailyPoints: dayPoints,
            projects: projectContributions
        )
    }

    private func clip(
        _ interval: LeadershipInterval,
        start: Date,
        end: Date
    ) -> LeadershipInterval? {
        let clippedStart = max(interval.startAt, start)
        let clippedEnd = min(interval.endAt, end)
        guard clippedEnd > clippedStart else { return nil }
        return LeadershipInterval(
            id: interval.id,
            workerID: interval.workerID,
            runtime: interval.runtime,
            workerKind: interval.workerKind,
            projectID: interval.projectID,
            startAt: clippedStart,
            endAt: clippedEnd,
            quality: interval.quality,
            isAutonomous: interval.isAutonomous
        )
    }

    private func mergePerWorker(_ intervals: [LeadershipInterval]) -> [LeadershipInterval] {
        Dictionary(grouping: intervals, by: \.workerID).values.flatMap { values in
            let sorted = values.sorted { $0.startAt < $1.startAt }
            var result: [LeadershipInterval] = []
            for interval in sorted {
                guard let previous = result.last, interval.startAt <= previous.endAt else {
                    result.append(interval)
                    continue
                }
                result[result.count - 1] = LeadershipInterval(
                    id: previous.id,
                    workerID: previous.workerID,
                    runtime: previous.runtime,
                    workerKind: previous.workerKind,
                    projectID: previous.projectID,
                    startAt: previous.startAt,
                    endAt: max(previous.endAt, interval.endAt),
                    quality: lowerQuality(previous.quality, interval.quality),
                    isAutonomous: previous.isAutonomous || interval.isAutonomous
                )
            }
            return result
        }
    }

    private func lowerQuality(
        _ lhs: LeadershipEvidenceQuality,
        _ rhs: LeadershipEvidenceQuality
    ) -> LeadershipEvidenceQuality {
        lhs.confidence <= rhs.confidence ? lhs : rhs
    }

    private struct TimelineMetrics {
        let activeWindow: TimeInterval
        let parallelWindow: TimeInterval
        let multiProjectWindow: TimeInterval
        let averageParallelism: Double
        let peakConcurrency: Int
    }

    private struct Boundary {
        let starts: Bool
        let workerID: String
        let projectID: String
    }

    private func timelineMetrics(_ intervals: [LeadershipInterval]) -> TimelineMetrics {
        guard !intervals.isEmpty else {
            return TimelineMetrics(
                activeWindow: 0,
                parallelWindow: 0,
                multiProjectWindow: 0,
                averageParallelism: 0,
                peakConcurrency: 0
            )
        }

        var boundaries: [Date: [Boundary]] = [:]
        for interval in intervals {
            boundaries[interval.startAt, default: []].append(Boundary(
                starts: true,
                workerID: interval.workerID,
                projectID: interval.projectID
            ))
            boundaries[interval.endAt, default: []].append(Boundary(
                starts: false,
                workerID: interval.workerID,
                projectID: interval.projectID
            ))
        }

        let times = boundaries.keys.sorted()
        var active: [String: String] = [:]
        var activeWindow: TimeInterval = 0
        var parallelWindow: TimeInterval = 0
        var multiProjectWindow: TimeInterval = 0
        var peak = 0
        var previous = times.first

        for time in times {
            if let previous {
                let duration = max(0, time.timeIntervalSince(previous))
                if !active.isEmpty { activeWindow += duration }
                if active.count >= 2 { parallelWindow += duration }
                if Set(active.values).count >= 2 { multiProjectWindow += duration }
            }
            let events = boundaries[time] ?? []
            for event in events where !event.starts {
                active.removeValue(forKey: event.workerID)
            }
            for event in events where event.starts {
                active[event.workerID] = event.projectID
            }
            peak = max(peak, active.count)
            previous = time
        }

        let aiDuration = intervals.reduce(0.0) { $0 + $1.duration }
        return TimelineMetrics(
            activeWindow: activeWindow,
            parallelWindow: parallelWindow,
            multiProjectWindow: multiProjectWindow,
            averageParallelism: activeWindow > 0 ? aiDuration / activeWindow : 0,
            peakConcurrency: peak
        )
    }

    private func makeDayPoints(
        intervals: [LeadershipInterval],
        start: Date,
        now: Date,
        calendar: Calendar
    ) -> [LeadershipDayPoint] {
        var points: [LeadershipDayPoint] = []
        var day = calendar.startOfDay(for: start)
        let finalDay = calendar.startOfDay(for: now)
        while day <= finalDay {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 3600)
            let clipped = intervals.compactMap { clip($0, start: day, end: min(nextDay, now)) }
            let metrics = timelineMetrics(clipped)
            points.append(LeadershipDayPoint(
                day: day,
                agentCount: Set(clipped.map(\.workerID)).count,
                aiHours: clipped.reduce(0.0) { $0 + $1.duration } / 3600,
                peakConcurrency: metrics.peakConcurrency
            ))
            guard nextDay > day else { break }
            day = nextDay
        }
        return points
    }

    private func hasAutonomousInterval(
        on day: Date,
        intervals: [LeadershipInterval],
        calendar: Calendar
    ) -> Bool {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(24 * 3600)
        return intervals.contains { $0.isAutonomous && $0.endAt > day && $0.startAt < nextDay }
    }

    private func durationWeightedConfidence(_ intervals: [LeadershipInterval]) -> Double {
        let total = intervals.reduce(0.0) { $0 + $1.duration }
        guard total > 0 else { return 0 }
        return intervals.reduce(0.0) { totalConfidence, interval in
            totalConfidence + interval.duration * interval.quality.confidence
        } / total
    }

    private func makeProjectContributions(
        workers: [LeadershipWorker],
        intervals: [LeadershipInterval]
    ) -> [LeadershipProjectContribution] {
        let workersByID = Dictionary(uniqueKeysWithValues: workers.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: intervals, by: \.projectID)
        return grouped.map { projectID, values in
            let projectName = values.compactMap { workersByID[$0.workerID]?.projectName }.first ?? "未归类"
            return LeadershipProjectContribution(
                projectID: projectID,
                projectName: projectName,
                agentCount: Set(values.map(\.workerID)).count,
                aiHours: values.reduce(0.0) { $0 + $1.duration } / 3600,
                autonomousHours: values.filter(\.isAutonomous).reduce(0.0) { $0 + $1.duration } / 3600
            )
        }.sorted {
            if $0.aiHours != $1.aiHours { return $0.aiHours > $1.aiHours }
            return $0.projectName < $1.projectName
        }
    }
}
