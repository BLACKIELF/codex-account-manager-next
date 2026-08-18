import Foundation

struct CCSwitchUsageSummary: Equatable {
    let requestCount: Int64
    let freshInputTokens: Int64
    let outputTokens: Int64
    let cacheReadTokens: Int64
    let cacheCreationTokens: Int64
    let realTotalTokens: Int64
    let todayTokens: Int64
    let sevenDayTokens: Int64
    let schemaVersion: Int
    let recordedAt: Date?

    var localUsage: LocalUsage {
        let lifetime = TokenBreakdown(
            inputTokens: freshInputTokens + cacheReadTokens + cacheCreationTokens,
            cachedInputTokens: cacheReadTokens,
            cacheWriteInputTokens: cacheCreationTokens,
            outputTokens: outputTokens,
            reasoningOutputTokens: 0,
            totalTokens: realTotalTokens
        )
        func totalOnly(_ value: Int64) -> PricedTokenUsage {
            PricedTokenUsage(
                tokens: TokenBreakdown(
                    inputTokens: 0,
                    cachedInputTokens: 0,
                    outputTokens: 0,
                    reasoningOutputTokens: 0,
                    totalTokens: value
                ),
                estimatedCostUSD: 0
            )
        }
        return LocalUsage(
            lifetimeTokens: realTotalTokens,
            todayTokens: todayTokens,
            sevenDayTokens: sevenDayTokens,
            threadCount: 0,
            lastUpdatedAt: recordedAt,
            dailyBuckets: [],
            recentThreads: [],
            detailedUsage: DetailedUsage(
                today: totalOnly(todayTokens),
                sevenDay: totalOnly(sevenDayTokens),
                month: .zero,
                lifetime: PricedTokenUsage(tokens: lifetime, estimatedCostUSD: 0),
                parsedFileCount: 0,
                tokenEventCount: 0
            ),
            usageTrend: nil,
            inferencePerformance: nil,
            projectBoard: nil,
            toolUsages: [],
            skillUsages: []
        )
    }
}

enum CCSwitchUsageError: LocalizedError, Equatable {
    case databaseMissing
    case sqliteMissing
    case unsupportedSchema(Int)
    case incompatibleSchema
    case overlappingSources
    case queryFailed

    var errorDescription: String? {
        switch self {
        case .databaseMissing:
            return "未找到本机历史数据"
        case .sqliteMissing:
            return "未找到系统 sqlite3"
        case let .unsupportedSchema(version):
            return "本机历史数据版本为 \(version)，当前暂不支持"
        case .incompatibleSchema:
            return "本机历史数据格式不兼容"
        case .overlappingSources:
            return "本机历史明细发生重叠，已停止估算以避免重复统计"
        case .queryFailed:
            return "本机历史统计失败"
        }
    }
}

final class CCSwitchUsageReader {
    static let supportedSchemaVersion = 16

    private let databaseURL: URL
    private let sqliteURL: URL?

    init(databaseURL: URL? = nil, sqliteURL: URL? = nil) {
        let environment = ProcessInfo.processInfo.environment
        self.databaseURL = databaseURL
            ?? environment["CODEXU_CC_SWITCH_DB_OVERRIDE"].map(URL.init(fileURLWithPath:))
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".cc-switch/cc-switch.db")
        if let sqliteURL {
            self.sqliteURL = sqliteURL
        } else {
            self.sqliteURL = ["/usr/bin/sqlite3", "/opt/homebrew/bin/sqlite3"]
                .map(URL.init(fileURLWithPath:))
                .first { FileManager.default.isExecutableFile(atPath: $0.path) }
        }
    }

    func load(context: RuntimeLoadContext) -> Result<CCSwitchUsageSummary, CCSwitchUsageError> {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return .failure(.databaseMissing)
        }
        guard sqliteURL != nil else { return .failure(.sqliteMissing) }

        guard let schema = try? query(schemaQuery).first,
              let version = int(schema["user_version"])
        else { return .failure(.queryFailed) }
        guard version == Self.supportedSchemaVersion else {
            return .failure(.unsupportedSchema(version))
        }
        guard int(schema["log_columns"]) == 10,
              int(schema["rollup_columns"]) == 9
        else { return .failure(.incompatibleSchema) }

        let calendar = context.statistics.calendar
        let todayStart = calendar.startOfDay(for: context.now)
        let sevenDayStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let queryText = summaryQuery(
            todayEpoch: Int64(todayStart.timeIntervalSince1970),
            sevenDayEpoch: Int64(sevenDayStart.timeIntervalSince1970),
            todayKey: formatter.string(from: todayStart),
            sevenDayKey: formatter.string(from: sevenDayStart)
        )
        guard let row = try? query(queryText).first else { return .failure(.queryFailed) }
        guard int(row["overlap_days"]) == 0 else { return .failure(.overlappingSources) }
        let detailRecordAt = int64(row["latest_created_at"])
            .flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil }
        let rollupRecordAt = (row["latest_rollup_date"] as? String).flatMap(formatter.date(from:))
        return .success(CCSwitchUsageSummary(
            requestCount: int64(row["request_count"]) ?? 0,
            freshInputTokens: int64(row["fresh_input_tokens"]) ?? 0,
            outputTokens: int64(row["output_tokens"]) ?? 0,
            cacheReadTokens: int64(row["cache_read_tokens"]) ?? 0,
            cacheCreationTokens: int64(row["cache_creation_tokens"]) ?? 0,
            realTotalTokens: int64(row["real_total_tokens"]) ?? 0,
            todayTokens: int64(row["today_tokens"]) ?? 0,
            sevenDayTokens: int64(row["seven_day_tokens"]) ?? 0,
            schemaVersion: version,
            recordedAt: [detailRecordAt, rollupRecordAt].compactMap { $0 }.max()
        ))
    }

    private var schemaQuery: String {
        """
        SELECT
          (SELECT user_version FROM pragma_user_version) AS user_version,
          (SELECT COUNT(*) FROM pragma_table_info('proxy_request_logs')
           WHERE name IN ('app_type','model','input_tokens','output_tokens','cache_read_tokens',
                          'cache_creation_tokens','input_token_semantics','data_source','status_code','created_at')) AS log_columns,
          (SELECT COUNT(*) FROM pragma_table_info('usage_daily_rollups')
           WHERE name IN ('date','app_type','request_count','success_count','input_tokens','output_tokens',
                          'cache_read_tokens','cache_creation_tokens','input_token_semantics')) AS rollup_columns;
        """
    }

    private func summaryQuery(
        todayEpoch: Int64,
        sevenDayEpoch: Int64,
        todayKey: String,
        sevenDayKey: String
    ) -> String {
        """
        WITH effective_detail AS (
          SELECT 1 AS request_count,
            CASE
              WHEN l.input_token_semantics = 2 THEN l.input_tokens
              WHEN l.app_type IN ('codex','gemini','grokbuild')
                AND l.input_token_semantics = 1
                AND l.input_tokens >= l.cache_read_tokens + l.cache_creation_tokens
                THEN l.input_tokens - l.cache_read_tokens - l.cache_creation_tokens
              WHEN l.app_type IN ('codex','gemini','grokbuild')
                AND l.input_token_semantics = 0
                AND l.input_tokens >= l.cache_read_tokens
                THEN l.input_tokens - l.cache_read_tokens
              ELSE l.input_tokens
            END AS fresh_input,
            l.output_tokens, l.cache_read_tokens, l.cache_creation_tokens,
            l.created_at, NULL AS rollup_date
          FROM proxy_request_logs l
          WHERE l.app_type = 'codex'
            AND NOT (
              COALESCE(l.data_source, 'proxy') IN ('session_log','codex_session','gemini_session','opencode_session')
              AND EXISTS (
                SELECT 1 FROM proxy_request_logs proxy_dedup
                WHERE COALESCE(proxy_dedup.data_source, 'proxy') = 'proxy'
                  AND proxy_dedup.app_type IN (
                    l.app_type,
                    CASE WHEN l.app_type = 'claude' THEN 'claude-desktop' ELSE l.app_type END
                  )
                  AND proxy_dedup.status_code >= 200 AND proxy_dedup.status_code < 300
                  AND proxy_dedup.input_tokens = l.input_tokens
                  AND proxy_dedup.output_tokens = l.output_tokens
                  AND proxy_dedup.cache_read_tokens = l.cache_read_tokens
                  AND (
                    proxy_dedup.cache_creation_tokens = l.cache_creation_tokens
                    OR (
                      l.cache_creation_tokens = 0
                      AND COALESCE(l.data_source, 'proxy') IN ('codex_session','gemini_session','opencode_session')
                    )
                  )
                  AND proxy_dedup.created_at BETWEEN l.created_at - 600 AND l.created_at + 600
                  AND (
                    LOWER(proxy_dedup.model) = LOWER(l.model)
                    OR LOWER(proxy_dedup.model) = 'unknown'
                    OR LOWER(l.model) = 'unknown'
                  )
              )
            )
        ), rollups AS (
          SELECT r.request_count,
            CASE
              WHEN r.input_token_semantics = 2 THEN r.input_tokens
              WHEN r.app_type IN ('codex','gemini','grokbuild')
                AND r.input_token_semantics = 1
                AND r.input_tokens >= r.cache_read_tokens + r.cache_creation_tokens
                THEN r.input_tokens - r.cache_read_tokens - r.cache_creation_tokens
              WHEN r.app_type IN ('codex','gemini','grokbuild')
                AND r.input_token_semantics = 0
                AND r.input_tokens >= r.cache_read_tokens
                THEN r.input_tokens - r.cache_read_tokens
              ELSE r.input_tokens
            END AS fresh_input,
            r.output_tokens, r.cache_read_tokens, r.cache_creation_tokens,
            NULL AS created_at, r.date AS rollup_date
          FROM usage_daily_rollups r
          WHERE r.app_type = 'codex'
        ), combined AS (
          SELECT * FROM effective_detail
          UNION ALL
          SELECT * FROM rollups
        )
        SELECT
          COALESCE(SUM(request_count), 0) AS request_count,
          COALESCE(SUM(fresh_input), 0) AS fresh_input_tokens,
          COALESCE(SUM(output_tokens), 0) AS output_tokens,
          COALESCE(SUM(cache_read_tokens), 0) AS cache_read_tokens,
          COALESCE(SUM(cache_creation_tokens), 0) AS cache_creation_tokens,
          COALESCE(SUM(fresh_input + output_tokens + cache_read_tokens + cache_creation_tokens), 0) AS real_total_tokens,
          COALESCE(SUM(CASE WHEN created_at >= \(todayEpoch) OR rollup_date >= '\(todayKey)'
            THEN fresh_input + output_tokens + cache_read_tokens + cache_creation_tokens ELSE 0 END), 0) AS today_tokens,
          COALESCE(SUM(CASE WHEN created_at >= \(sevenDayEpoch) OR rollup_date >= '\(sevenDayKey)'
            THEN fresh_input + output_tokens + cache_read_tokens + cache_creation_tokens ELSE 0 END), 0) AS seven_day_tokens,
          MAX(created_at) AS latest_created_at,
          MAX(rollup_date) AS latest_rollup_date,
          (SELECT COUNT(*) FROM (
            SELECT DISTINCT date(l.created_at, 'unixepoch', 'localtime') AS day
            FROM proxy_request_logs l
            WHERE l.app_type = 'codex'
            INTERSECT
            SELECT DISTINCT r.date AS day
            FROM usage_daily_rollups r
            WHERE r.app_type = 'codex'
          )) AS overlap_days
        FROM combined;
        """
    }

    private func query(_ sql: String) throws -> [[String: Any]] {
        guard let sqliteURL else { throw CCSwitchUsageError.sqliteMissing }
        let process = Process()
        let output = Pipe()
        process.executableURL = sqliteURL
        process.arguments = ["-readonly", "-json", databaseURL.path, sql]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        try process.run()
        let maximumOutputBytes = 1 * 1_024 * 1_024
        let data = try output.fileHandleForReading.read(upToCount: maximumOutputBytes + 1) ?? Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0, data.count <= maximumOutputBytes else {
            throw CCSwitchUsageError.queryFailed
        }
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }

    private func int(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private func int64(_ value: Any?) -> Int64? {
        (value as? NSNumber)?.int64Value
    }
}

enum CCSwitchUsageReaderSelfTest {
    static func run() -> Bool {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("cc-switch-reader-\(UUID().uuidString)", isDirectory: true)
        let database = directory.appendingPathComponent("fixture.db")
        defer { try? fileManager.removeItem(at: directory) }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try createFixture(at: database)
            let context = RuntimeLoadContext.live(now: Date())
            guard case let .success(summary) = CCSwitchUsageReader(databaseURL: database).load(context: context),
                  summary.requestCount == 5,
                  summary.realTotalTokens == 1_397,
                  summary.todayTokens == 1_167,
                  summary.sevenDayTokens == 1_397,
                  summary.recordedAt.map({ abs($0.timeIntervalSince(context.now)) < 2 }) == true
            else {
                print("CC Switch reader self-test failed: unexpected summary")
                return false
            }
            let today = Self.dayKey(for: context.now)
            try execute(database: database, sql: "INSERT INTO usage_daily_rollups VALUES ('\(today)','codex',1,1,1,1,0,0,2);")
            guard case .failure(.overlappingSources) = CCSwitchUsageReader(databaseURL: database).load(context: context) else {
                print("CC Switch reader self-test failed: overlapping sources gate")
                return false
            }
            try execute(database: database, sql: "PRAGMA user_version=17;")
            guard case .failure(.unsupportedSchema(17)) = CCSwitchUsageReader(databaseURL: database).load(context: context) else {
                print("CC Switch reader self-test failed: schema gate")
                return false
            }
            print("CC Switch reader self-test passed")
            return true
        } catch {
            print("CC Switch reader self-test failed: \(error)")
            return false
        }
    }

    private static func createFixture(at database: URL) throws {
        let now = Int64(Date().timeIntervalSince1970)
        let key = dayKey(for: Date().addingTimeInterval(-24 * 60 * 60))
        try execute(database: database, sql: """
        PRAGMA user_version=16;
        CREATE TABLE proxy_request_logs (
          request_id TEXT PRIMARY KEY, app_type TEXT, model TEXT, input_tokens INTEGER,
          output_tokens INTEGER, cache_read_tokens INTEGER, cache_creation_tokens INTEGER,
          input_token_semantics INTEGER, data_source TEXT, status_code INTEGER, created_at INTEGER
        );
        CREATE TABLE usage_daily_rollups (
          date TEXT, app_type TEXT, request_count INTEGER, success_count INTEGER,
          input_tokens INTEGER, output_tokens INTEGER, cache_read_tokens INTEGER,
          cache_creation_tokens INTEGER, input_token_semantics INTEGER
        );
        INSERT INTO proxy_request_logs VALUES
          ('proxy','codex','gpt-test',1000,100,600,0,1,'proxy',200,\(now)),
          ('duplicate','codex','gpt-test',1000,100,600,0,1,'codex_session',200,\(now)),
          ('fresh','codex','gpt-fresh',50,10,5,2,2,'codex_session',200,\(now));
        INSERT INTO usage_daily_rollups VALUES ('\(key)','codex',3,3,200,30,20,0,0);
        """)
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func execute(database: URL, sql: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [database.path, sql]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CCSwitchUsageError.queryFailed }
    }
}
