import Foundation

enum CodexSessionLinkSelfTest {
    static func run() -> Bool {
        var failures: [String] = []
        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        let threadID = "019f607f-954b-72c1-8aab-12b7527f1943"
        let url = CodexSessionLink.url(threadID: threadID)
        expect(url?.absoluteString == "codex://threads/\(threadID)", "valid thread ID should create canonical Codex URL")
        expect(url?.scheme == "codex", "URL scheme should be codex")
        expect(url?.host == "threads", "URL host should be threads")
        expect(
            CodexSessionLink.url(threadID: threadID.uppercased())?.absoluteString == "codex://threads/\(threadID)",
            "uppercase UUID should be canonicalized"
        )
        expect(
            CodexSessionLink.url(threadID: "  \(threadID)\n")?.absoluteString == "codex://threads/\(threadID)",
            "surrounding whitespace should be ignored"
        )
        expect(CodexSessionLink.url(threadID: "not-a-thread") == nil, "invalid thread ID should be rejected")
        expect(CodexSessionLink.url(threadID: "{\(threadID)}") == nil, "non-canonical UUID should be rejected")
        expect(CodexSessionLink.url(threadID: "") == nil, "empty thread ID should be rejected")

        if failures.isEmpty {
            print("codex session link self-test passed")
            return true
        }
        failures.forEach { print("codex session link self-test failed: \($0)") }
        return false
    }
}
