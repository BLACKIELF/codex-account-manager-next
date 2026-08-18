import Foundation

final class MultiRuntimeUsageReader {
    private let registry: RuntimeProviderRegistry

    init(registry: RuntimeProviderRegistry = RuntimeProviderRegistry()) {
        self.registry = registry
    }

    func load(
        statisticsPreference: StatisticsTimeZonePreference = .default,
        generation: UInt64 = 0,
        codexHomeDirectory: URL? = nil
    ) -> MultiRuntimeUsageSnapshot {
        let span = PerformanceMonitor.shared.begin(.runtimeLoad)
        let context = RuntimeLoadContext.live(
            statisticsPreference: statisticsPreference,
            codexHomeDirectory: codexHomeDirectory
        )
        let runtimeSnapshots = registry.providers.map { provider in
            provider.loadSnapshot(context: context)
        }
        let refreshedAt = Date()
        let aggregate = runtimeSnapshots.first?.snapshot ?? .empty
        let snapshot = MultiRuntimeUsageSnapshot(
            refreshedAt: refreshedAt,
            runtimes: runtimeSnapshots,
            aggregate: aggregate,
            leadership: .empty,
            statisticsIdentity: StatisticsIdentity(
                preference: context.statistics.preference,
                resolvedIdentifier: context.statistics.resolvedIdentifier,
                generation: generation,
                now: context.now
            )
        )
        PerformanceMonitor.shared.end(span)
        return snapshot
    }

    func loadTaskBoard(
        scope: RuntimeScope,
        statisticsPreference: StatisticsTimeZonePreference = .default
    ) -> TaskBoard? {
        let span = PerformanceMonitor.shared.begin(.taskLoad)
        let context = RuntimeLoadContext.live(statisticsPreference: statisticsPreference)
        let board = registry.provider(for: scope)?.loadTaskBoard(context: context)
        PerformanceMonitor.shared.end(span, success: board != nil)
        return board
    }
}
