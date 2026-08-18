import Foundation

enum PerformanceMonitorSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexu-performance-\(UUID().uuidString)", isDirectory: true)
        let reportURL = directory.appendingPathComponent("report.json")
        let monitor = PerformanceMonitor(
            reportURL: reportURL,
            maximumOperationSamples: 256,
            maximumResourceSamples: 8,
            recordsMetrics: true
        )

        for index in 0..<300 {
            let span = monitor.begin(.fullRefresh)
            monitor.end(span, success: index % 10 != 0)
        }
        for index in 0..<12 {
            monitor.recordResourceSample(windowVisible: index.isMultiple(of: 2))
        }
        monitor.flush()

        let report = monitor.snapshot()
        let refresh = report.operations[PerformanceOperation.fullRefresh.rawValue]
        expect(refresh?.count == 300, "operation count should retain all observations")
        expect(refresh?.samplesMilliseconds.count == 256, "operation samples should be bounded")
        expect(refresh?.failureCount == 30, "failure count should retain all recorded failures")
        expect((refresh?.p95Milliseconds ?? -1) >= 0, "p95 should be available")
        expect(report.resources.count == 8, "resource samples should be bounded")
        expect(FileManager.default.fileExists(atPath: reportURL.path), "report should be persisted")

        let restoredMonitor = PerformanceMonitor(
            reportURL: reportURL,
            maximumOperationSamples: 256,
            maximumResourceSamples: 8,
            recordsMetrics: true
        )
        let restored = restoredMonitor.snapshot()
        expect(restored.operations[PerformanceOperation.fullRefresh.rawValue]?.count == 300, "persisted counters should survive restart")
        expect(restored.operations[PerformanceOperation.fullRefresh.rawValue]?.samplesMilliseconds.count == 256, "restored samples should remain bounded")
        expect(restored.resources.count == 8, "restored resources should remain bounded")

        let text = (try? String(contentsOf: reportURL, encoding: .utf8)) ?? ""
        for forbidden in ["command", "prompt", "approval", "reason", "threadId", "path"] {
            expect(!text.localizedCaseInsensitiveContains(forbidden), "report must not contain \(forbidden)")
        }

        try? FileManager.default.removeItem(at: directory)
        if failures.isEmpty {
            print("performance monitor self-test passed")
            return true
        }
        failures.forEach { print("performance monitor self-test failed: \($0)") }
        return false
    }
}
