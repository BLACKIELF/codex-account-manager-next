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

        let olderThreadID = "019f607f-954b-72c1-8aab-12b7527f1944"
        let recentIdleThreadID = "019f607f-954b-72c1-8aab-12b7527f1945"
        let recordedThreadID = "019f607f-954b-72c1-8aab-12b7527f1946"
        let snapshot = CodexTaskLiveSnapshot(
            connectionMode: .sharedDaemon,
            records: [
                olderThreadID: TaskLiveRecord(
                    threadID: olderThreadID,
                    name: nil,
                    state: .running,
                    updatedAt: Date(timeIntervalSince1970: 1),
                    turnID: nil,
                    connectionMode: .sharedDaemon
                ),
                threadID: TaskLiveRecord(
                    threadID: threadID,
                    name: nil,
                    state: .waitingInput,
                    updatedAt: Date(timeIntervalSince1970: 2),
                    turnID: nil,
                    connectionMode: .sharedDaemon
                ),
                recentIdleThreadID: TaskLiveRecord(
                    threadID: recentIdleThreadID,
                    name: nil,
                    state: .idle,
                    updatedAt: Date(timeIntervalSince1970: 3),
                    turnID: nil,
                    connectionMode: .sharedDaemon
                ),
                recordedThreadID: TaskLiveRecord(
                    threadID: recordedThreadID,
                    name: nil,
                    state: .recorded,
                    updatedAt: Date(timeIntervalSince1970: 4),
                    turnID: nil,
                    connectionMode: .sharedDaemon
                ),
            ],
            refreshedAt: Date(timeIntervalSince1970: 4)
        )
        expect(
            CodexSessionOpener.uniqueActiveThreadID(
                in: snapshot,
                now: Date(timeIntervalSince1970: 4)
            ) == nil,
            "multiple active tasks must not guess the foreground thread"
        )
        let singleActiveSnapshot = CodexTaskLiveSnapshot(
            connectionMode: .sharedDaemon,
            records: [
                threadID: snapshot.records[threadID]!,
                recentIdleThreadID: snapshot.records[recentIdleThreadID]!,
            ],
            refreshedAt: Date(timeIntervalSince1970: 4)
        )
        expect(
            CodexSessionOpener.uniqueActiveThreadID(
                in: singleActiveSnapshot,
                now: Date(timeIntervalSince1970: 4)
            ) == threadID,
            "one active task should identify the foreground thread"
        )
        expect(
            CodexSessionOpener.uniqueActiveThreadID(
                in: .disconnected,
                now: Date(timeIntervalSince1970: 4)
            ) == nil,
            "a disconnected task snapshot must not identify a thread"
        )
        expect(
            CodexSessionOpener.uniqueActiveThreadID(
                in: singleActiveSnapshot,
                now: Date(timeIntervalSince1970: 50)
            ) == nil,
            "a stale task snapshot must not identify a thread"
        )

        let visibleTask = TaskItem(
            id: "visible",
            code: "COD-TEST",
            title: "Continue account manager repair",
            detail: "",
            chip: "recent",
            updatedAt: Date(timeIntervalSince1970: 10),
            tokens: nil,
            kind: .active,
            threadID: threadID,
            sourceKind: .codexThread,
            displayState: .recentlyActive,
            stateBasis: .activityWindow
        )
        let newerBackgroundTask = TaskItem(
            id: "background",
            code: "COD-BACK",
            title: "Background task",
            detail: "",
            chip: "recent",
            updatedAt: Date(timeIntervalSince1970: 11),
            tokens: nil,
            kind: .active,
            threadID: recentIdleThreadID,
            sourceKind: .codexThread,
            displayState: .recentlyActive,
            stateBasis: .activityWindow
        )
        let taskBoard = TaskBoard(
            refreshedAt: Date(timeIntervalSince1970: 12),
            columns: [
                TaskColumn(id: .active, title: "Active", count: 2, items: [visibleTask, newerBackgroundTask])
            ]
        )
        expect(
            CodexSessionOpener.mostRecentThreadID(
                in: taskBoard,
                matchingWindowTitles: [
                    "Continue account manager repair — Codex",
                    "Background task — Codex",
                ],
                now: Date(timeIntervalSince1970: 12)
            ) == threadID,
            "the frontmost Codex window should win over a newer visible task"
        )
        expect(
            CodexSessionOpener.uniqueThreadID(
                in: taskBoard,
                matchingWindowTitles: ["Continue account manager repair — Codex"]
            ) == threadID,
            "one open task window should identify the current task"
        )
        expect(
            CodexSessionOpener.uniqueThreadID(
                in: taskBoard,
                matchingWindowTitles: [
                    "Continue account manager repair — Codex",
                    "Background task — Codex",
                ]
            ) == nil,
            "multiple open task windows must not guess the current task"
        )
        expect(
            CodexSessionOpener.mostRecentThreadID(
                in: taskBoard,
                matchingWindowTitles: ["ChatGPT"],
                now: Date(timeIntervalSince1970: 12)
            ) == nil,
            "a generic app window title must not guess the current task"
        )
        expect(
            CodexSessionOpener.containsVisibleThread(
                threadID,
                in: taskBoard,
                matchingWindowTitles: ["Continue account manager repair — Codex"]
            ),
            "task restoration should verify the requested visible thread"
        )
        expect(
            !CodexSessionOpener.containsVisibleThread(
                recordedThreadID,
                in: taskBoard,
                matchingWindowTitles: ["Continue account manager repair — Codex"]
            ),
            "task restoration should reject a different thread"
        )
        expect(
            CodexSessionOpener.containsThread(threadID, in: taskBoard),
            "a captured foreground thread must still exist on the task board"
        )
        expect(
            !CodexSessionOpener.containsThread(recordedThreadID, in: taskBoard),
            "an unknown captured thread must be rejected"
        )

        let logNow = Date(timeIntervalSince1970: 1_000)
        let freshTaskBoard = TaskBoard(refreshedAt: logNow, columns: taskBoard.columns)
        let focusedLog = """
            1970-01-01T00:16:39.000Z info [electron-message-handler] event rendererWindowFocused=true rendererWindowVisible=true threadId=\(threadID) turnId=\(olderThreadID)
            """
        expect(
            CodexSessionOpener.uniqueRecentFocusedThreadID(
                in: focusedLog,
                taskBoard: freshTaskBoard,
                now: logNow
            ) == threadID,
            "fresh focused Codex log metadata should identify the current task"
        )
        expect(
            CodexSessionOpener.uniqueRecentFocusedThreadID(
                in: focusedLog.replacingOccurrences(of: "rendererWindowFocused=true", with: "rendererWindowFocused=false"),
                taskBoard: freshTaskBoard,
                now: logNow
            ) == nil,
            "unfocused Codex log metadata must not identify a task"
        )
        let blurredLog =
            focusedLog + "\n"
            + focusedLog
            .replacingOccurrences(of: "00:16:39.000", with: "00:16:40.000")
            .replacingOccurrences(of: "rendererWindowFocused=true", with: "rendererWindowFocused=false")
        expect(
            CodexSessionOpener.uniqueRecentFocusedThreadID(
                in: blurredLog,
                taskBoard: freshTaskBoard,
                now: logNow
            ) == threadID,
            "the same task should survive the focused-to-manager blur transition"
        )
        let ambiguousLog =
            focusedLog + "\n"
            + focusedLog
            .replacingOccurrences(of: "00:16:39.000", with: "00:16:40.000")
            .replacingOccurrences(of: "threadId=\(threadID)", with: "threadId=\(recentIdleThreadID)")
        expect(
            CodexSessionOpener.uniqueRecentFocusedThreadID(
                in: ambiguousLog,
                taskBoard: freshTaskBoard,
                now: logNow
            ) == nil,
            "multiple recent focused task IDs must fail closed"
        )

        if failures.isEmpty {
            print("codex session link self-test passed")
            return true
        }
        failures.forEach { print("codex session link self-test failed: \($0)") }
        return false
    }
}
