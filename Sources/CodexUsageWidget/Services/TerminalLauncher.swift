import AppKit
import Foundation

protocol TerminalLaunching {
    func launch(codexHome: URL, workingDirectory: URL?, accountName: String) async throws
}

enum TerminalLauncherError: LocalizedError {
    case invalidProfileID
    case profileDirectoryMissing(String)
    case codexExecutableMissing
    case appleEventDenied
    case appleScriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProfileID:
            return "账号环境标识无效；仅允许字母和数字"
        case .profileDirectoryMissing(let path):
            return "账号环境目录不存在：\(path)。请先重新登录该账号"
        case .codexExecutableMissing:
            return "未找到可执行的 Codex CLI。请先安装 Codex CLI，或确认独立安装路径可执行"
        case .appleEventDenied:
            return "Terminal 自动化授权被拒绝。请前往：系统设置 → 隐私与安全性 → 自动化 → CodexAccountManagerNext → Terminal"
        case .appleScriptFailed(let detail):
            return "无法在 Terminal 中打开 Codex：\(detail)"
        }
    }
}

struct TerminalAppLauncher: TerminalLaunching {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func launch(codexHome: URL, workingDirectory: URL?, accountName: String) async throws {
        let command = try launchCommand(
            codexHome: codexHome,
            workingDirectory: workingDirectory,
            accountName: accountName
        )
        let source = "tell application \"Terminal\"\nactivate\ndo script \"\(Self.appleScriptLiteral(command))\"\nend tell"
        var errorInfo: NSDictionary?
        guard NSAppleScript(source: source)?.executeAndReturnError(&errorInfo) != nil else {
            let number = errorInfo?[NSAppleScript.errorNumber] as? Int
            if number == -1743 {
                throw TerminalLauncherError.appleEventDenied
            }
            let message = errorInfo?[NSAppleScript.errorMessage] as? String ?? "AppleEvent 执行失败"
            throw TerminalLauncherError.appleScriptFailed(message)
        }
    }

    func launchCommand(codexHome: URL, workingDirectory: URL?, accountName: String) throws -> String {
        let profileID = codexHome.lastPathComponent
        guard !profileID.isEmpty,
              profileID.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains)
        else { throw TerminalLauncherError.invalidProfileID }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: codexHome.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw TerminalLauncherError.profileDirectoryMissing(codexHome.path)
        }
        guard let executable = Self.codexExecutable(fileManager: fileManager) else {
            throw TerminalLauncherError.codexExecutableMissing
        }

        let directoryCommand = workingDirectory.map { "cd \(Self.shellQuote($0.path)) || cd \"$HOME\"" }
            ?? "cd \"$HOME\""
        return [
            "export CODEX_HOME=\(Self.shellQuote(codexHome.path))",
            "unset CODEX_ACCESS_TOKEN CODEX_API_KEY",
            directoryCommand,
            "echo \(Self.shellQuote("Codex 账号: \(accountName) · CODEX_HOME=\(codexHome.path)"))",
            Self.configuredCodexCommand(executable: executable)
        ].joined(separator: "\n")
    }

    private static func configuredCodexCommand(executable: String) -> String {
        [
            shellQuote(executable),
            "--model", shellQuote("gpt-5.6-sol"),
            "-c", shellQuote("model_reasoning_effort=\"high\""),
            "-c", shellQuote("agents.default_subagent_model=\"gpt-5.6-terra\""),
            "-c", shellQuote("agents.default_subagent_reasoning_effort=\"xhigh\"")
        ].joined(separator: " ")
    }

    static func codexExecutable(fileManager: FileManager = .default) -> String? {
        let independentCandidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ]
        return independentCandidates.first(where: fileManager.isExecutableFile(atPath:))
            ?? CodexExecutable.path(fileManager: fileManager)
    }

    static func socketPathUTF8Length(codexHome: URL) -> Int {
        codexHome
            .appendingPathComponent("app-server-control/app-server-control.sock")
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
            .lengthOfBytes(using: .utf8)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
