import Cocoa
import Foundation

enum CodexExecutable {
    static func path(fileManager: FileManager = .default) -> String? {
        var candidates: [String] = []
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            candidates.append(appURL.appendingPathComponent("Contents/Resources/codex").path)
        }
        candidates.append(contentsOf: [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ])
        return candidates.first { fileManager.isExecutableFile(atPath: $0) }
    }

    static func version() -> String? {
        guard let executable = path() else { return nil }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["--version"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            return nil
        }
        guard finished.wait(timeout: .now() + 2) == .success else {
            process.terminate()
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let maximumVersionBytes = 4 * 1_024
        guard let data = try? pipe.fileHandleForReading.read(upToCount: maximumVersionBytes + 1),
              data.count <= maximumVersionBytes
        else { return nil }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
