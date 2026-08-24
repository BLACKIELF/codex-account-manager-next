import AppKit
import Foundation

enum CodexSessionLink {
    static func url(threadID: String) -> URL? {
        let trimmed = threadID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uuid = UUID(uuidString: trimmed) else { return nil }
        let canonicalID = uuid.uuidString.lowercased()
        guard trimmed.lowercased() == canonicalID else { return nil }

        var components = URLComponents()
        components.scheme = "codex"
        components.host = "threads"
        components.path = "/\(canonicalID)"
        return components.url
    }
}

enum CodexSessionOpener {
    @discardableResult
    static func open(threadID: String) -> Bool {
        guard let url = CodexSessionLink.url(threadID: threadID) else { return false }
        return NSWorkspace.shared.open(url)
    }
}
