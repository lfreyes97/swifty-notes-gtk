import Foundation
@testable import SwiftyNotes
import Testing

struct AppSandboxTests {
    @Test("Flatpak is detected via FLATPAK_ID")
    func detectsFlatpakViaEnvironment() {
        #expect(AppSandbox.detect(
            environment: ["FLATPAK_ID": "me.spaceinbox.swiftynotes"],
            flatpakInfoExists: false,
        ) == true)
    }

    @Test("Flatpak is detected via the flatpak-info file when the env var is absent")
    func detectsFlatpakViaInfoFile() {
        // Some launch paths (e.g. `flatpak run --command=sh` children) can
        // lose the env var; /.flatpak-info is always present in the sandbox.
        #expect(AppSandbox.detect(
            environment: [:],
            flatpakInfoExists: true,
        ) == true)
    }

    @Test("Snap is detected via the SNAP env var")
    func detectsSnapViaEnvironment() {
        #expect(AppSandbox.detect(
            environment: ["SNAP": "/snap/swifty-notes/184"],
            flatpakInfoExists: false,
        ) == true)
    }

    @Test("A plain host install is not sandboxed")
    func hostInstallIsNotSandboxed() {
        #expect(AppSandbox.detect(
            environment: ["HOME": "/home/user", "PATH": "/usr/bin"],
            flatpakInfoExists: false,
        ) == false)
    }

    @Test("Empty env values do not count as sandboxed")
    func emptyEnvironmentValuesDoNotCount() {
        #expect(AppSandbox.detect(
            environment: ["FLATPAK_ID": "", "SNAP": ""],
            flatpakInfoExists: false,
        ) == false)
    }
}
