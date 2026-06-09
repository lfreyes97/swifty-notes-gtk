import Foundation

/// Detects whether the running process lives inside an application
/// sandbox (Flatpak or Snap). Used to decide if a failed network probe
/// means "this install can never reach the network" (sandbox without
/// network permission) versus "the user is merely offline right now"
/// (host install on a plane) — only the former should hide network
/// affordances like the "Check for Updates…" menu entry.
enum AppSandbox {
    /// Evaluated once; the sandbox cannot change mid-process.
    static let isSandboxed: Bool = detect(
        environment: ProcessInfo.processInfo.environment,
        flatpakInfoExists: FileManager.default.fileExists(atPath: "/.flatpak-info"),
    )

    /// Pure decision core, injectable for tests. Flatpak sets `FLATPAK_ID`
    /// and mounts `/.flatpak-info` inside every sandbox; Snap sets `SNAP`
    /// to the mounted snap path.
    static func detect(
        environment: [String: String],
        flatpakInfoExists: Bool,
    ) -> Bool {
        if environment["FLATPAK_ID"]?.isEmpty == false { return true }
        if environment["SNAP"]?.isEmpty == false { return true }
        return flatpakInfoExists
    }
}
