import Cocoa
import Foundation

final class CodexAccountActions {
    private var loginProcess: Process?
    private var warmUpProcess: Process?

    var isLoginRunning: Bool { loginProcess?.isRunning == true }
    var isWarmUpRunning: Bool { warmUpProcess?.isRunning == true }

    func login(
        profile: CodexProfile,
        completion: @escaping (Result<Void, Error>) -> Void
    ) throws {
        guard !isLoginRunning else { return }
        guard let executable = CodexExecutable.path() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["login"]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = profile.codexHomePath
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                self?.loginProcess = nil
                if finished.terminationStatus == 0 {
                    completion(.success(()))
                } else {
                    completion(.failure(CocoaError(.userCancelled)))
                }
            }
        }
        try process.run()
        loginProcess = process
    }

    func launchCodex(profile: CodexProfile, completion: @escaping (Error?) -> Void) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") else {
            completion(CocoaError(.fileNoSuchFile))
            return
        }
        guard let executable = CodexExecutable.path() else {
            completion(CocoaError(.fileNoSuchFile))
            return
        }
        let fileManager = FileManager.default
        let systemHome = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        let systemAuthURL = systemHome.appendingPathComponent("auth.json")
        let targetAuthURL = profile.codexHomeURL.appendingPathComponent("auth.json")
        let previousAuth = try? Data(contentsOf: systemAuthURL)
        let targetAuth: Data?
        if profile.isSystemProfile {
            targetAuth = nil
        } else {
            do {
                targetAuth = try Data(contentsOf: targetAuthURL)
            } catch {
                completion(error)
                return
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try fileManager.createDirectory(
                    at: systemHome,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
                if let targetAuth {
                    if targetAuth != previousAuth {
                        let logout = Process()
                        logout.executableURL = URL(fileURLWithPath: executable)
                        logout.arguments = ["logout"]
                        var environment = ProcessInfo.processInfo.environment
                        environment["CODEX_HOME"] = systemHome.path
                        logout.environment = environment
                        logout.standardOutput = FileHandle.nullDevice
                        logout.standardError = FileHandle.nullDevice
                        try logout.run()
                        logout.waitUntilExit()
                        guard logout.terminationStatus == 0 else {
                            throw NSError(
                                domain: "CodexAccountActions",
                                code: Int(logout.terminationStatus),
                                userInfo: [NSLocalizedDescriptionKey: "Codex 注销未完成，原账号未切换"]
                            )
                        }
                    }
                    try targetAuth.write(to: systemAuthURL, options: .atomic)
                    try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: systemAuthURL.path)
                }
            } catch {
                if targetAuth != nil {
                    Self.restoreAuth(previousAuth, at: systemAuthURL, fileManager: fileManager)
                }
                DispatchQueue.main.async { completion(error) }
                return
            }

            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { application, error in
                guard error == nil, let application else {
                    if targetAuth != nil {
                        Self.restoreAuth(previousAuth, at: systemAuthURL, fileManager: fileManager)
                    }
                    DispatchQueue.main.async { completion(error ?? CocoaError(.executableNotLoadable)) }
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if application.isTerminated {
                        if targetAuth != nil {
                            Self.restoreAuth(previousAuth, at: systemAuthURL, fileManager: fileManager)
                        }
                        completion(NSError(
                            domain: "CodexAccountActions",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Codex 启动后立即退出，原账号已恢复"]
                        ))
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }

    private static func restoreAuth(_ data: Data?, at url: URL, fileManager: FileManager) {
        if let data {
            try? data.write(to: url, options: .atomic)
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } else {
            try? fileManager.removeItem(at: url)
        }
    }

    func warmUp(
        profile: CodexProfile,
        completion: @escaping (Result<Void, Error>) -> Void
    ) throws {
        guard !isWarmUpRunning else { return }
        guard let executable = CodexExecutable.path() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = [
            "exec",
            "--ephemeral",
            "--skip-git-repo-check",
            "--ignore-user-config",
            "--ignore-rules",
            "--model", "gpt-5.6-luna",
            "--sandbox", "read-only",
            "--color", "never",
            "-C", FileManager.default.temporaryDirectory.path,
            "你好"
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = profile.codexHomePath
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                self?.warmUpProcess = nil
                if finished.terminationStatus == 0 {
                    completion(.success(()))
                } else {
                    completion(.failure(NSError(
                        domain: "CodexAccountActions",
                        code: Int(finished.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "官方 Codex 请求未完成"]
                    )))
                }
            }
        }
        try process.run()
        warmUpProcess = process
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 90) {
            if process.isRunning { process.terminate() }
        }
    }
}
