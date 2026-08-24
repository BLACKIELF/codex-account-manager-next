import Foundation

struct AccountAutomationEvent: Codable, Equatable, Identifiable {
    enum Level: String, Codable {
        case info
        case success
        case warning
        case failure
    }

    let id: UUID
    let occurredAt: Date
    let level: Level
    let title: String
    let detail: String
}

final class AccountAutomationAuditStore {
    private let fileManager: FileManager
    private let eventsURL: URL
    private let maximumEvents = 100

    init(fileManager: FileManager = .default, applicationSupportDirectory: URL? = nil) {
        self.fileManager = fileManager
        let support = applicationSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        eventsURL = support
            .appendingPathComponent("CodexAccountManagerNext", isDirectory: true)
            .appendingPathComponent("automation-events-v1.json")
    }

    func load() -> [AccountAutomationEvent] {
        guard let data = try? Data(contentsOf: eventsURL),
              let events = try? JSONDecoder().decode([AccountAutomationEvent].self, from: data)
        else { return [] }
        return Array(events.prefix(maximumEvents))
    }

    func append(_ event: AccountAutomationEvent) throws -> [AccountAutomationEvent] {
        var events = load()
        events.insert(event, at: 0)
        events = Array(events.prefix(maximumEvents))
        let directory = eventsURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let data = try JSONEncoder().encode(events)
        try data.write(to: eventsURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: eventsURL.path)
        return events
    }
}

enum AccountAutomationAuditStoreSelfTest {
    static func run() -> Bool {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("account-automation-audit-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        do {
            let store = AccountAutomationAuditStore(
                fileManager: fileManager,
                applicationSupportDirectory: root
            )
            let event = AccountAutomationEvent(
                id: UUID(),
                occurredAt: Date(timeIntervalSince1970: 123),
                level: .success,
                title: "自动切换完成",
                detail: "c***@e***.com → n***@e***.com"
            )
            guard try store.append(event) == [event], store.load() == [event] else {
                print("Account automation audit store self-test failed")
                return false
            }
            print("Account automation audit store self-test passed")
            return true
        } catch {
            print("Account automation audit store self-test failed: \(error)")
            return false
        }
    }
}
