import Foundation

struct HubTask: Decodable, Equatable {
    let accountAlias: String?
    let state: String
    let createdAt: Date
    let updatedAt: Date

    private static let accountBusyStates: Set<String> = [
        "awaiting_approval", "starting", "running", "cancel_requested", "uncertain"
    ]

    static func blocksAccountWarmUp(state: String) -> Bool {
        accountBusyStates.contains(state)
    }

    var blocksAccountWarmUp: Bool {
        Self.blocksAccountWarmUp(state: state)
    }
}

struct HubOverview: Decodable {
    let tasks: [HubTask]?
}

enum HubWarmUpAvailability: Equatable {
    case idle
    case busy
    case unavailable
}

enum HubConsoleModel {
    private static let overviewURL = URL(string: "http://127.0.0.1:8787/api/overview")!

    static func warmUpAvailability(for accountAlias: String) async -> HubWarmUpAvailability {
        let alias = accountAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !alias.isEmpty else { return .unavailable }
        do {
            let overview = try await fetchInspectionOverview()
            let busy = (overview.tasks ?? []).contains {
                $0.accountAlias?.caseInsensitiveCompare(alias) == .orderedSame && $0.blocksAccountWarmUp
            }
            return busy ? .busy : .idle
        } catch {
            return .unavailable
        }
    }

    static func fetchInspectionOverview() async throws -> HubOverview {
        var request = URLRequest(url: overviewURL, timeoutInterval: 6)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode)
        else { throw URLError(.badServerResponse) }
        return try decoder.decode(HubOverview.self, from: data)
    }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = HubDateParsing.parse(raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "无法解析时间 \(raw)"
                )
            }
            return date
        }
        return decoder
    }()
}

enum HubWarmUpGateSelfTest {
    static func run() -> Bool {
        let blocking = ["awaiting_approval", "starting", "running", "cancel_requested", "uncertain"]
        let terminal = ["succeeded", "failed", "cancelled", "blocked_configuration"]
        let passed = blocking.allSatisfy { HubTask.blocksAccountWarmUp(state: $0) }
            && terminal.allSatisfy { !HubTask.blocksAccountWarmUp(state: $0) }
        if !passed { print("Hub warm-up gate self-test failed") }
        return passed
    }
}

private enum HubDateParsing {
    static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let plainSecondsFormatter = ISO8601DateFormatter()

    static func parse(_ raw: String) -> Date? {
        fractionalSecondsFormatter.date(from: raw) ?? plainSecondsFormatter.date(from: raw)
    }
}
