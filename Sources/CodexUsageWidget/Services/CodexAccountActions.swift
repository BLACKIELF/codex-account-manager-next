import Cocoa
import CryptoKit
import Darwin
import Foundation

private enum CodexLoginError: LocalizedError {
    case browserUnavailable
    case cancelled
    case credentialsUnavailable
    case identityMismatch
    case message(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .browserUnavailable: return "无法打开官方登录网页"
        case .cancelled: return "登录已取消，原账号未受影响"
        case .credentialsUnavailable: return "官方登录已完成，但没有生成可保存的本机凭据"
        case .identityMismatch: return "登录身份与这张账号卡不一致，未写入原账号"
        case let .message(message): return message
        case .timedOut: return "等待官方登录完成超时，原账号未受影响"
        }
    }
}

private enum CodexLoginProtocolState: Equatable {
    case initializing
    case starting
    case waiting(loginID: String)
    case readingAccount
    case finished
}

private enum CodexLoginProtocolEvent: Equatable {
    case none
    case initialized
    case loginStarted(loginID: String, authURL: String)
    case loginCompleted
    case authenticated(email: String)
    case failed(String)
}

private enum CodexLoginProtocolParser {
    static func event(
        from object: [String: Any],
        state: CodexLoginProtocolState
    ) -> CodexLoginProtocolEvent {
        if object["method"] as? String == "account/login/completed" {
            guard case let .waiting(expectedLoginID) = state,
                  let params = object["params"] as? [String: Any]
            else { return .none }
            if let receivedLoginID = params["loginId"] as? String,
               receivedLoginID != expectedLoginID {
                return .none
            }
            guard params["success"] as? Bool == true else {
                return .failed(nonEmpty(params["error"] as? String) ?? "官方登录未完成")
            }
            return .loginCompleted
        }

        guard let responseID = integerID(object["id"]) else { return .none }
        if let error = object["error"] as? [String: Any] {
            return .failed(nonEmpty(error["message"] as? String) ?? "官方登录服务返回错误")
        }
        switch (state, responseID) {
        case (.initializing, 1):
            return .initialized
        case (.starting, 2):
            guard let result = object["result"] as? [String: Any],
                  result["type"] as? String == "chatgpt",
                  let loginID = nonEmpty(result["loginId"] as? String),
                  let authURL = nonEmpty(result["authUrl"] as? String)
            else { return .failed("官方登录服务返回了无法识别的响应") }
            return .loginStarted(loginID: loginID, authURL: authURL)
        case (.readingAccount, 3):
            guard let result = object["result"] as? [String: Any],
                  let account = result["account"] as? [String: Any],
                  account["type"] as? String == "chatgpt",
                  let email = nonEmpty(account["email"] as? String)
            else { return .failed("登录完成，但无法确认账号身份") }
            return .authenticated(email: email)
        default:
            return .none
        }
    }

    private static func integerID(_ value: Any?) -> Int64? {
        if let value = value as? Int { return Int64(value) }
        if let value = value as? Int64 { return value }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private final class CodexLoginSession {
    private let profile: CodexProfile
    private let executableURL: URL
    private let fileManager: FileManager
    private let stagingHomeURL: URL
    private let completion: (Result<Void, Error>) -> Void
    private let queue = DispatchQueue(label: "com.blackielf.codex-account-manager-next.account-login", qos: .userInitiated)
    private let readerQueue = DispatchQueue(label: "com.blackielf.codex-account-manager-next.account-login.reader", qos: .utility)
    private var state: CodexLoginProtocolState = .initializing
    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?
    private var outputBuffer = Data()
    private var timeout: DispatchWorkItem?
    private var isFinished = false

    init(
        profile: CodexProfile,
        executableURL: URL,
        fileManager: FileManager = .default,
        completion: @escaping (Result<Void, Error>) -> Void
    ) throws {
        self.profile = profile
        self.executableURL = executableURL
        self.fileManager = fileManager
        self.completion = completion
        stagingHomeURL = fileManager.temporaryDirectory
            .appendingPathComponent("camnext-login-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: stagingHomeURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stagingHomeURL.path)
    }

    func start() throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["app-server", "-c", "cli_auth_credentials_store=\"file\"", "--stdio"]
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_HOME"] = stagingHomeURL.path
        process.environment = environment
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            self?.queue.async {
                guard let self, !self.isFinished else { return }
                self.finish(.failure(CodexLoginError.message("官方登录服务已退出")))
            }
        }
        do {
            try process.run()
            self.process = process
            inputHandle = input.fileHandleForWriting
            outputHandle = output.fileHandleForReading
            try startReadLoop(output.fileHandleForReading)
            guard writeJSON([
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "codex-account-manager-next",
                        "title": "Codex Account Manager Next",
                        "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
                    ],
                    "capabilities": ["experimentalApi": false, "optOutNotificationMethods": []]
                ]
            ]) else { throw CodexLoginError.message("无法连接官方登录服务") }
        } catch {
            isFinished = true
            state = .finished
            cleanup()
            throw error
        }

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, !self.isFinished else { return }
            self.sendCancelIfPossible()
            self.finish(.failure(CodexLoginError.timedOut))
        }
        self.timeout = timeout
        queue.asyncAfter(deadline: .now() + 10 * 60, execute: timeout)
    }

    func cancel() {
        queue.async { [weak self] in
            guard let self, !self.isFinished else { return }
            self.sendCancelIfPossible()
            self.finish(.failure(CodexLoginError.cancelled))
        }
    }

    private func startReadLoop(_ handle: FileHandle) throws {
        let descriptor = try POSIXPipeReader.duplicateDescriptor(for: handle)
        readerQueue.async { [weak self] in
            defer { Darwin.close(descriptor) }
            while let self {
                let chunk: Data
                do {
                    guard let data = try POSIXPipeReader.readChunk(from: descriptor, maximumBytes: 64 * 1_024)
                    else { break }
                    chunk = data
                } catch {
                    break
                }
                var accepted = false
                self.queue.sync {
                    guard !self.isFinished else { return }
                    accepted = self.consume(chunk)
                }
                if !accepted { break }
            }
        }
    }

    private func consume(_ data: Data) -> Bool {
        let maximumBytes = 1 * 1_024 * 1_024
        guard !data.isEmpty,
              data.count <= maximumBytes,
              outputBuffer.count <= maximumBytes - data.count
        else {
            finish(.failure(CodexLoginError.message("官方登录响应过大")))
            return false
        }
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 10) {
            let line = outputBuffer.subdata(in: outputBuffer.startIndex..<newline)
            outputBuffer.removeSubrange(outputBuffer.startIndex...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
            else { continue }
            handle(CodexLoginProtocolParser.event(from: object, state: state))
            if isFinished { return false }
        }
        return true
    }

    private func handle(_ event: CodexLoginProtocolEvent) {
        switch event {
        case .none:
            break
        case .initialized:
            state = .starting
            guard writeJSON(["method": "initialized"]),
                  writeJSON(["id": 2, "method": "account/login/start", "params": ["type": "chatgpt"]])
            else { return finish(.failure(CodexLoginError.message("无法启动官方登录"))) }
        case let .loginStarted(loginID, authURL):
            state = .waiting(loginID: loginID)
            guard let url = URL(string: authURL), url.scheme?.lowercased() == "https" else {
                return finish(.failure(CodexLoginError.browserUnavailable))
            }
            DispatchQueue.main.async { [weak self] in
                let opened = NSWorkspace.shared.open(url)
                self?.queue.async {
                    guard let self, !self.isFinished, !opened else { return }
                    self.finish(.failure(CodexLoginError.browserUnavailable))
                }
            }
        case .loginCompleted:
            state = .readingAccount
            guard writeJSON(["id": 3, "method": "account/read", "params": ["refreshToken": false]])
            else { return finish(.failure(CodexLoginError.message("登录完成，但无法读取账号身份"))) }
        case let .authenticated(email):
            state = .finished
            promoteCredentials(authenticatedEmail: email)
        case let .failed(message):
            state = .finished
            finish(.failure(CodexLoginError.message(message)))
        }
    }

    private func promoteCredentials(authenticatedEmail: String) {
        do {
            try Self.promoteCredentials(
                from: stagingHomeURL,
                to: profile,
                authenticatedEmail: authenticatedEmail,
                fileManager: fileManager
            )
            finish(.success(()))
        } catch {
            finish(.failure(error))
        }
    }

    fileprivate static func promoteCredentials(
        from stagingHomeURL: URL,
        to profile: CodexProfile,
        authenticatedEmail: String,
        fileManager: FileManager
    ) throws {
        let stagedAuthURL = stagingHomeURL.appendingPathComponent("auth.json")
        let targetAuthURL = profile.codexHomeURL.appendingPathComponent("auth.json")
        guard let authData = try? Data(contentsOf: stagedAuthURL),
              let object = try? JSONSerialization.jsonObject(with: authData) as? [String: Any],
              let tokens = object["tokens"] as? [String: Any],
              tokens["access_token"] is String
        else { throw CodexLoginError.credentialsUnavailable }
        guard let identity = CodexOfficialProfileReader.credentialIdentity(fromAuthData: authData),
              identity.email == normalizedEmail(authenticatedEmail),
              profile.matchesRecordedAccount(email: identity.email),
              profile.lastSnapshot?.accountID == nil
                  || profile.lastSnapshot?.accountID == identity.accountID
        else { throw CodexLoginError.identityMismatch }

        let previousAuth = try? Data(contentsOf: targetAuthURL)
        do {
            try fileManager.createDirectory(
                at: profile.codexHomeURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: profile.codexHomePath)
            try authData.write(to: targetAuthURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: targetAuthURL.path)
        } catch {
            restoreAuth(previousAuth, at: targetAuthURL, fileManager: fileManager)
            throw error
        }
    }

    private static func normalizedEmail(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private func sendCancelIfPossible() {
        guard case let .waiting(loginID) = state else {
            state = .finished
            return
        }
        _ = writeJSON(["id": 4, "method": "account/login/cancel", "params": ["loginId": loginID]])
        state = .finished
    }

    private func writeJSON(_ object: [String: Any]) -> Bool {
        guard let inputHandle,
              let data = try? JSONSerialization.data(withJSONObject: object)
        else { return false }
        do {
            try inputHandle.write(contentsOf: data)
            try inputHandle.write(contentsOf: Data("\n".utf8))
            return true
        } catch {
            return false
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard !isFinished else { return }
        isFinished = true
        state = .finished
        timeout?.cancel()
        timeout = nil
        cleanup()
        DispatchQueue.main.async { [completion] in completion(result) }
    }

    private func cleanup() {
        try? inputHandle?.close()
        try? outputHandle?.close()
        if process?.isRunning == true { process?.terminate() }
        process = nil
        inputHandle = nil
        outputHandle = nil
        outputBuffer.removeAll(keepingCapacity: false)
        try? fileManager.removeItem(at: stagingHomeURL)
    }

    private static func restoreAuth(_ data: Data?, at url: URL, fileManager: FileManager) {
        if let data {
            try? data.write(to: url, options: .atomic)
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } else {
            try? fileManager.removeItem(at: url)
        }
    }
}

final class CodexAccountActions {
    enum PendingSwitchRecoveryOutcome: Equatable {
        case noPendingSwitch
        case restoredOriginalAuth(codexWasReopened: Bool)
        case originalAuthAlreadyPresent(codexWasReopened: Bool)
        case preservedExternalAuth
    }

    fileprivate struct PendingSwitchJournal: Codable, Equatable {
        let version: Int
        let createdAt: Date
        let originalAuth: Data?
        let targetAuthFingerprint: Data
        let originalCodexWasRunning: Bool

        init(
            originalAuth: AuthState,
            targetAuthFingerprint: Data,
            originalCodexWasRunning: Bool,
            createdAt: Date = Date()
        ) {
            version = 1
            self.createdAt = createdAt
            switch originalAuth {
            case .missing:
                self.originalAuth = nil
            case let .data(data):
                self.originalAuth = data
            }
            self.targetAuthFingerprint = targetAuthFingerprint
            self.originalCodexWasRunning = originalCodexWasRunning
        }

        var originalAuthState: AuthState {
            originalAuth.map(AuthState.data) ?? .missing
        }
    }

    fileprivate enum PendingSwitchRecoveryDecision: Equatable {
        case rollbackOriginal
        case originalAlreadyPresent
        case preserveExternal
    }

    private var loginSession: CodexLoginSession?
    private var warmUpProcess: Process?

    var isLoginRunning: Bool { loginSession != nil }
    var isWarmUpRunning: Bool { warmUpProcess?.isRunning == true }

    func login(
        profile: CodexProfile,
        completion: @escaping (Result<Void, Error>) -> Void
    ) throws {
        guard !isLoginRunning else { throw CodexLoginError.message("已有账号正在登录") }
        guard let executable = CodexExecutable.path() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let session = try CodexLoginSession(
            profile: profile,
            executableURL: URL(fileURLWithPath: executable)
        ) { [weak self] result in
            self?.loginSession = nil
            completion(result)
        }
        loginSession = session
        do {
            try session.start()
        } catch {
            loginSession = nil
            throw error
        }
    }

    func cancelLogin() {
        loginSession?.cancel()
    }

    func currentSystemAuthFingerprint(
        expectedEmail: String,
        expectedAccountID: String
    ) throws -> Data {
        let authURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")
        guard case let .data(data) = try Self.authState(at: authURL),
              let identity = CodexOfficialProfileReader.credentialIdentity(fromAuthData: data),
              identity.email == Self.normalizedEmail(expectedEmail),
              identity.accountID == expectedAccountID
        else {
            throw Self.switchError("当前 Codex 凭据身份与低额度触发账号不一致")
        }
        return Self.authFingerprint(data)
    }

    func recoverPendingSwitchIfNeeded(
        completion: @escaping (Result<PendingSwitchRecoveryOutcome, Error>) -> Void
    ) {
        let fileManager = FileManager.default
        let switchLock: Int32
        do {
            switchLock = try Self.acquireSwitchLock(fileManager: fileManager)
        } catch {
            completion(.failure(error))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            defer { Self.releaseSwitchLock(switchLock) }
            let result: Result<PendingSwitchRecoveryOutcome, Error>
            do {
                guard let journal = try Self.loadPendingSwitchJournal(fileManager: fileManager) else {
                    result = .success(.noPendingSwitch)
                    DispatchQueue.main.async { completion(result) }
                    return
                }
                let systemHome = fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent(".codex", isDirectory: true)
                let systemAuthURL = systemHome.appendingPathComponent("auth.json")
                let currentAuth = try Self.authState(at: systemAuthURL)
                switch Self.pendingSwitchRecoveryDecision(current: currentAuth, journal: journal) {
                case .preserveExternal:
                    guard Self.pendingSwitchRecoveryDecision(
                        current: try Self.authState(at: systemAuthURL),
                        journal: journal
                    ) == .preserveExternal else {
                        throw Self.switchError("清理恢复记录前凭据再次变化；已保留恢复记录")
                    }
                    try Self.clearPendingSwitchJournal(fileManager: fileManager)
                    result = .success(.preservedExternalAuth)
                case .originalAlreadyPresent:
                    let reopened = try Self.restoreOriginalCodexRuntimeIfNeeded(
                        originalAuth: journal.originalAuthState,
                        originalCodexWasRunning: journal.originalCodexWasRunning,
                        systemHome: systemHome
                    )
                    guard try Self.authState(at: systemAuthURL) == journal.originalAuthState else {
                        throw Self.switchError("补开原 Codex 期间凭据变化；已保留恢复记录且不覆盖")
                    }
                    try Self.clearPendingSwitchJournal(fileManager: fileManager)
                    result = .success(.originalAuthAlreadyPresent(codexWasReopened: reopened))
                case .rollbackOriginal:
                    guard let appURL = NSWorkspace.shared.urlForApplication(
                        withBundleIdentifier: "com.openai.codex"
                    ) else {
                        throw CocoaError(.fileNoSuchFile)
                    }
                    try Self.stopCodexGracefullyIfRunning(appURL: appURL)
                    guard Self.pendingSwitchRecoveryDecision(
                        current: try Self.authState(at: systemAuthURL),
                        journal: journal
                    ) == .rollbackOriginal else {
                        throw Self.switchError("恢复前凭据再次变化；已保留外部最新状态，不覆盖")
                    }
                    try fileManager.createDirectory(
                        at: systemHome,
                        withIntermediateDirectories: true,
                        attributes: [.posixPermissions: 0o700]
                    )
                    try Self.restoreAuth(journal.originalAuthState, at: systemAuthURL, fileManager: fileManager)
                    guard try Self.authState(at: systemAuthURL) == journal.originalAuthState else {
                        throw Self.switchError("启动恢复写回原账号后校验失败")
                    }
                    let reopened = try Self.restoreOriginalCodexRuntimeIfNeeded(
                        originalAuth: journal.originalAuthState,
                        originalCodexWasRunning: journal.originalCodexWasRunning,
                        systemHome: systemHome,
                        appURL: appURL
                    )
                    guard try Self.authState(at: systemAuthURL) == journal.originalAuthState else {
                        throw Self.switchError("原 Codex 恢复期间凭据变化；已保留恢复记录且不覆盖")
                    }
                    try Self.clearPendingSwitchJournal(fileManager: fileManager)
                    result = .success(.restoredOriginalAuth(codexWasReopened: reopened))
                }
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }

    func launchCodex(
        profile: CodexProfile,
        expectedSourceAuthFingerprint: Data? = nil,
        completion: @escaping (Error?) -> Void
    ) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") else {
            completion(CocoaError(.fileNoSuchFile))
            return
        }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "local.codex.account-manager").isEmpty else {
            completion(Self.switchError("旧版账号管理器仍在运行；为避免两个管理器同时改写登录，请先退出旧版"))
            return
        }

        let fileManager = FileManager.default
        let systemHome = fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        let systemAuthURL = systemHome.appendingPathComponent("auth.json")
        let targetAuthURL = profile.codexHomeURL.appendingPathComponent("auth.json")
        let switchLock: Int32
        do {
            switchLock = try Self.acquireSwitchLock(fileManager: fileManager)
        } catch {
            completion(error)
            return
        }

        let previousAuth: AuthState
        let targetAuth: Data?
        let targetIdentity: CodexCredentialIdentity?
        do {
            guard NSRunningApplication.runningApplications(withBundleIdentifier: "local.codex.account-manager").isEmpty else {
                throw Self.switchError("旧版账号管理器在切换准备期间启动；已取消写入")
            }
            guard try Self.loadPendingSwitchJournal(fileManager: fileManager) == nil else {
                throw Self.switchError("检测到未完成的账号切换；请先完成启动恢复")
            }
            previousAuth = try Self.authState(at: systemAuthURL)
            if let expectedSourceAuthFingerprint {
                guard case let .data(data) = previousAuth,
                      Self.authFingerprint(data) == expectedSourceAuthFingerprint
                else {
                    throw Self.switchError("低额度触发后当前 Codex 凭据已变化；已取消切换")
                }
            }
            if profile.isSystemProfile {
                targetAuth = nil
                targetIdentity = nil
            } else {
                let auth = try Self.validatedManagedAuth(at: targetAuthURL, profile: profile)
                targetAuth = auth
                targetIdentity = CodexOfficialProfileReader.credentialIdentity(fromAuthData: auth)
            }
        } catch {
            Self.releaseSwitchLock(switchLock)
            completion(error)
            return
        }

        let requiresRestart = targetAuth.map { previousAuth != .data($0) } ?? false
        let runningApplications = requiresRestart
            ? NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
            : []
        let previousProcessIDs = Set(runningApplications.map(\.processIdentifier))
        let originalCodexWasRunning: Bool
        do {
            if requiresRestart {
                let detectedProcessIDs = try Self.codexProcessIDs(appURL: appURL)
                originalCodexWasRunning = !runningApplications.isEmpty || !detectedProcessIDs.isEmpty
            } else {
                originalCodexWasRunning = false
            }
        } catch {
            Self.releaseSwitchLock(switchLock)
            completion(error)
            return
        }
        let preparedJournal: PendingSwitchJournal?
        do {
            if let targetAuth, requiresRestart {
                let pending = PendingSwitchJournal(
                    originalAuth: previousAuth,
                    targetAuthFingerprint: Self.authFingerprint(targetAuth),
                    originalCodexWasRunning: originalCodexWasRunning
                )
                try Self.persistPendingSwitchJournal(pending, fileManager: fileManager)
                preparedJournal = pending
            } else {
                preparedJournal = nil
            }
        } catch {
            Self.releaseSwitchLock(switchLock)
            completion(error)
            return
        }
        if requiresRestart, !runningApplications.allSatisfy({ $0.terminate() }) {
            try? Self.clearPendingSwitchJournal(fileManager: fileManager)
            Self.releaseSwitchLock(switchLock)
            completion(Self.switchError("Codex 拒绝了安全退出；账号未切换"))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            defer { Self.releaseSwitchLock(switchLock) }
            let journal = preparedJournal
            var journalPersisted = preparedJournal != nil
            do {
                if requiresRestart {
                    try Self.waitForGracefulCodexExit(appURL: appURL)
                }
                try fileManager.createDirectory(
                    at: systemHome,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
                if let targetAuth, requiresRestart {
                    guard NSRunningApplication.runningApplications(withBundleIdentifier: "local.codex.account-manager").isEmpty else {
                        throw Self.switchError("旧版账号管理器在写入前启动；已取消切换")
                    }
                    guard try Self.authState(at: systemAuthURL) == previousAuth else {
                        throw Self.switchError("切换期间 Codex 登录已被其他程序修改；已取消写入")
                    }
                    if let expectedSourceAuthFingerprint {
                        guard case let .data(data) = previousAuth,
                              Self.authFingerprint(data) == expectedSourceAuthFingerprint
                        else {
                            throw Self.switchError("低额度触发账号凭据已变化；已取消写入")
                        }
                    }
                    try targetAuth.write(to: systemAuthURL, options: .atomic)
                    try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: systemAuthURL.path)
                    guard try Data(contentsOf: systemAuthURL) == targetAuth else {
                        throw Self.switchError("目标账号凭据写入后校验失败")
                    }
                }
                if requiresRestart {
                    try Self.openCodex(at: appURL)
                    try Self.waitForNewCodexProcess(previousProcessIDs: previousProcessIDs)
                } else {
                    try Self.openCodex(at: appURL)
                }
                if let targetIdentity {
                    try Self.verifyActiveAccount(at: systemHome, expectedIdentity: targetIdentity)
                }
                if requiresRestart,
                   !Self.hasNewCodexProcess(previousProcessIDs: previousProcessIDs) {
                    throw Self.switchError("目标账号确认后 Codex 进程已退出")
                }
                if journalPersisted {
                    guard let journal,
                          Self.pendingSwitchRecoveryDecision(
                              current: try Self.authState(at: systemAuthURL),
                              journal: journal
                          ) == .rollbackOriginal
                    else {
                        throw Self.switchError("完成切换前凭据再次变化；不会覆盖外部最新状态")
                    }
                    try Self.clearPendingSwitchJournal(fileManager: fileManager)
                    journalPersisted = false
                }
                DispatchQueue.main.async { completion(nil) }
            } catch let switchFailure {
                var reportedError: Error = switchFailure
                if let journal, journalPersisted {
                    do {
                        switch Self.pendingSwitchRecoveryDecision(
                            current: try Self.authState(at: systemAuthURL),
                            journal: journal
                        ) {
                        case .originalAlreadyPresent:
                            break
                        case .preserveExternal:
                            throw Self.switchError("切换失败后凭据已被其他程序修改；已保留外部最新状态，不覆盖")
                        case .rollbackOriginal:
                            try Self.stopCodexGracefullyIfRunning(appURL: appURL)
                            guard Self.pendingSwitchRecoveryDecision(
                                current: try Self.authState(at: systemAuthURL),
                                journal: journal
                            ) == .rollbackOriginal else {
                                throw Self.switchError("恢复前凭据再次变化；已保留外部最新状态，不覆盖")
                            }
                            try Self.restoreAuth(previousAuth, at: systemAuthURL, fileManager: fileManager)
                            guard try Self.authState(at: systemAuthURL) == previousAuth else {
                                throw Self.switchError("原账号凭据回滚后校验失败")
                            }
                        }
                    } catch {
                        reportedError = Self.switchError(
                            "账号切换失败，且原凭据回滚未完成：\(error.localizedDescription)"
                        )
                    }
                }

                var originalStateRestored = false
                do {
                    originalStateRestored = try Self.authState(at: systemAuthURL) == previousAuth
                } catch {
                    reportedError = Self.switchError(
                        "\(reportedError.localizedDescription)；无法确认原凭据是否已恢复"
                    )
                }
                var originalRuntimeRestored = !originalCodexWasRunning
                if originalStateRestored, originalCodexWasRunning {
                    do {
                        _ = try Self.restoreOriginalCodexRuntimeIfNeeded(
                            originalAuth: previousAuth,
                            originalCodexWasRunning: true,
                            systemHome: systemHome,
                            appURL: appURL,
                            previousProcessIDs: previousProcessIDs
                        )
                        originalRuntimeRestored = true
                    } catch {
                        reportedError = Self.switchError(
                            "\(reportedError.localizedDescription)；原 Codex 也未能重新打开并确认身份"
                        )
                    }
                }
                if journalPersisted, originalStateRestored, originalRuntimeRestored {
                    do {
                        guard try Self.authState(at: systemAuthURL) == previousAuth else {
                            throw Self.switchError("清理恢复记录前凭据再次变化；已保留恢复记录")
                        }
                        try Self.clearPendingSwitchJournal(fileManager: fileManager)
                        journalPersisted = false
                    } catch {
                        reportedError = Self.switchError(
                            "\(reportedError.localizedDescription)；已恢复原账号，但未能清理恢复记录"
                        )
                    }
                }
                let finalError = reportedError
                DispatchQueue.main.async { completion(finalError) }
            }
        }
    }

    fileprivate enum AuthState: Equatable {
        case missing
        case data(Data)
    }

    private static func waitForGracefulCodexExit(appURL: URL) throws {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex").isEmpty,
               try codexProcessIDs(appURL: appURL).isEmpty {
                return
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        guard try codexProcessIDs(appURL: appURL).isEmpty else {
            throw switchError("Codex 未能在 10 秒内安全退出；账号未切换，且不会强制结束进程")
        }
        throw switchError("Codex 仍在运行；账号未切换")
    }

    private static func waitForNewCodexProcess(previousProcessIDs: Set<pid_t>) throws {
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if hasNewCodexProcess(previousProcessIDs: previousProcessIDs) { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        throw switchError("Codex 未在 8 秒内重新启动，原账号已恢复")
    }

    private static func hasNewCodexProcess(previousProcessIDs: Set<pid_t>) -> Bool {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.openai.codex")
            .contains { !$0.isTerminated && !previousProcessIDs.contains($0.processIdentifier) }
    }

    private static func stopCodexGracefullyIfRunning(appURL: URL) throws {
        let applications = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
        let processIDs = try codexProcessIDs(appURL: appURL)
        guard applications.allSatisfy({ $0.terminate() }) else {
            throw switchError("新 Codex 未能安全退出；为避免运行中身份错配，未恢复原凭据")
        }
        if !applications.isEmpty || !processIDs.isEmpty {
            try waitForGracefulCodexExit(appURL: appURL)
        }
    }

    private static func verifyActiveAccount(
        at codexHome: URL,
        expectedIdentity: CodexCredentialIdentity
    ) throws {
        let snapshot = CodexUsageReader().load(
            context: RuntimeLoadContext.live(codexHomeDirectory: codexHome)
        )
        let credentialIdentity = CodexOfficialProfileReader.credentialIdentity(codexHomeURL: codexHome)
        guard normalizedEmail(snapshot.account?.email) == expectedIdentity.email,
              credentialIdentity == expectedIdentity
        else {
            throw switchError("Codex 重新打开后未确认目标账号身份")
        }
    }

    private static func codexProcessIDs(appURL: URL) throws -> [pid_t] {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "\(NSRegularExpression.escapedPattern(for: appURL.path))/Contents/"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw switchError("无法启动 Codex 进程探测；已取消账号切换")
        }
        let data: Data
        do {
            data = try readAllBytes(
                from: output.fileHandleForReading.fileDescriptor,
                maximumBytes: 64 * 1_024,
                failureMessage: "无法读取 Codex 进程探测结果；已取消账号切换"
            )
        } catch {
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
            throw error
        }
        process.waitUntilExit()
        switch process.terminationStatus {
        case 1:
            return []
        case 0:
            break
        default:
            throw switchError(
                "Codex 进程探测异常退出；已取消账号切换",
                code: Int(process.terminationStatus)
            )
        }
        guard let outputText = String(data: data, encoding: .utf8), !outputText.isEmpty else {
            throw switchError("Codex 进程探测返回空结果；已取消账号切换")
        }
        var lines = outputText.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        guard !lines.isEmpty else {
            throw switchError("Codex 进程探测返回空结果；已取消账号切换")
        }
        return try lines.map { line in
            guard !line.isEmpty,
                  line.utf8.allSatisfy({ $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }),
                  let processID = pid_t(line),
                  processID > 0
            else {
                throw switchError("Codex 进程探测返回非数字 PID；已取消账号切换")
            }
            return processID
        }
    }

    private static func openCodex(at appURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [appURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw switchError("无法重新打开 Codex，原账号已恢复", code: Int(process.terminationStatus))
        }
    }

    fileprivate static func validatedManagedAuth(at url: URL, profile: CodexProfile) throws -> Data {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw switchError("无法读取目标账号凭据")
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = object["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty,
              let expectedAccountID = profile.lastSnapshot?.accountID,
              !expectedAccountID.isEmpty,
              let identity = CodexOfficialProfileReader.credentialIdentity(fromAuthData: data),
              identity.accountID == expectedAccountID,
              profile.matchesRecordedCredential(identity)
        else { throw switchError("目标账号凭据无效或身份与账号卡不一致") }
        return data
    }

    fileprivate static func authState(at url: URL) throws -> AuthState {
        do {
            return .data(try Data(contentsOf: url))
        } catch let error as NSError
            where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return .missing
        } catch {
            throw switchError("无法安全读取当前 Codex 凭据；已取消切换")
        }
    }

    fileprivate static func authFingerprint(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    fileprivate static func mayRestoreAuth(
        didWriteTarget: Bool,
        current: AuthState,
        target: Data
    ) -> Bool {
        didWriteTarget && current == .data(target)
    }

    fileprivate static func credentialEmail(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = object["tokens"] as? [String: Any]
        else { return nil }
        return normalizedEmail(CodexOfficialProfileReader.email(fromIDToken: tokens["id_token"] as? String))
    }

    private static func normalizedEmail(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private static func restoreAuth(_ state: AuthState, at url: URL, fileManager: FileManager) throws {
        switch state {
        case let .data(data):
            try data.write(to: url, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        case .missing:
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        }
    }

    private static func restoreOriginalCodexRuntimeIfNeeded(
        originalAuth: AuthState,
        originalCodexWasRunning: Bool,
        systemHome: URL,
        appURL suppliedAppURL: URL? = nil,
        previousProcessIDs suppliedProcessIDs: Set<pid_t>? = nil
    ) throws -> Bool {
        guard originalCodexWasRunning else { return false }
        guard let appURL = suppliedAppURL
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex")
        else { throw CocoaError(.fileNoSuchFile) }

        let applications = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex")
        let processIDs = try codexProcessIDs(appURL: appURL)
        if applications.isEmpty, !processIDs.isEmpty {
            throw switchError("仅检测到未受控的 Codex 辅助进程；未自动补开原 Codex")
        }

        let originalIdentity: CodexCredentialIdentity?
        if case let .data(data) = originalAuth {
            originalIdentity = CodexOfficialProfileReader.credentialIdentity(fromAuthData: data)
        } else {
            originalIdentity = nil
        }
        var previousProcessIDs = suppliedProcessIDs ?? []
        previousProcessIDs.formUnion(applications.map(\.processIdentifier))
        let needsFreshLaunch = applications.isEmpty || originalIdentity == nil
        if !applications.isEmpty, originalIdentity == nil {
            try stopCodexGracefullyIfRunning(appURL: appURL)
            guard try authState(at: systemHome.appendingPathComponent("auth.json")) == originalAuth else {
                throw switchError("重启原 Codex 前凭据变化；已保留恢复记录且不覆盖")
            }
        }

        var reopened = false
        if needsFreshLaunch {
            try openCodex(at: appURL)
            try waitForNewCodexProcess(previousProcessIDs: previousProcessIDs)
            reopened = true
        }
        if let identity = originalIdentity {
            try verifyActiveAccount(at: systemHome, expectedIdentity: identity)
        }
        return reopened
    }

    fileprivate static func pendingSwitchRecoveryDecision(
        current: AuthState,
        journal: PendingSwitchJournal
    ) -> PendingSwitchRecoveryDecision {
        if current == journal.originalAuthState { return .originalAlreadyPresent }
        if case let .data(data) = current,
           authFingerprint(data) == journal.targetAuthFingerprint {
            return .rollbackOriginal
        }
        return .preserveExternal
    }

    fileprivate static func persistPendingSwitchJournal(
        _ journal: PendingSwitchJournal,
        fileManager: FileManager,
        applicationSupportDirectory: URL? = nil
    ) throws {
        try validatePendingSwitchJournal(journal)
        guard try loadPendingSwitchJournal(
            fileManager: fileManager,
            applicationSupportDirectory: applicationSupportDirectory
        ) == nil else {
            throw switchError("已有未完成的账号切换恢复记录")
        }
        let directory = try accountManagerSupportDirectory(
            fileManager: fileManager,
            applicationSupportDirectory: applicationSupportDirectory,
            createIfNeeded: true
        )
        let url = directory.appendingPathComponent("pending-account-switch-v1.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(journal)
        try writeMode600AtomicallyWithoutReplacement(data, to: url)
        guard let loaded = try loadPendingSwitchJournal(
            fileManager: fileManager,
            applicationSupportDirectory: applicationSupportDirectory
        ),
        loaded.originalAuthState == journal.originalAuthState,
        loaded.targetAuthFingerprint == journal.targetAuthFingerprint,
        loaded.originalCodexWasRunning == journal.originalCodexWasRunning
        else { throw switchError("账号切换恢复记录写入后校验失败") }
    }

    fileprivate static func loadPendingSwitchJournal(
        fileManager: FileManager,
        applicationSupportDirectory: URL? = nil
    ) throws -> PendingSwitchJournal? {
        let directory = try accountManagerSupportDirectory(
            fileManager: fileManager,
            applicationSupportDirectory: applicationSupportDirectory,
            createIfNeeded: false
        )
        let url = directory.appendingPathComponent("pending-account-switch-v1.json")
        let descriptor = url.path.withCString {
            Darwin.open($0, O_RDONLY | O_NOFOLLOW)
        }
        guard descriptor >= 0 else {
            if errno == ENOENT { return nil }
            throw switchError("无法安全打开账号切换恢复记录", code: Int(errno))
        }
        defer { Darwin.close(descriptor) }

        var metadata = stat()
        guard Darwin.fstat(descriptor, &metadata) == 0 else {
            throw switchError("无法读取账号切换恢复记录属性", code: Int(errno))
        }
        guard (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
              (metadata.st_mode & mode_t(0o777)) == mode_t(0o600),
              metadata.st_size >= 0,
              metadata.st_size <= 1_048_576
        else { throw switchError("账号切换恢复记录类型、权限或大小不安全") }

        let data = try readAllBytes(
            from: descriptor,
            maximumBytes: 1_048_576,
            failureMessage: "无法读取账号切换恢复记录"
        )
        let journal: PendingSwitchJournal
        do {
            journal = try JSONDecoder().decode(PendingSwitchJournal.self, from: data)
        } catch {
            throw switchError("账号切换恢复记录损坏；已停止自动切换")
        }
        try validatePendingSwitchJournal(journal)
        return journal
    }

    fileprivate static func clearPendingSwitchJournal(
        fileManager: FileManager,
        applicationSupportDirectory: URL? = nil
    ) throws {
        let directory = try accountManagerSupportDirectory(
            fileManager: fileManager,
            applicationSupportDirectory: applicationSupportDirectory,
            createIfNeeded: false
        )
        let url = directory.appendingPathComponent("pending-account-switch-v1.json")
        let result = url.path.withCString { Darwin.unlink($0) }
        guard result == 0 else {
            if errno == ENOENT { return }
            throw switchError("无法清理账号切换恢复记录", code: Int(errno))
        }
        try syncDirectory(directory)
    }

    private static func validatePendingSwitchJournal(_ journal: PendingSwitchJournal) throws {
        guard journal.version == 1,
              journal.targetAuthFingerprint.count == SHA256.Digest.byteCount
        else { throw switchError("账号切换恢复记录版本或指纹无效") }
    }

    private static func writeMode600AtomicallyWithoutReplacement(_ data: Data, to url: URL) throws {
        let temporaryURL = url.deletingLastPathComponent().appendingPathComponent(
            ".\(url.lastPathComponent).\(UUID().uuidString).tmp"
        )
        var descriptor = temporaryURL.path.withCString {
            Darwin.open($0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else {
            throw switchError("无法创建账号切换恢复记录临时文件", code: Int(errno))
        }
        var installed = false
        defer {
            if descriptor >= 0 { Darwin.close(descriptor) }
            if !installed { temporaryURL.path.withCString { _ = Darwin.unlink($0) } }
        }

        guard Darwin.fchmod(descriptor, S_IRUSR | S_IWUSR) == 0 else {
            throw switchError("无法设置账号切换恢复记录权限", code: Int(errno))
        }
        try writeAllBytes(data, to: descriptor)
        guard Darwin.fsync(descriptor) == 0 else {
            throw switchError("无法持久化账号切换恢复记录", code: Int(errno))
        }
        let closeResult = Darwin.close(descriptor)
        descriptor = -1
        guard closeResult == 0 else {
            throw switchError("无法关闭账号切换恢复记录", code: Int(errno))
        }
        let renameResult = temporaryURL.path.withCString { sourcePath in
            url.path.withCString { destinationPath in
                Darwin.renamex_np(sourcePath, destinationPath, UInt32(RENAME_EXCL))
            }
        }
        guard renameResult == 0 else {
            throw switchError(
                errno == EEXIST ? "已有未完成的账号切换恢复记录" : "无法原子安装账号切换恢复记录",
                code: Int(errno)
            )
        }
        installed = true
        try syncDirectory(url.deletingLastPathComponent())
    }

    private static func writeAllBytes(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let written = Darwin.write(
                    descriptor,
                    buffer.baseAddress?.advanced(by: offset),
                    buffer.count - offset
                )
                if written < 0, errno == EINTR { continue }
                guard written > 0 else {
                    throw switchError("无法完整写入账号切换恢复记录", code: Int(errno))
                }
                offset += written
            }
        }
    }

    private static func readAllBytes(
        from descriptor: Int32,
        maximumBytes: Int,
        failureMessage: String
    ) throws -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4 * 1_024)
        while true {
            let count = buffer.withUnsafeMutableBytes {
                Darwin.read(descriptor, $0.baseAddress, $0.count)
            }
            if count < 0, errno == EINTR { continue }
            guard count >= 0 else { throw switchError(failureMessage, code: Int(errno)) }
            if count == 0 { return result }
            guard result.count <= maximumBytes - count else {
                throw switchError("\(failureMessage)；数据超过安全上限")
            }
            result.append(contentsOf: buffer[0..<count])
        }
    }

    private static func syncDirectory(_ directory: URL) throws {
        let descriptor = directory.path.withCString { Darwin.open($0, O_RDONLY | O_NOFOLLOW) }
        guard descriptor >= 0 else {
            throw switchError("无法打开恢复记录目录进行持久化", code: Int(errno))
        }
        defer { Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else {
            throw switchError("无法持久化恢复记录目录", code: Int(errno))
        }
    }

    private static func accountManagerSupportDirectory(
        fileManager: FileManager,
        applicationSupportDirectory: URL?,
        createIfNeeded: Bool
    ) throws -> URL {
        let support = applicationSupportDirectory
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent(
                "Library/Application Support",
                isDirectory: true
            )
        let directory = support.appendingPathComponent("CodexAccountManagerNext", isDirectory: true)
        if createIfNeeded {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        }
        return directory
    }

    fileprivate static func acquireSwitchLock(
        fileManager: FileManager,
        applicationSupportDirectory: URL? = nil
    ) throws -> Int32 {
        let directory = try accountManagerSupportDirectory(
            fileManager: fileManager,
            applicationSupportDirectory: applicationSupportDirectory,
            createIfNeeded: true
        )
        let descriptor = Darwin.open(
            directory.appendingPathComponent("account-switch.lock").path,
            O_CREAT | O_RDWR,
            S_IRUSR | S_IWUSR
        )
        guard descriptor >= 0 else { throw switchError("无法建立账号切换锁") }
        _ = Darwin.fchmod(descriptor, S_IRUSR | S_IWUSR)
        var lock = flock()
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)
        guard Darwin.fcntl(descriptor, F_SETLK, &lock) != -1 else {
            Darwin.close(descriptor)
            throw switchError("另一个账号切换正在进行")
        }
        return descriptor
    }

    fileprivate static func releaseSwitchLock(_ descriptor: Int32) {
        var lock = flock()
        lock.l_type = Int16(F_UNLCK)
        lock.l_whence = Int16(SEEK_SET)
        _ = Darwin.fcntl(descriptor, F_SETLK, &lock)
        Darwin.close(descriptor)
    }

    private static func switchError(_ message: String, code: Int = 1) -> NSError {
        NSError(
            domain: "CodexAccountManagerNext.AccountSwitch",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
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

enum CodexAccountLoginProtocolSelfTest {
    static func run() -> Bool {
        let started = CodexLoginProtocolParser.event(
            from: [
                "id": 2,
                "result": [
                    "type": "chatgpt",
                    "loginId": "login-1",
                    "authUrl": "https://auth.openai.com/example"
                ]
            ],
            state: .starting
        )
        let wrongCompletion = CodexLoginProtocolParser.event(
            from: [
                "method": "account/login/completed",
                "params": ["loginId": "other-login", "success": true]
            ],
            state: .waiting(loginID: "login-1")
        )
        let completed = CodexLoginProtocolParser.event(
            from: [
                "method": "account/login/completed",
                "params": ["loginId": "login-1", "success": true]
            ],
            state: .waiting(loginID: "login-1")
        )
        let authenticated = CodexLoginProtocolParser.event(
            from: [
                "id": 3,
                "result": [
                    "requiresOpenaiAuth": true,
                    "account": ["type": "chatgpt", "email": "person@example.com"]
                ]
            ],
            state: .readingAccount
        )
        let failure = CodexLoginProtocolParser.event(
            from: [
                "method": "account/login/completed",
                "params": ["loginId": "login-2", "success": false, "error": "cancelled"]
            ],
            state: .waiting(loginID: "login-2")
        )
        let lateCompletion = CodexLoginProtocolParser.event(
            from: [
                "method": "account/login/completed",
                "params": ["loginId": "login-2", "success": true]
            ],
            state: .finished
        )
        guard started == .loginStarted(
            loginID: "login-1",
            authURL: "https://auth.openai.com/example"
        ),
        wrongCompletion == .none,
        completed == .loginCompleted,
        authenticated == .authenticated(email: "person@example.com"),
        failure == .failed("cancelled"),
        lateCompletion == .none else {
            print("account login protocol self-test failed")
            return false
        }

        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("codex-login-self-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        do {
            let staging = root.appendingPathComponent("staging", isDirectory: true)
            let target = root.appendingPathComponent("target", isDirectory: true)
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
            let loginPayload = Data(#"{"email":"person@example.com"}"#.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            let stagedAuth = Data(
                #"{"tokens":{"access_token":"test-only","id_token":"e30.\#(loginPayload).sig","account_id":"acct-person"}}"#.utf8
            )
            let originalAuth = Data(#"{"original":true}"#.utf8)
            try stagedAuth.write(to: staging.appendingPathComponent("auth.json"))
            try originalAuth.write(to: target.appendingPathComponent("auth.json"))
            let profile = CodexProfile(
                id: "test",
                name: "person@example.com",
                codexHomePath: target.path,
                isSystemProfile: false,
                createdAt: Date(timeIntervalSince1970: 0),
                lastSnapshot: CodexAccountSnapshot(
                    accountType: "chatgpt",
                    planType: nil,
                    email: "person@example.com",
                    accountID: "acct-person",
                    limitId: nil,
                    limitName: nil,
                    fiveHour: nil,
                    sevenDay: nil,
                    monthly: nil,
                    fetchedAt: Date(timeIntervalSince1970: 0),
                    appServerVersion: nil
                )
            )
            do {
                try CodexLoginSession.promoteCredentials(
                    from: staging,
                    to: profile,
                    authenticatedEmail: "other@example.com",
                    fileManager: fileManager
                )
                print("account login protocol self-test failed: identity mismatch was accepted")
                return false
            } catch {}
            guard try Data(contentsOf: target.appendingPathComponent("auth.json")) == originalAuth else {
                print("account login protocol self-test failed: identity mismatch overwrote auth")
                return false
            }
            try CodexLoginSession.promoteCredentials(
                from: staging,
                to: profile,
                authenticatedEmail: "PERSON@example.com",
                fileManager: fileManager
            )
            guard try Data(contentsOf: target.appendingPathComponent("auth.json")) == stagedAuth else {
                print("account login protocol self-test failed: verified auth was not promoted")
                return false
            }
        } catch {
            print("account login protocol self-test failed: \(error)")
            return false
        }
        print("account login protocol self-test passed")
        return true
    }
}

enum CodexAccountSwitchSafetySelfTest {
    static func run() -> Bool {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("codex-account-switch-safety-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }
        do {
            let home = root.appendingPathComponent("profile", isDirectory: true)
            try fileManager.createDirectory(at: home, withIntermediateDirectories: true)
            let payload = Data(#"{"email":"person@example.com"}"#.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            let auth = Data(
                #"{"tokens":{"access_token":"test-only","id_token":"e30.\#(payload).sig","account_id":"acct-person"}}"#.utf8
            )
            let authURL = home.appendingPathComponent("auth.json")
            try auth.write(to: authURL)
            let profile = CodexProfile(
                id: "test",
                name: "person@example.com",
                codexHomePath: home.path,
                isSystemProfile: false,
                createdAt: Date(timeIntervalSince1970: 0),
                lastSnapshot: CodexAccountSnapshot(
                    accountType: "chatgpt",
                    planType: "plus",
                    email: "person@example.com",
                    accountID: "acct-person",
                    limitId: nil,
                    limitName: nil,
                    fiveHour: nil,
                    sevenDay: nil,
                    monthly: nil,
                    fetchedAt: Date(timeIntervalSince1970: 0),
                    appServerVersion: nil
                )
            )
            guard try CodexAccountActions.validatedManagedAuth(at: authURL, profile: profile) == auth else {
                print("Codex account switch safety self-test failed: valid identity rejected")
                return false
            }
            var mismatched = profile
            mismatched.lastSnapshot = CodexAccountSnapshot(
                accountType: "chatgpt",
                planType: "plus",
                email: "other@example.com",
                accountID: "acct-person",
                limitId: nil,
                limitName: nil,
                fiveHour: nil,
                sevenDay: nil,
                monthly: nil,
                fetchedAt: Date(timeIntervalSince1970: 0),
                appServerVersion: nil
            )
            guard (try? CodexAccountActions.validatedManagedAuth(at: authURL, profile: mismatched)) == nil else {
                print("Codex account switch safety self-test failed: mismatched identity accepted")
                return false
            }
            let descriptor = try CodexAccountActions.acquireSwitchLock(
                fileManager: fileManager,
                applicationSupportDirectory: root
            )
            CodexAccountActions.releaseSwitchLock(descriptor)
            let attributes = try fileManager.attributesOfItem(
                atPath: root.appendingPathComponent("CodexAccountManagerNext/account-switch.lock").path
            )
            guard (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600 else {
                print("Codex account switch safety self-test failed: lock permissions")
                return false
            }
            guard try CodexAccountActions.authState(at: authURL) == .data(auth),
                  try CodexAccountActions.authState(at: root.appendingPathComponent("missing-auth.json")) == .missing,
                  CodexAccountActions.authFingerprint(auth) == CodexAccountActions.authFingerprint(auth),
                  CodexAccountActions.authFingerprint(auth) != CodexAccountActions.authFingerprint(Data("different".utf8)),
                  CodexAccountActions.mayRestoreAuth(
                      didWriteTarget: true,
                      current: .data(auth),
                      target: auth
                  ),
                  !CodexAccountActions.mayRestoreAuth(
                      didWriteTarget: true,
                      current: .data(Data("external-change".utf8)),
                      target: auth
                  ),
                  !CodexAccountActions.mayRestoreAuth(
                      didWriteTarget: false,
                      current: .data(auth),
                      target: auth
                  )
            else {
                print("Codex account switch safety self-test failed: auth state, fingerprint, or rollback ownership")
                return false
            }
            do {
                _ = try CodexAccountActions.authState(at: home)
                print("Codex account switch safety self-test failed: unreadable auth treated as missing")
                return false
            } catch {}
            let originalAuth = Data(#"{"tokens":{"original":true}}"#.utf8)
            let pending = CodexAccountActions.PendingSwitchJournal(
                originalAuth: .data(originalAuth),
                targetAuthFingerprint: CodexAccountActions.authFingerprint(auth),
                originalCodexWasRunning: true,
                createdAt: Date(timeIntervalSince1970: 0)
            )
            try CodexAccountActions.persistPendingSwitchJournal(
                pending,
                fileManager: fileManager,
                applicationSupportDirectory: root
            )
            let journalURL = root.appendingPathComponent(
                "CodexAccountManagerNext/pending-account-switch-v1.json"
            )
            let journalAttributes = try fileManager.attributesOfItem(atPath: journalURL.path)
            guard (journalAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600,
                  try CodexAccountActions.loadPendingSwitchJournal(
                      fileManager: fileManager,
                      applicationSupportDirectory: root
                  ) == pending,
                  CodexAccountActions.pendingSwitchRecoveryDecision(
                      current: .data(auth),
                      journal: pending
                  ) == .rollbackOriginal,
                  CodexAccountActions.pendingSwitchRecoveryDecision(
                      current: .data(originalAuth),
                      journal: pending
                  ) == .originalAlreadyPresent,
                  CodexAccountActions.pendingSwitchRecoveryDecision(
                      current: .data(Data("external-change".utf8)),
                      journal: pending
                  ) == .preserveExternal
            else {
                print("Codex account switch safety self-test failed: journal decision or permissions")
                return false
            }
            try CodexAccountActions.clearPendingSwitchJournal(
                fileManager: fileManager,
                applicationSupportDirectory: root
            )
            guard !fileManager.fileExists(atPath: journalURL.path),
                  try CodexAccountActions.loadPendingSwitchJournal(
                      fileManager: fileManager,
                      applicationSupportDirectory: root
                  ) == nil
            else {
                print("Codex account switch safety self-test failed: journal cleanup")
                return false
            }
            print("Codex account switch safety self-test passed")
            return true
        } catch {
            print("Codex account switch safety self-test failed: \(error)")
            return false
        }
    }
}
