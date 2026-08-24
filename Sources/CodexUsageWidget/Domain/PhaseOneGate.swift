import Foundation

enum PhaseOneCheckStatus: String, Codable, Equatable {
    case pass
    case pending
    case fail
}

enum PhaseOneConclusion: String, Codable, Equatable {
    case pass = "PASS"
    case pending = "PENDING"
    case fail = "FAIL"
}

struct PhaseOneCheck: Codable, Equatable {
    let id: String
    let status: PhaseOneCheckStatus
}

struct PhaseOneGateReport: Codable, Equatable {
    let version: Int
    let generatedAtEpochSeconds: Double
    let conclusion: PhaseOneConclusion
    let checks: [PhaseOneCheck]
}

enum PhaseOneGateEvaluator {
    static func evaluate(_ checks: [PhaseOneCheck]) -> PhaseOneConclusion {
        if checks.contains(where: { $0.status == .fail }) { return .fail }
        if checks.contains(where: { $0.status == .pending }) { return .pending }
        return checks.isEmpty ? .pending : .pass
    }
}

enum PhaseOneGateSelfTest {
    static func run() -> Bool {
        let passing = [PhaseOneCheck(id: "automatic", status: .pass)]
        let pending = passing + [PhaseOneCheck(id: "soak", status: .pending)]
        let failing = pending + [PhaseOneCheck(id: "privacy", status: .fail)]
        let passed = PhaseOneGateEvaluator.evaluate(passing) == .pass
            && PhaseOneGateEvaluator.evaluate(pending) == .pending
            && PhaseOneGateEvaluator.evaluate(failing) == .fail
            && PhaseOneGateEvaluator.evaluate([]) == .pending
        print(passed ? "phase one gate self-test passed" : "phase one gate self-test failed")
        return passed
    }
}

enum PhaseOneGateCommand {
    static func run(arguments: [String]) -> Int32 {
        guard let commandIndex = arguments.firstIndex(of: "--evaluate-phase-one-gate") else { return 64 }
        var checks: [PhaseOneCheck] = []
        var outputURL: URL?
        var index = commandIndex + 1
        while index < arguments.count {
            if arguments[index] == "--output", arguments.indices.contains(index + 1) {
                outputURL = URL(fileURLWithPath: arguments[index + 1])
                index += 2
                continue
            }
            let components = arguments[index].split(separator: "=", maxSplits: 1).map(String.init)
            if components.count == 2, let status = PhaseOneCheckStatus(rawValue: components[1]) {
                checks.append(PhaseOneCheck(id: components[0], status: status))
            } else {
                return 64
            }
            index += 1
        }

        guard let outputURL else { return 64 }
        let report = PhaseOneGateReport(
            version: 1,
            generatedAtEpochSeconds: Date().timeIntervalSince1970,
            conclusion: PhaseOneGateEvaluator.evaluate(checks),
            checks: checks
        )
        do {
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: outputURL, options: .atomic)
            print(report.conclusion.rawValue)
            switch report.conclusion {
            case .pass: return 0
            case .pending: return 2
            case .fail: return 1
            }
        } catch {
            return 74
        }
    }
}
