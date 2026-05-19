import Foundation

/// Parsed result of the command-line arguments that the launcher hands to
/// the application layer. Only flags consumed by the app itself live here;
/// anything we don't recognise is preserved in `passthroughArguments` so
/// GTK / glib continue to see their own flags (`--gtk-debug`, etc.) and
/// positional document paths still reach the activate / open handlers.
struct AppLaunchOptions: Equatable {
    /// When set via `--force-update-available`, the update checker reports
    /// `updateAvailable` even if the running build is at or ahead of the
    /// latest GitHub release. Used to exercise the banner without having
    /// to ship a new release first.
    let forceUpdateAvailable: Bool
    let passthroughArguments: [String]

    static let forceUpdateAvailableFlag = "--force-update-available"

    static func parse(arguments: [String]) -> AppLaunchOptions {
        var passthrough: [String] = []
        var force = false
        for arg in arguments {
            if arg == forceUpdateAvailableFlag {
                force = true
            } else {
                passthrough.append(arg)
            }
        }
        return AppLaunchOptions(
            forceUpdateAvailable: force,
            passthroughArguments: passthrough,
        )
    }
}
