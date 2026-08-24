import Foundation

struct AgentTokenShare: Equatable, Identifiable {
    let name: String
    let tokens: Int64
    var manual: Bool = false

    var id: String { "\(manual ? "manual" : "agent"):\(name)" }
}

func replacingGrokSessionShare(
    in shares: [AgentTokenShare],
    with grokTokens: Int64?
) -> [AgentTokenShare] {
    guard let grokTokens, grokTokens > 0 else { return shares }
    var result = shares
    result.removeAll { ["grok", "grokbuild"].contains($0.name.lowercased()) }
    result.append(AgentTokenShare(name: "Grok", tokens: grokTokens))
    return result
}

func customTokenCount(fromWanText text: String) -> Int64? {
    guard let wan = Double(text.replacingOccurrences(of: ",", with: ".")),
          wan.isFinite,
          wan > 0,
          wan <= Double(Int64.max) / 10_000
    else { return nil }
    return Int64(wan * 10_000)
}

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
    let allAgentsRealTotalTokens: Int64
    var allAgentsTodayTokens: Int64 = 0
    var allAgentsShares: [AgentTokenShare] = []

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
            skillUsages: [],
            allAgentsLifetimeTokens: allAgentsRealTotalTokens,
            allAgentsTodayTokens: allAgentsTodayTokens,
            allAgentsShares: allAgentsShares
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
            ?? environment["CAMNEXT_CC_SWITCH_DB_OVERRIDE"].map(URL.init(fileURLWithPath:))
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
        guard let allAgentsRows = try? query(allAgentsQuery(
            todayEpoch: Int64(todayStart.timeIntervalSince1970),
            todayKey: formatter.string(from: todayStart)
        )) else { return .failure(.queryFailed) }
        let allAgentsShares = allAgentsRows.compactMap { shareRow -> AgentTokenShare? in
            guard let name = shareRow["agent"] as? String else { return nil }
            return AgentTokenShare(name: name, tokens: int64(shareRow["real_total"]) ?? 0)
        }
        let allAgentsToday = allAgentsRows.reduce(Int64(0)) { $0 + (int64($1["today_total"]) ?? 0) }
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
            recordedAt: [detailRecordAt, rollupRecordAt].compactMap { $0 }.max(),
            allAgentsRealTotalTokens: allAgentsShares.reduce(Int64(0)) { $0 + $1.tokens },
            allAgentsTodayTokens: allAgentsToday,
            allAgentsShares: allAgentsShares.sorted { $0.tokens > $1.tokens }
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

    private static func freshInputCase(alias: String) -> String {
        """
        CASE
          WHEN \(alias).input_token_semantics = 2 THEN \(alias).input_tokens
          WHEN \(alias).app_type IN ('codex','gemini','grokbuild')
            AND \(alias).input_token_semantics = 1
            AND \(alias).input_tokens >= \(alias).cache_read_tokens + \(alias).cache_creation_tokens
            THEN \(alias).input_tokens - \(alias).cache_read_tokens - \(alias).cache_creation_tokens
          WHEN \(alias).app_type IN ('codex','gemini','grokbuild')
            AND \(alias).input_token_semantics = 0
            AND \(alias).input_tokens >= \(alias).cache_read_tokens
            THEN \(alias).input_tokens - \(alias).cache_read_tokens
          ELSE \(alias).input_tokens
        END
        """
    }

    private static func proxyDedupExists() -> String {
        """
        EXISTS (
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
            \(Self.freshInputCase(alias: "l")) AS fresh_input,
            l.output_tokens, l.cache_read_tokens, l.cache_creation_tokens,
            l.created_at, NULL AS rollup_date
          FROM proxy_request_logs l
          WHERE l.app_type = 'codex'
            AND NOT (
              COALESCE(l.data_source, 'proxy') IN ('session_log','codex_session','gemini_session','opencode_session')
              AND \(Self.proxyDedupExists())
            )
        ), rollups AS (
          SELECT r.request_count,
            \(Self.freshInputCase(alias: "r")) AS fresh_input,
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

    /// 与 summaryQuery 相同的口径，但不过滤 app_type：按 agent 分组统计全时段与今日 token。
    private func allAgentsQuery(todayEpoch: Int64, todayKey: String) -> String {
        """
        WITH effective_detail AS (
          SELECT
            l.app_type AS agent,
            \(Self.freshInputCase(alias: "l")) AS fresh_input,
            l.output_tokens, l.cache_read_tokens, l.cache_creation_tokens,
            l.created_at, NULL AS rollup_date
          FROM proxy_request_logs l
          WHERE NOT (
            COALESCE(l.data_source, 'proxy') IN ('session_log','codex_session','gemini_session','opencode_session')
            AND \(Self.proxyDedupExists())
          )
        ), rollups AS (
          SELECT
            r.app_type AS agent,
            \(Self.freshInputCase(alias: "r")) AS fresh_input,
            r.output_tokens, r.cache_read_tokens, r.cache_creation_tokens,
            NULL AS created_at, r.date AS rollup_date
          FROM usage_daily_rollups r
        ), combined AS (
          SELECT * FROM effective_detail
          UNION ALL
          SELECT * FROM rollups
        )
        SELECT
          COALESCE(agent, '未知') AS agent,
          COALESCE(SUM(fresh_input + output_tokens + cache_read_tokens + cache_creation_tokens), 0) AS real_total,
          COALESCE(SUM(CASE WHEN created_at >= \(todayEpoch) OR rollup_date >= '\(todayKey)'
            THEN fresh_input + output_tokens + cache_read_tokens + cache_creation_tokens ELSE 0 END), 0) AS today_total
        FROM combined
        GROUP BY agent
        ORDER BY real_total DESC;
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
                  summary.allAgentsRealTotalTokens == 1_547,
                  summary.allAgentsTodayTokens == 1_317,
                  summary.allAgentsShares.map(\.name) == ["codex", "claude"],
                  summary.allAgentsShares.map(\.tokens) == [1_397, 150],
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
            let zcodeDirectory = directory.appendingPathComponent("zcode-home", isDirectory: true)
            try fileManager.createDirectory(at: zcodeDirectory, withIntermediateDirectories: true)
            let zcodeDatabase = zcodeDirectory.appendingPathComponent(".zcode/cli/db/db.sqlite")
            try fileManager.createDirectory(
                at: zcodeDatabase.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try execute(
                database: zcodeDatabase,
                sql: """
                CREATE TABLE turn_usage (
                  session_id TEXT PRIMARY KEY, turn_id TEXT, status TEXT, started_at INTEGER,
                  input_tokens INTEGER, output_tokens INTEGER, reasoning_tokens INTEGER,
                  cache_creation_input_tokens INTEGER, cache_read_input_tokens INTEGER
                );
                INSERT INTO turn_usage VALUES ('s1','t1','ok',\(Int64(Date().timeIntervalSince1970 * 1000)),1000,100,0,0,600);
                INSERT INTO turn_usage VALUES ('s2','t2','ok',1,50,10,5,2,3);
                """
            )
            let zcodeUsage = ZCodeUsageReader.usage(
                todayStart: Calendar.current.startOfDay(for: Date()),
                fileManager: fileManager,
                homeDirectory: zcodeDirectory
            )
            guard zcodeUsage?.lifetimeTokens == 1_770, zcodeUsage?.todayTokens == 1_700 else {
                print("CC Switch reader self-test failed: zcode usage totals")
                return false
            }
            guard ZCodeUsageReader.usage(
                todayStart: Date(),
                fileManager: fileManager,
                homeDirectory: directory.appendingPathComponent("empty-home", isDirectory: true)
            ) == nil else {
                print("CC Switch reader self-test failed: zcode missing database must stay nil")
                return false
            }
            let grokMerged = replacingGrokSessionShare(
                in: [
                    AgentTokenShare(name: "codex", tokens: 100),
                    AgentTokenShare(name: "grokbuild", tokens: 25)
                ],
                with: 80
            )
            guard grokMerged.map(\.name) == ["codex", "Grok"],
                  grokMerged.map(\.tokens) == [100, 80]
            else {
                print("CC Switch reader self-test failed: Grok session source replacement")
                return false
            }
            guard customTokenCount(fromWanText: "5000") == 50_000_000,
                  customTokenCount(fromWanText: "1,5") == 15_000,
                  customTokenCount(fromWanText: "inf") == nil,
                  customTokenCount(fromWanText: "1e999") == nil,
                  AgentTokenShare(name: "codex", tokens: 1).id
                    != AgentTokenShare(name: "codex", tokens: 1, manual: true).id
            else {
                print("CC Switch reader self-test failed: custom token input boundary")
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
          ('fresh','codex','gpt-fresh',50,10,5,2,2,'codex_session',200,\(now)),
          ('claude-proxy','claude','claude-test',100,50,0,0,0,'proxy',200,\(now));
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

/// ZCode CLI 的本机全时段与今日 token 用量（~/.zcode/cli/db/db.sqlite 的 turn_usage 表）。
/// 与 CC Switch 相同的含缓存口径；数据库不存在时返回 nil，不伪造数据。
enum ZCodeUsageReader {
    struct Usage: Equatable {
        let lifetimeTokens: Int64
        let todayTokens: Int64
    }

    static func usage(
        todayStart: Date,
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil
    ) -> Usage? {
        let home = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        let database = home.appendingPathComponent(".zcode/cli/db/db.sqlite")
        guard fileManager.fileExists(atPath: database.path) else { return nil }
        guard let sqlitePath = ["/usr/bin/sqlite3", "/opt/homebrew/bin/sqlite3"]
            .first(where: { fileManager.isExecutableFile(atPath: $0) })
        else { return nil }

        let todayEpochMs = Int64(todayStart.timeIntervalSince1970 * 1000)
        let sql = """
        SELECT COALESCE(SUM(input_tokens),0) + COALESCE(SUM(output_tokens),0)
             + COALESCE(SUM(reasoning_tokens),0) + COALESCE(SUM(cache_read_input_tokens),0)
             + COALESCE(SUM(cache_creation_input_tokens),0) AS real_total,
          COALESCE(SUM(CASE WHEN started_at >= \(todayEpochMs)
            THEN input_tokens + output_tokens + reasoning_tokens
                 + cache_read_input_tokens + cache_creation_input_tokens ELSE 0 END), 0) AS today_total
        FROM turn_usage;
        """
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: sqlitePath)
        process.arguments = ["-readonly", "-json", database.path, sql]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = (try? output.fileHandleForReading.read(upToCount: 1 << 20)) ?? Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = rows.first
        else { return nil }
        return Usage(
            lifetimeTokens: (first["real_total"] as? NSNumber)?.int64Value ?? 0,
            todayTokens: (first["today_total"] as? NSNumber)?.int64Value ?? 0
        )
    }
}

/// 用户手动录入的自定义 token 来源（如美团 API），存 UserDefaults，全局生效。
enum CustomTokenSourceStore {
    struct Entry: Equatable, Identifiable, Codable {
        let name: String
        let tokens: Int64

        var id: String { name }
    }

    static let storageKey = "CodexManagerNext.customTokenSources.v1"

    static func load(defaults: UserDefaults = .standard) -> [Entry] {
        let raw: String?
        if let stored = defaults.string(forKey: storageKey) {
            raw = stored
        } else if let stored = defaults.data(forKey: storageKey) {
            raw = String(data: stored, encoding: .utf8)
        } else {
            raw = nil
        }
        guard let raw,
              let data = raw.data(using: .utf8),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries
    }

    static func save(_ entries: [Entry], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(entries),
              let raw = String(data: data, encoding: .utf8)
        else { return }
        defaults.set(raw, forKey: storageKey)
    }
}

/// Grok CLI 与 Grok 桌面工作区会话的本机全时段 token 用量（~/.grok/sessions/*/*/updates.jsonl 的 usage 记录）。
enum GrokUsageReader {
    static func lifetimeTokens(
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil
    ) -> Int64? {
        let home = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        let sessionsRoot = home.appendingPathComponent(".grok/sessions", isDirectory: true)
        guard fileManager.fileExists(atPath: sessionsRoot.path) else { return nil }

        var workDirectories: [URL] = []
        if let workspaceDirs = try? fileManager.contentsOfDirectory(
            at: sessionsRoot,
            includingPropertiesForKeys: nil
        ) {
            for workspace in workspaceDirs {
                if let sessionDirs = try? fileManager.contentsOfDirectory(
                    at: workspace,
                    includingPropertiesForKeys: nil
                ) {
                    for session in sessionDirs {
                        workDirectories.append(session)
                    }
                }
            }
        }

        var total: Int64 = 0
        for sessionDirectory in workDirectories {
            let updates = sessionDirectory.appendingPathComponent("updates.jsonl")
            guard fileManager.fileExists(atPath: updates.path),
                  let data = try? Data(contentsOf: updates, options: .mappedIfSafe)
            else { continue }
            for lineSubdata in splitLines(data) {
                guard lineSubdata.contains(Data("\"usage\"".utf8)),
                      let object = try? JSONSerialization.jsonObject(with: lineSubdata) as? [String: Any],
                      let usage = findUsage(in: object)
                else { continue }
                let input = (usage["inputTokens"] as? NSNumber)?.int64Value ?? 0
                let output = (usage["outputTokens"] as? NSNumber)?.int64Value ?? 0
                total += input + output
            }
        }
        return total
    }

    private static func splitLines(_ data: Data) -> [Data] {
        var lines: [Data] = []
        var start = data.startIndex
        var index = data.startIndex
        while index < data.endIndex {
            if data[index] == 0x0A {
                if index > start {
                    lines.append(data.subdata(in: start..<index))
                }
                start = data.index(after: index)
            }
            index = data.index(after: index)
        }
        if start < data.endIndex {
            lines.append(data.subdata(in: start..<data.endIndex))
        }
        return lines
    }

    private static func findUsage(in object: [String: Any]) -> [String: Any]? {
        if let usage = object["usage"] as? [String: Any],
           usage["totalTokens"] != nil {
            return usage
        }
        for value in object.values {
            if let dictionary = value as? [String: Any],
               let usage = findUsage(in: dictionary) {
                return usage
            }
            if let array = value as? [[String: Any]] {
                for item in array {
                    if let usage = findUsage(in: item) {
                        return usage
                    }
                }
            }
        }
        return nil
    }
}
