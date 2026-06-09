import Foundation
@testable import SwiftyNotes
import Testing

struct AppSandboxTests {
    @Test
    func `flatpak is detected via FLATPAK_ID`() {
        #expect(AppSandbox.detect(
            environment: ["FLATPAK_ID": "me.spaceinbox.swiftynotes"],
            flatpakInfoExists: false,
        ) == true)
    }

    @Test
    func `flatpak is detected via the flatpak-info file when the env var is absent`() {
        // Some launch paths (e.g. `flatpak run --command=sh` children) can
        // lose the env var; /.flatpak-info is always present in the sandbox.
        #expect(AppSandbox.detect(
            environment: [:],
            flatpakInfoExists: true,
        ) == true)
    }

    @Test
    func `snap is detected via the SNAP env var`() {
        #expect(AppSandbox.detect(
            environment: ["SNAP": "/snap/swifty-notes/184"],
            flatpakInfoExists: false,
        ) == true)
    }

    @Test
    func `a plain host install is not sandboxed`() {
        #expect(AppSandbox.detect(
            environment: ["HOME": "/home/user", "PATH": "/usr/bin"],
            flatpakInfoExists: false,
        ) == false)
    }

    @Test
    func `empty env values do not count as sandboxed`() {
        #expect(AppSandbox.detect(
            environment: ["FLATPAK_ID": "", "SNAP": ""],
            flatpakInfoExists: false,
        ) == false)
    }
}
