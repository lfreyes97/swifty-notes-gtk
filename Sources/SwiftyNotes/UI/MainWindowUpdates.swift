import Adwaita
import Foundation

extension MainWindow {
    /// Default fetcher used at runtime — hits the GitHub releases API
    /// for `makoni/swifty-notes-gtk`. Tests inject their own closure via
    /// the `fetcher` parameter on ``checkForUpdates(manual:fetcher:)``.
    static let defaultUpdateFetcher: @Sendable () async throws -> GitHubLatestRelease =
        UpdateChecker.gitHubReleasesFetcher(
            owner: "makoni",
            repo: "swifty-notes-gtk",
        )

    /// Kicks off an async update check and updates the banner / toast on
    /// completion. `manual` controls how feedback is surfaced for
    /// non-update outcomes: silent on launch checks, but a toast for the
    /// "Check for Updates…" menu action so the user gets confirmation
    /// that the click did something.
    func checkForUpdates(
        manual: Bool,
        fetcher: @escaping @Sendable () async throws -> GitHubLatestRelease = MainWindow.defaultUpdateFetcher,
    ) {
        let checker = UpdateChecker(
            currentVersion: BuildInfo.version,
            forceUpdateAvailable: forceUpdateAvailable,
            fetchLatestRelease: fetcher,
        )
        Task { [weak self] in
            let result = await checker.check()
            await MainActor.run { [weak self] in
                self?.handleUpdateCheckResult(result, manual: manual)
            }
        }
    }

    func handleUpdateCheckResult(_ result: UpdateCheckResult, manual: Bool) {
        switch result {
        case let .updateAvailable(version, releaseURL):
            pendingUpdateReleaseURL = releaseURL
            updateBanner.show(version: version)
        case .upToDate:
            if manual {
                toastOverlay.addToast(Toast(title: "Swifty Notes is up to date."))
            }
        case let .error(message):
            if manual {
                toastOverlay.addToast(Toast(title: "Could not check for updates: \(message)"))
            }
        }
    }

    func openPendingUpdateReleasePage() {
        guard let url = pendingUpdateReleaseURL else { return }
        do {
            try directoryOpener(url)
        } catch {
            toastOverlay.addToast(Toast(title: "Could not open release page: \(error.localizedDescription)"))
        }
    }
}
