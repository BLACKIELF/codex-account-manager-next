import AppKit
import Foundation

protocol TerminalLaunching {
    func launch(
        codexHome: URL,
        workingDirectory: URL?,
        accountName: String,
        preference: CodexExecutionPreference
    ) async throws
}

enum TerminalLauncherError: LocalizedError {
    case invalidProfileID
    case invalidProfileDirectory
    case profileDirectoryMissing
    case codexExecutableMissing
    case appleEventDenied
    case appleScriptFailed

    var errorDescription: String? {
        switch self {
        case .invalidProfileID:
            return "账号环境标识无效；仅允许字母和数字"
        case .invalidProfileDirectory:
            return "账号环境不在 Next 的独立资料目录中"
        case .profileDirectoryMissing:
            return "账号环境目录不存在，请先重新登录该账号"
        case .codexExecutableMissing:
            return "未找到可执行的 Codex CLI。请先安装 Codex CLI，或确认独立安装路径可执行"
        case .appleEventDenied:
            return "Terminal 自动化授权被拒绝。请前往：系统设置 → 隐私与安全性 → 自动化 → CodexAccountManagerNext → Terminal"
        case .appleScriptFailed:
            return "无法在 Terminal 中打开 Codex"
        }
    }
}

struct TerminalAppLauncher: TerminalLaunching {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func launch(
        codexHome: URL,
        workingDirectory: URL?,
        accountName: String,
        preference: CodexExecutionPreference
    ) async throws {
        let command = try launchCommand(
            codexHome: codexHome,
            workingDirectory: workingDirectory,
            accountName: accountName,
            preference: preference
        )
        let source = "tell application \"Terminal\"\nactivate\ndo script \"\(Self.appleScriptLiteral(command))\"\nend tell"
        var errorInfo: NSDictionary?
        guard NSAppleScript(source: source)?.executeAndReturnError(&errorInfo) != nil else {
            let number = errorInfo?[NSAppleScript.errorNumber] as? Int
            if number == -1743 {
                throw TerminalLauncherError.appleEventDenied
            }
            throw TerminalLauncherError.appleScriptFailed
        }
    }

    func launchCommand(
        codexHome: URL,
        workingDirectory: URL?,
        accountName: String,
        preference: CodexExecutionPreference
    ) throws -> String {
        let preference = try preference.validated()
        let profileID = codexHome.lastPathComponent
        guard !profileID.isEmpty,
              profileID.unicodeScalars.allSatisfy(CharacterSet.alphanumerics.contains)
        else { throw TerminalLauncherError.invalidProfileID }

        let expectedHome = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex-account-manager-next/profiles", isDirectory: true)
            .appendingPathComponent(profileID, isDirectory: true)
            .standardizedFileURL.path
        guard codexHome.standardizedFileURL.path == expectedHome else {
            throw TerminalLauncherError.invalidProfileDirectory
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: codexHome.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw TerminalLauncherError.profileDirectoryMissing
        }
        guard let executable = Self.codexExecutable(fileManager: fileManager) else {
            throw TerminalLauncherError.codexExecutableMissing
        }

        let directoryCommand = workingDirectory.map {
            "cd \(Self.shellPathExpression($0.path, homeDirectory: fileManager.homeDirectoryForCurrentUser)) || cd \"$HOME\""
        }
            ?? "cd \"$HOME\""
        let managedHomeExpression = "\"$HOME\"/" + Self.shellQuote(
            ".codex-account-manager-next/profiles/\(profileID)"
        )
        return [
            "export CODEX_HOME=\(managedHomeExpression)",
            "unset CODEX_ACCESS_TOKEN CODEX_API_KEY",
            directoryCommand,
            "echo \(Self.shellQuote("Codex 独立账号环境已就绪"))",
            try Self.configuredCodexCommand(executable: executable, preference: preference)
        ].joined(separator: "\n")
    }

    static func configuredCodexCommand(
        executable: String,
        preference: CodexExecutionPreference
    ) throws -> String {
        let preference = try preference.validated()
        var arguments = [
            shellPathExpression(executable),
            "--model", shellQuote(preference.model.rawValue),
            "-c", shellQuote("model_reasoning_effort=\"\(preference.reasoningEffort.rawValue)\""),
            "-c", shellQuote("agents.default_subagent_model=\"\(preference.model.rawValue)\""),
            "-c", shellQuote(
                "agents.default_subagent_reasoning_effort=\"\(preference.reasoningEffort.rawValue)\""
            ),
            "-c", shellQuote("service_tier=\"\(preference.serviceTier.rawValue)\"")
        ]
        arguments.append(preference.serviceTier == .fast ? "--enable fast_mode" : "--disable fast_mode")
        return arguments.joined(separator: " ")
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

    private static func shellPathExpression(
        _ path: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> String {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let homePath = homeDirectory.standardizedFileURL.path
        if standardizedPath == homePath { return "\"$HOME\"" }
        let homePrefix = homePath + "/"
        if standardizedPath.hasPrefix(homePrefix) {
            return "\"$HOME\"/" + shellQuote(String(standardizedPath.dropFirst(homePrefix.count)))
        }
        return shellQuote(standardizedPath)
    }

    private static func appleScriptLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
