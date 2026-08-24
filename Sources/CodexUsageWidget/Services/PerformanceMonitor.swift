import Darwin
import Foundation
import os.log

enum PerformanceOperation: String, CaseIterable, Codable {
    case appStartup
    case fullRefresh
    case taskRefresh
    case runtimeLoad
    case taskLoad
    case appServerQuota
    case appServerTasks
    case sqliteRead
    case statePublish
    case statusRender
}

struct PerformanceSpan {
    fileprivate let operation: PerformanceOperation
    fileprivate let startedAt: UInt64
    fileprivate let signpostID: OSSignpostID
}

struct PerformanceOperationSummary: Codable, Equatable {
    let count: Int
    let failureCount: Int
    let p50Milliseconds: Double
    let p95Milliseconds: Double
    let maximumMilliseconds: Double
    let samplesMilliseconds: [Double]
}

struct PerformanceResourceSample: Codable, Equatable {
    let capturedAtEpochSeconds: Double
    let residentBytes: UInt64
    let cpuTimeMilliseconds: Double
    let windowVisible: Bool
}

struct PerformanceReport: Codable, Equatable {
    let version: Int
    let updatedAtEpochSeconds: Double
    let operations: [String: PerformanceOperationSummary]
    let resources: [PerformanceResourceSample]
}

final class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private struct MutableOperationSummary {
        var count = 0
        var failureCount = 0
        var samples: [Double] = []

        init(count: Int = 0, failureCount: Int = 0, samples: [Double] = []) {
            self.count = count
            self.failureCount = failureCount
            self.samples = samples
        }
    }

    private static let log = OSLog(subsystem: "com.blackielf.codex-account-manager-next", category: "performance")
    private let queue = DispatchQueue(label: "com.blackielf.codex-account-manager-next.performance", qos: .utility)
    private let reportURL: URL
    private let maximumOperationSamples: Int
    private let maximumResourceSamples: Int
    private let recordsMetrics: Bool
    private var summaries: [PerformanceOperation: MutableOperationSummary] = [:]
    private var resources: [PerformanceResourceSample] = []
    private var pendingWrite: DispatchWorkItem?

    init(
        reportURL: URL? = nil,
        maximumOperationSamples: Int = 256,
        maximumResourceSamples: Int = 128,
        recordsMetrics: Bool = false
    ) {
        self.maximumOperationSamples = maximumOperationSamples
        self.maximumResourceSamples = maximumResourceSamples
        self.recordsMetrics = recordsMetrics
        self.reportURL = reportURL ?? FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
            .appendingPathComponent("CodexAccountManagerNext", isDirectory: true)
            .appendingPathComponent("performance-v1.json")

        if recordsMetrics,
           let data = try? Data(contentsOf: self.reportURL),
           let report = try? JSONDecoder().decode(PerformanceReport.self, from: data),
           report.version == 1 {
            for operation in PerformanceOperation.allCases {
                guard let persisted = report.operations[operation.rawValue] else { continue }
                summaries[operation] = MutableOperationSummary(
                    count: persisted.count,
                    failureCount: persisted.failureCount,
                    samples: Array(persisted.samplesMilliseconds.suffix(maximumOperationSamples))
                )
            }
            resources = Array(report.resources.suffix(maximumResourceSamples))
        }
    }

    func begin(_ operation: PerformanceOperation) -> PerformanceSpan {
        let signpostID = OSSignpostID(log: Self.log)
        os_signpost(
            .begin,
            log: Self.log,
            name: "Codex Account Manager Next operation",
            signpostID: signpostID,
            "%{public}s",
            operation.rawValue
        )
        return PerformanceSpan(
            operation: operation,
            startedAt: DispatchTime.now().uptimeNanoseconds,
            signpostID: signpostID
        )
    }

    func end(_ span: PerformanceSpan, success: Bool = true) {
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - span.startedAt) / 1_000_000
        os_signpost(
            .end,
            log: Self.log,
            name: "Codex Account Manager Next operation",
            signpostID: span.signpostID,
            "%{public}s %{public}s",
            span.operation.rawValue,
            success ? "success" : "failure"
        )
        guard recordsMetrics else { return }
        queue.async {
            var summary = self.summaries[span.operation] ?? MutableOperationSummary()
            summary.count += 1
            summary.samples.append(elapsed)
            if summary.samples.count > self.maximumOperationSamples {
                summary.samples.removeFirst(summary.samples.count - self.maximumOperationSamples)
            }
            if !success { summary.failureCount += 1 }
            self.summaries[span.operation] = summary
            self.scheduleWrite()
        }
    }

    func recordResourceSample(windowVisible: Bool) {
        guard recordsMetrics else { return }
        let sample = PerformanceResourceSample(
            capturedAtEpochSeconds: Date().timeIntervalSince1970,
            residentBytes: Self.residentBytes(),
            cpuTimeMilliseconds: Self.cpuTimeMilliseconds(),
            windowVisible: windowVisible
        )
        queue.async {
            self.resources.append(sample)
            if self.resources.count > self.maximumResourceSamples {
                self.resources.removeFirst(self.resources.count - self.maximumResourceSamples)
            }
            self.scheduleWrite()
        }
    }

    func flush() {
        guard recordsMetrics else { return }
        queue.sync {
            pendingWrite?.cancel()
            pendingWrite = nil
            writeReport()
        }
    }

    func snapshot() -> PerformanceReport {
        queue.sync { makeReport() }
    }

    private func scheduleWrite() {
        pendingWrite?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingWrite = nil
            self?.writeReport()
        }
        pendingWrite = work
        queue.asyncAfter(deadline: .now() + 30, execute: work)
    }

    private func writeReport() {
        let directory = reportURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(makeReport()).write(to: reportURL, options: .atomic)
        } catch {
            // Performance telemetry must never affect the product path.
        }
    }

    private func makeReport() -> PerformanceReport {
        let operations = Dictionary(uniqueKeysWithValues: summaries.map { operation, mutable in
            let sorted = mutable.samples.sorted()
            return (
                operation.rawValue,
                PerformanceOperationSummary(
                    count: mutable.count,
                    failureCount: mutable.failureCount,
                    p50Milliseconds: Self.percentile(sorted, fraction: 0.50),
                    p95Milliseconds: Self.percentile(sorted, fraction: 0.95),
                    maximumMilliseconds: sorted.last ?? 0,
                    samplesMilliseconds: mutable.samples
                )
            )
        })
        return PerformanceReport(
            version: 1,
            updatedAtEpochSeconds: Date().timeIntervalSince1970,
            operations: operations,
            resources: resources
        )
    }

    private static func percentile(_ sorted: [Double], fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = Int(ceil(Double(sorted.count) * fraction)) - 1
        return sorted[max(0, min(index, sorted.count - 1))]
    }

    private static func residentBytes() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.resident_size) : 0
    }

    private static func cpuTimeMilliseconds() -> Double {
        var usage = rusage()
        guard getrusage(RUSAGE_SELF, &usage) == 0 else { return 0 }
        let user = Double(usage.ru_utime.tv_sec) * 1_000 + Double(usage.ru_utime.tv_usec) / 1_000
        let system = Double(usage.ru_stime.tv_sec) * 1_000 + Double(usage.ru_stime.tv_usec) / 1_000
        return user + system
    }
}
