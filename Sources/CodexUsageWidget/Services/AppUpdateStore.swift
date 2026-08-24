import AppKit
import Combine
import Foundation

final class AppUpdateStore: ObservableObject {
    @Published private(set) var result: AppUpdateResult = .idle()
    @Published private(set) var isChecking = false

    private let settings: AppSettings
    private let checker: GitHubReleaseUpdateChecker
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: AppSettings,
        checker: GitHubReleaseUpdateChecker = GitHubReleaseUpdateChecker()
    ) {
        self.settings = settings
        self.checker = checker
        observeSettings()
    }

    func startAutomaticCheck() {
        guard settings.automaticUpdateChecksEnabled else {
            result = disabledResult()
            return
        }
        check(force: false)
    }

    func checkNow() {
        check(force: true)
    }

    func openPreferredUpdateURL() {
        guard let url = result.preferredOpenURL else { return }
        NSWorkspace.shared.open(url)
    }

    func skipCurrentAvailableVersion() {
        guard let version = result.latestVersionLabel else { return }
        settings.skipUpdateVersion(version)
        if result.status == .updateAvailable {
            result = AppUpdateResult(
                status: .upToDate,
                checkedAt: result.checkedAt,
                currentVersion: result.currentVersion,
                latestRelease: result.latestRelease,
                preferredAsset: result.preferredAsset,
                errorMessage: nil
            )
        }
    }

    private func check(force: Bool) {
        guard !isChecking else { return }
        isChecking = true
        result = AppUpdateResult(
            status: .checking,
            checkedAt: Date(),
            currentVersion: AppVersion.current(),
            latestRelease: result.latestRelease,
            preferredAsset: result.preferredAsset,
            errorMessage: nil
        )

        checker.check(
            currentVersion: AppVersion.current(),
            includePrereleases: true,
            force: force
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.apply(result, force: force)
            }
        }
    }

    private func apply(_ nextResult: AppUpdateResult, force: Bool) {
        isChecking = false
        if !force,
           nextResult.status == .updateAvailable,
           nextResult.latestVersionLabel == settings.skippedUpdateVersion {
            result = AppUpdateResult(
                status: .upToDate,
                checkedAt: nextResult.checkedAt,
                currentVersion: nextResult.currentVersion,
                latestRelease: nextResult.latestRelease,
                preferredAsset: nextResult.preferredAsset,
                errorMessage: nil
            )
            return
        }
        result = nextResult
    }

    private func observeSettings() {
        settings.$automaticUpdateChecksEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.startAutomaticCheck()
                } else {
                    self.isChecking = false
                    self.result = self.disabledResult()
                }
            }
            .store(in: &cancellables)
    }

    private func disabledResult() -> AppUpdateResult {
        AppUpdateResult(
            status: .disabled,
            checkedAt: Date(),
            currentVersion: AppVersion.current(),
            latestRelease: result.latestRelease,
            preferredAsset: result.preferredAsset,
            errorMessage: nil
        )
    }
}
