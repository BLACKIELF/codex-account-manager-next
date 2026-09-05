import Foundation

private enum DebugLogger {
    private static let lock = NSLock()
    private static let maximumBytes = 512 * 1_024

    static func write(_ message: String) {
        guard ProcessInfo.processInfo.environment["CAMNEXT_DEBUG"] == "1" else { return }

        lock.lock()
        defer { lock.unlock() }

        let fileManager = FileManager.default
        guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }
        let url =
            cacheDirectory
            .appendingPathComponent("CodexAccountManagerNext", isDirectory: true)
            .appendingPathComponent("debug.log")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let sanitizedMessage =
            message
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        guard let line = "\(timestamp) \(sanitizedMessage)\n".data(using: .utf8) else { return }

        var data = Data()
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
            let fileSize = values.fileSize,
            fileSize <= maximumBytes,
            let existing = try? Data(contentsOf: url)
        {
            data = existing
        }
        data.append(line)
        if data.count > maximumBytes {
            data = Data(data.suffix(maximumBytes))
        }
        try? PrivateLocalFileStore.write(data, to: url, fileManager: fileManager)
    }
}

func debugLog(_ message: String) {
    DebugLogger.write(message)
}
