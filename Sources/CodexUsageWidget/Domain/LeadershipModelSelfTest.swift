import Foundation

enum LeadershipModelSelfTest {
    static func run() -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = date("2026-07-21T18:00:00Z")
        let day = calendar.startOfDay(for: now)

        let oneDayDimensions = LeadershipDimensionKind.allCases.map {
            LeadershipDimension(kind: $0, score: 100, confidence: 1, summaryValue: 1)
        }
        let oneDayScore = LeadershipScoreModel.finalScore(
            dimensions: oneDayDimensions,
            activeDays: 1,
            evidenceCoverage: 1
        )?.score
        let matureScore = LeadershipScoreModel.finalScore(
            dimensions: oneDayDimensions,
            activeDays: 28,
            evidenceCoverage: 1
        )?.score

        let titleCases = [
            (19, "碳基牛马"), (20, "赛博监工"),
            (34, "赛博监工"), (35, "分身队长"),
            (64, "硅基领主"), (65, "硅基统帅"),
            (79, "硅基统帅"), (80, "超级个体"),
            (92, "超级个体"), (93, "人类最强者"),
            (99, "人类最强者"), (100, "人类最强者")
        ].allSatisfy { LeadershipScoreModel.title(for: $0.0).name == $0.1 }
        let englishTitleCases = [
            (1, "Carbon Laborer"), (2, "Cyber Overseer"),
            (3, "Clone Captain"), (4, "Silicon Lord"),
            (5, "Silicon Marshal"), (6, "Super Individual"),
            (7, "Humanity's Apex")
        ].allSatisfy { item in
            let (level, name) = item
            let score = [0, 20, 35, 50, 65, 80, 93][level - 1]
            return LeadershipScoreModel.title(for: score).englishName == name
        }
        let topRankIsUnified = [93, 99, 100].allSatisfy {
            let title = LeadershipScoreModel.title(for: $0)
            return title.level == 7 && title.lowerBound == 93 && title.upperBound == 100
        }

        let workers = [
            worker("a", project: "p1", kind: .main),
            worker("b", project: "p1", kind: .subagent),
            worker("c", project: "p2", kind: .automation),
            worker("ignored", project: "p3", kind: .main)
        ]
        let intervals = [
            interval("a1", worker: workers[0], start: day.addingTimeInterval(9 * 3600), end: day.addingTimeInterval(10 * 3600)),
            interval("a2", worker: workers[0], start: day.addingTimeInterval(9.75 * 3600), end: day.addingTimeInterval(10.25 * 3600)),
            interval("b1", worker: workers[1], start: day.addingTimeInterval(9.5 * 3600), end: day.addingTimeInterval(10.5 * 3600), autonomous: true),
            interval("c1", worker: workers[2], start: day.addingTimeInterval(15 * 3600), end: day.addingTimeInterval(16 * 3600), autonomous: true),
            interval("e1", worker: workers[3], start: day.addingTimeInterval(8 * 3600), end: day.addingTimeInterval(17 * 3600), quality: .estimated)
        ]
        let dashboard = LeadershipAggregator().makeDashboard(
            workers: workers,
            intervals: intervals,
            now: now,
            calendar: calendar
        )
        let today = dashboard.todayReport
        let hoursCorrect = abs((today?.aiHours ?? 0) - 3.25) < 0.001
        let concurrencyCorrect = today?.peakConcurrency == 2
        let agentCountCorrect = today?.agentCount == 3
        let estimatedExcluded = today?.projects.contains(where: { $0.projectID == "p3" }) == false
        let autonomyPositive = (today?.dimensions.first { $0.kind == .autonomy }?.score ?? 0) > 0

        let rootOnlyDashboard = LeadershipAggregator().makeDashboard(
            workers: [workers[0]],
            intervals: [intervals[0]],
            now: now,
            calendar: calendar
        )
        let rootAutonomy = rootOnlyDashboard.todayReport?.dimensions.first { $0.kind == .autonomy }?.score
        let confidenceSeparate = today?.evidenceCoverage == 1
            && LeadershipScoreModel.finalScore(
                dimensions: oneDayDimensions,
                activeDays: 1,
                evidenceCoverage: 0.69
            ) == nil
        let commandRadiusHandlesMissingRank = LeadershipCommandRadiusLayout.ringCount(for: 0) == 0
            && LeadershipCommandRadiusLayout.visibleNodeCount(agentCount: 1, ringCount: 0) == 0
            && LeadershipCommandRadiusLayout.visibleNodeCount(agentCount: 12, ringCount: 3) == 12
            && LeadershipCommandRadiusLayout.visibleNodeCount(agentCount: 13, ringCount: 3) == 12

        let passed = oneDayScore != nil
            && oneDayScore! <= 33
            && matureScore == 100
            && titleCases
            && englishTitleCases
            && topRankIsUnified
            && hoursCorrect
            && concurrencyCorrect
            && agentCountCorrect
            && estimatedExcluded
            && autonomyPositive
            && rootAutonomy == 0
            && confidenceSeparate
            && commandRadiusHandlesMissingRank
        print(passed ? "leadership model self-test passed" : "leadership model self-test failed")
        return passed
    }

    private static func worker(
        _ id: String,
        project: String,
        kind: LeadershipWorkerKind
    ) -> LeadershipWorker {
        LeadershipWorker(
            id: id,
            runtime: .codex,
            kind: kind,
            projectID: project,
            projectName: project,
            parentID: kind == .subagent ? "a" : nil
        )
    }

    private static func interval(
        _ id: String,
        worker: LeadershipWorker,
        start: Date,
        end: Date,
        quality: LeadershipEvidenceQuality = .fact,
        autonomous: Bool = false
    ) -> LeadershipInterval {
        LeadershipInterval(
            id: id,
            workerID: worker.id,
            runtime: worker.runtime,
            workerKind: worker.kind,
            projectID: worker.projectID,
            startAt: start,
            endAt: end,
            quality: quality,
            isAutonomous: autonomous
        )
    }

    private static func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
