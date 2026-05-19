import Foundation

enum BuildInfo {
    private static let defaultVersion = "1.1.6"

    /// Source of truth resolution order:
    /// 1. `SWIFTY_NOTES_VERSION` env var — Linux release flow exports
    ///    this via `packaging/release/install-user.sh`, and developers
    ///    can override locally for testing the update checker.
    /// 2. `CFBundleShortVersionString` from the surrounding .app's
    ///    Info.plist — CI passes `MARKETING_VERSION` to xcodebuild for
    ///    the macOS release pipeline, so the bundle is the authoritative
    ///    version source there. Without this step the in-app About /
    ///    update-checker would read `defaultVersion` even when the .app
    ///    itself was correctly stamped, leading to inconsistent UI
    ///    versus the Finder Get Info value.
    /// 3. `defaultVersion` for unbundled `swift run` developer builds
    ///    where neither of the above is set.
    static var version: String {
        if let env = ProcessInfo.processInfo.environment["SWIFTY_NOTES_VERSION"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !env.isEmpty
        {
            return env
        }
        if let bundled = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let trimmed = bundled.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return defaultVersion
    }
}
