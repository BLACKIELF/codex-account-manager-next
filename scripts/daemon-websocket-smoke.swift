import Foundation

@main
enum DaemonWebSocketSmoke {
    static func main() {
        let socketPath = ProcessInfo.processInfo.environment["CAMNEXT_DAEMON_SOCKET"]
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex/app-server-control/app-server-control.sock").path
        guard FileManager.default.fileExists(atPath: socketPath) else {
            print("daemon WebSocket smoke failed: socket is missing")
            exit(1)
        }

        let callbackQueue = DispatchQueue(label: "codex-account-manager-next.daemon-smoke")
        let completed = DispatchSemaphore(value: 0)
        var succeeded = false
        var didComplete = false
        func finish(_ success: Bool, _ message: String) {
            guard !didComplete else { return }
            didComplete = true
            succeeded = success
            print(message)
            completed.signal()
        }

        let socket = AFUnixWebSocket(
            socketPath: socketPath,
            maximumMessageBytes: 2 * 1_024 * 1_024,
            callbackQueue: callbackQueue
        )
        socket.start(
            onReady: {
                let request: [String: Any] = [
                    "id": 1,
                    "method": "initialize",
                    "params": [
                        "clientInfo": [
                            "name": "codex-account-manager-next-smoke",
                            "title": "Codex Account Manager Next Smoke",
                            "version": "0"
                        ],
                        "capabilities": [
                            "experimentalApi": false,
                            "optOutNotificationMethods": []
                        ]
                    ]
                ]
                guard let data = try? JSONSerialization.data(withJSONObject: request),
                      socket.sendText(data) else {
                    finish(false, "daemon WebSocket smoke failed: initialize write")
                    return
                }
            },
            onMessage: { data in
                guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let requestID = (object["id"] as? NSNumber)?.intValue else { return }
                if requestID == 1 {
                    guard object["error"] == nil,
                          let initialized = try? JSONSerialization.data(withJSONObject: [
                              "method": "initialized"
                          ]),
                          socket.sendText(initialized),
                          let list = try? JSONSerialization.data(withJSONObject: [
                              "id": 2,
                              "method": "thread/list",
                              "params": [
                                  "limit": 30,
                                  "sortKey": "recency_at",
                                  "sortDirection": "desc",
                                  "useStateDbOnly": true
                              ]
                          ]),
                          socket.sendText(list) else {
                        finish(false, "daemon WebSocket smoke failed: initialize response")
                        return
                    }
                } else if requestID == 2 {
                    guard object["error"] == nil,
                          let result = object["result"] as? [String: Any],
                          let threads = result["data"] as? [[String: Any]] else {
                        finish(false, "daemon WebSocket smoke failed: thread/list response")
                        return
                    }
                    guard threads.count == 30 else {
                        finish(false, "daemon WebSocket smoke failed: expected 30 threads, got \(threads.count)")
                        return
                    }
                    finish(true, "daemon WebSocket smoke passed: initialize ok, thread/list count=30")
                }
            },
            onDisconnect: {
                finish(false, "daemon WebSocket smoke failed: disconnected")
            }
        )

        if completed.wait(timeout: .now() + 12) == .timedOut {
            print("daemon WebSocket smoke failed: timed out")
            socket.close()
            exit(1)
        }
        socket.close()
        exit(succeeded ? 0 : 1)
    }
}
