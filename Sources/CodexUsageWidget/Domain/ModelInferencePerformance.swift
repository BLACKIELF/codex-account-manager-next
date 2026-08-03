import Foundation

struct ModelInferenceSample: Equatable, Codable {
    let completedAt: Date
    let durationSeconds: Double
    let outputTokens: Int64
    let reasoningOutputTokens: Int64
    let model: String
    let effort: String
    let eventIdentity: CodexTokenEventIdentity
}

struct ModelInferencePerformanceGroup: Identifiable, Equatable, Codable {
    let id: String
    let model: String
    let effort: String
    let callCount: Int
    let averageDurationSeconds: Double
    let p50DurationSeconds: Double
    let p90DurationSeconds: Double
    let effectiveOutputTokensPerSecond: Double
    let outputTokens: Int64
    let reasoningOutputTokens: Int64
}

struct ModelInferencePerformance: Equatable, Codable {
    let groups: [ModelInferencePerformanceGroup]
    let totalCallCount: Int

    func displayGroups(limit: Int = 6) -> [ModelInferencePerformanceGroup] {
        Array(
            groups.sorted { lhs, rhs in
                if lhs.callCount != rhs.callCount { return lhs.callCount > rhs.callCount }
                if lhs.p50DurationSeconds != rhs.p50DurationSeconds {
                    return lhs.p50DurationSeconds < rhs.p50DurationSeconds
                }
                return lhs.id < rhs.id
            }.prefix(max(limit, 0))
        )
    }
}

struct ModelInferenceCallTracker {
    private var activeModel: String?
    private var activeEffort: String?
    private var callStartedAt: Date?
    private var observedModelOutput = false

    mutating func applyTurnContext(model: String?, effort: String?, at date: Date) {
        activeModel = normalizedValue(model)
        activeEffort = normalizedValue(effort)?.lowercased()
        callStartedAt = date
        observedModelOutput = false
    }

    mutating func applyInputBoundary(at date: Date) {
        if callStartedAt == nil || date > (callStartedAt ?? .distantPast) {
            callStartedAt = date
        }
        observedModelOutput = false
    }

    mutating func observeModelOutput() {
        observedModelOutput = true
    }

    mutating func consumeTokenEvent(
        at completedAt: Date,
        lastUsage: CodexTokenCounterSample?,
        eventIdentity: CodexTokenEventIdentity
    ) -> ModelInferenceSample? {
        defer {
            callStartedAt = completedAt
            observedModelOutput = false
        }

        guard let model = activeModel,
              let effort = activeEffort,
              let startedAt = callStartedAt,
              observedModelOutput,
              completedAt > startedAt,
              let lastUsage,
              !lastUsage.hasNegativeValue
        else { return nil }

        let usage = lastUsage.snapshot()
        guard usage.outputTokens > 0 else { return nil }

        return ModelInferenceSample(
            completedAt: completedAt,
            durationSeconds: completedAt.timeIntervalSince(startedAt),
            outputTokens: usage.outputTokens,
            reasoningOutputTokens: min(max(usage.reasoningOutputTokens, 0), usage.outputTokens),
            model: model,
            effort: effort,
            eventIdentity: eventIdentity
        )
    }

    private func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

enum ModelInferencePerformanceBuilder {
    static func make(
        samples: [ModelInferenceSample],
        dayStart: Date,
        dayEnd: Date
    ) -> ModelInferencePerformance? {
        let todaySamples = samples.filter {
            $0.completedAt >= dayStart
                && $0.completedAt < dayEnd
                && $0.durationSeconds > 0
                && $0.outputTokens > 0
        }
        guard !todaySamples.isEmpty else { return nil }

        let grouped = Dictionary(grouping: todaySamples) { sample in
            modelInferencePerformanceID(model: sample.model, effort: sample.effort)
        }

        let groups = grouped.compactMap { id, values -> ModelInferencePerformanceGroup? in
            guard let first = values.first else { return nil }
            let durations = values.map(\.durationSeconds).sorted()
            let totalDuration = durations.reduce(0, +)
            let outputTokens = values.reduce(Int64(0)) { $0 + $1.outputTokens }
            let reasoningTokens = values.reduce(Int64(0)) { $0 + $1.reasoningOutputTokens }
            guard totalDuration > 0, outputTokens > 0 else { return nil }

            return ModelInferencePerformanceGroup(
                id: id,
                model: first.model,
                effort: first.effort,
                callCount: values.count,
                averageDurationSeconds: totalDuration / Double(values.count),
                p50DurationSeconds: percentile(durations, fraction: 0.5),
                p90DurationSeconds: percentile(durations, fraction: 0.9),
                effectiveOutputTokensPerSecond: Double(outputTokens) / totalDuration,
                outputTokens: outputTokens,
                reasoningOutputTokens: reasoningTokens
            )
        }
        .sorted { lhs, rhs in
            if lhs.callCount != rhs.callCount { return lhs.callCount > rhs.callCount }
            return lhs.id < rhs.id
        }

        guard !groups.isEmpty else { return nil }
        return ModelInferencePerformance(
            groups: groups,
            totalCallCount: groups.reduce(0) { $0 + $1.callCount }
        )
    }

    static func percentile(_ sortedValues: [Double], fraction: Double) -> Double {
        guard let first = sortedValues.first else { return 0 }
        guard sortedValues.count > 1 else { return first }
        let clamped = min(max(fraction, 0), 1)
        let position = Double(sortedValues.count - 1) * clamped
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        guard lowerIndex != upperIndex else { return sortedValues[lowerIndex] }
        let progress = position - Double(lowerIndex)
        return sortedValues[lowerIndex]
            + (sortedValues[upperIndex] - sortedValues[lowerIndex]) * progress
    }
}

func modelInferencePerformanceID(model: String, effort: String) -> String {
    "\(model.lowercased())::\(effort.lowercased())"
}

enum ModelInferencePerformanceSelfTest {
    static func run() -> Bool {
        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        func nearlyEqual(_ lhs: Double, _ rhs: Double, tolerance: Double = 0.000_1) -> Bool {
            abs(lhs - rhs) <= tolerance
        }

        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let usage = CodexTokenCounterSample(
            inputTokens: 100,
            cachedInputTokens: 50,
            outputTokens: 40,
            reasoningOutputTokens: 10,
            totalTokens: 140
        )
        let identity = CodexTokenEventIdentity(cumulative: nil, lastUsage: usage)

        var tracker = ModelInferenceCallTracker()
        tracker.applyTurnContext(model: "gpt-test", effort: "High", at: base)
        tracker.applyInputBoundary(at: base.addingTimeInterval(1))
        tracker.observeModelOutput()
        let first = tracker.consumeTokenEvent(
            at: base.addingTimeInterval(5),
            lastUsage: usage,
            eventIdentity: identity
        )
        expect(nearlyEqual(first?.durationSeconds ?? 0, 4), "turn input should define the first call boundary")
        expect(first?.effort == "high", "effort should be normalized")

        tracker.applyInputBoundary(at: base.addingTimeInterval(20))
        tracker.observeModelOutput()
        let afterTool = tracker.consumeTokenEvent(
            at: base.addingTimeInterval(22),
            lastUsage: usage,
            eventIdentity: identity
        )
        expect(nearlyEqual(afterTool?.durationSeconds ?? 0, 2), "tool output should exclude tool execution time")

        tracker.applyTurnContext(model: "gpt-test", effort: nil, at: base.addingTimeInterval(30))
        tracker.observeModelOutput()
        let missingEffort = tracker.consumeTokenEvent(
            at: base.addingTimeInterval(31),
            lastUsage: usage,
            eventIdentity: identity
        )
        expect(missingEffort == nil, "missing effort must clear previous attribution")

        tracker.applyTurnContext(model: "gpt-test", effort: "high", at: base.addingTimeInterval(40))
        let baselineSnapshot = tracker.consumeTokenEvent(
            at: base.addingTimeInterval(40.001),
            lastUsage: usage,
            eventIdentity: identity
        )
        expect(baselineSnapshot == nil, "token snapshots without new model output must not become calls")

        let durations = [2.0, 4.0, 8.0]
        let samples = durations.enumerated().map { index, duration in
            ModelInferenceSample(
                completedAt: base.addingTimeInterval(Double(index + 1) * 60),
                durationSeconds: duration,
                outputTokens: Int64([20, 40, 80][index]),
                reasoningOutputTokens: Int64([5, 10, 20][index]),
                model: "gpt-test",
                effort: "high",
                eventIdentity: identity
            )
        }
        let performance = ModelInferencePerformanceBuilder.make(
            samples: samples,
            dayStart: base,
            dayEnd: base.addingTimeInterval(24 * 60 * 60)
        )
        let group = performance?.groups.first
        expect(group?.callCount == 3, "samples should aggregate by model and effort")
        expect(nearlyEqual(group?.averageDurationSeconds ?? 0, 14.0 / 3.0), "average duration")
        expect(nearlyEqual(group?.p50DurationSeconds ?? 0, 4), "p50 duration")
        expect(nearlyEqual(group?.p90DurationSeconds ?? 0, 7.2), "interpolated p90 duration")
        expect(nearlyEqual(group?.effectiveOutputTokensPerSecond ?? 0, 10), "effective throughput must use total output over total duration")

        let outside = ModelInferenceSample(
            completedAt: base.addingTimeInterval(-1),
            durationSeconds: 1,
            outputTokens: 10,
            reasoningOutputTokens: 0,
            model: "gpt-other",
            effort: "low",
            eventIdentity: identity
        )
        let filtered = ModelInferencePerformanceBuilder.make(
            samples: samples + [outside],
            dayStart: base,
            dayEnd: base.addingTimeInterval(24 * 60 * 60)
        )
        expect(filtered?.groups.count == 1, "samples outside the selected day must be excluded")

        if failures.isEmpty {
            print("model inference performance self-test passed")
            return true
        }
        failures.forEach { print("model inference performance self-test failed: \($0)") }
        return false
    }
}
