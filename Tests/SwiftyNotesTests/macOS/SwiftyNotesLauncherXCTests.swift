#if os(macOS)
import Adwaita
import Foundation
@testable import SwiftyNotes
import XCTest

final class SwiftyNotesLauncherXCTests: XCTestCase {
    @MainActor func test_app_controller_open_documents_creates_external_windows_without_main_window() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

        let firstURL = temp.appendingPathComponent("first.md", isDirectory: false)
        let secondURL = temp.appendingPathComponent("second.md", isDirectory: false)
        try "# First\n".write(to: firstURL, atomically: true, encoding: .utf8)
        try "# Second\n".write(to: secondURL, atomically: true, encoding: .utf8)

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.desktop-open")
        try app.register()

        let controller = AppController(
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            appSettingsStore: AppSettingsStore(
                settingsFileURL: temp
                    .appendingPathComponent("config", isDirectory: true)
                    .appendingPathComponent("settings.json", isDirectory: false),
            ),
            allowsWindowPresentation: false,
        )

        controller.openDocuments(at: [firstURL, secondURL], application: app)

        XCTAssertFalse(controller.debugHasMainWindow)
        XCTAssertTrue(controller.debugExternalDocumentFileURLs == [
            firstURL.standardizedFileURL,
            secondURL.standardizedFileURL,
        ])
    }

    func test_application_id_falls_back_to_AppIdentity_outside_override() {
        let resolved = SwiftyNotesLauncher.resolveApplicationID(
            override: nil,
            env: ["PATH": "/usr/bin"],
        )
        XCTAssertTrue(resolved == AppIdentity.identifier)
    }

    func test_application_id_honors_SWIFTY_NOTES_APP_ID_override_regardless_of_snap_environment() {
        let resolved = SwiftyNotesLauncher.resolveApplicationID(
            override: "me.example.custom",
            env: [
                "SNAP_INSTANCE_NAME": "swifty-notes",
                "SNAP_NAME": "swifty-notes",
            ],
        )
        XCTAssertTrue(resolved == "me.example.custom")
    }

    func test_application_id_stays_canonical_even_under_snap_environment() {
        let resolved = SwiftyNotesLauncher.resolveApplicationID(
            override: nil,
            env: [
                "SNAP_INSTANCE_NAME": "swifty-notes",
                "SNAP_NAME": "swifty-notes",
            ],
        )
        XCTAssertTrue(resolved == AppIdentity.identifier)
    }

    func test_application_id_ignores_empty_whitespace_override() {
        let resolved = SwiftyNotesLauncher.resolveApplicationID(
            override: "   ",
            env: [:],
        )
        XCTAssertTrue(resolved == AppIdentity.identifier)
    }

    func test_application_flags_default_to_handlesOpen_outside_a_snap_environment() {
        let flags = SwiftyNotesLauncher.resolveApplicationFlags(env: ["PATH": "/usr/bin"])
        XCTAssertTrue(flags == .handlesOpen)
    }

    func test_application_flags_add_nonUnique_under_strict_confined_snap_to_skip_session_bus_binding() {
        let flags = SwiftyNotesLauncher.resolveApplicationFlags(env: [
            "SNAP": "/snap/swifty-notes/current",
            "SNAP_NAME": "swifty-notes",
            "SNAP_INSTANCE_NAME": "swifty-notes",
        ])
        XCTAssertTrue(flags.contains(.handlesOpen))
        XCTAssertTrue(flags.contains(.nonUnique))
    }

    func test_application_flags_add_nonUnique_even_when_only_SNAP_env_is_set() {
        let flags = SwiftyNotesLauncher.resolveApplicationFlags(env: [
            "SNAP": "/snap/swifty-notes/current",
        ])
        XCTAssertTrue(flags.contains(.nonUnique))
    }

    @MainActor func test_app_controller_open_documents_reuses_existing_external_window_for_same_file() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

        let fileURL = temp.appendingPathComponent("reused.md", isDirectory: false)
        try "# Reused\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.desktop-open-reuse")
        try app.register()

        let controller = AppController(
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            appSettingsStore: AppSettingsStore(
                settingsFileURL: temp
                    .appendingPathComponent("config", isDirectory: true)
                    .appendingPathComponent("settings.json", isDirectory: false),
            ),
            allowsWindowPresentation: false,
        )

        controller.openDocuments(at: [fileURL], application: app)
        let firstWindowID = controller.debugExternalWindowIdentifier(for: fileURL)

        controller.openDocuments(at: [fileURL], application: app)
        let secondWindowID = controller.debugExternalWindowIdentifier(for: fileURL)

        XCTAssertTrue(controller.debugExternalDocumentFileURLs == [fileURL.standardizedFileURL])
        XCTAssertNotNil(firstWindowID)
        XCTAssertTrue(firstWindowID == secondWindowID)
    }
}
#endif
