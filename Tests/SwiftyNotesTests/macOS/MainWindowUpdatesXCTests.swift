#if os(macOS)
import Adwaita
import Foundation
@testable import SwiftyNotes
import XCTest

/// XCTest mirror of `MainWindowUpdatesTests`. Swift Testing's MainActor
/// integration interacts badly with the GTK4-Quartz autorelease pool
/// on macOS — creating multiple `MainWindow` instances inside a single
/// `swift-testing`-driven process crashes with "autorelease pool page
/// corrupted". Running the same assertions under XCTest (which manages
/// its own per-test autorelease scope) avoids the crash.
final class MainWindowUpdatesXCTests: XCTestCase {
    @MainActor func test_updateAvailable_result_shows_banner_and_records_release_url() throws {
        let window = try makeWindow(appID: "me.spaceinbox.swiftynotes.tests.update.available")
        let releaseURL = URL(string: "https://github.com/makoni/swifty-notes-gtk/releases/tag/v1.2.4")!

        window.handleUpdateCheckResult(.updateAvailable(version: "1.2.4", releaseURL: releaseURL), manual: false)

        XCTAssertTrue(window.updateBanner.isVisible)
        XCTAssertEqual(window.pendingUpdateReleaseURL, releaseURL)
    }

    @MainActor func test_upToDate_result_leaves_banner_hidden() throws {
        let window = try makeWindow(appID: "me.spaceinbox.swiftynotes.tests.update.uptodate")

        window.handleUpdateCheckResult(.upToDate, manual: false)

        XCTAssertFalse(window.updateBanner.isVisible)
        XCTAssertNil(window.pendingUpdateReleaseURL)
    }

    @MainActor func test_error_result_leaves_banner_hidden() throws {
        let window = try makeWindow(appID: "me.spaceinbox.swiftynotes.tests.update.error")

        window.handleUpdateCheckResult(.error(message: "network unreachable"), manual: true)

        XCTAssertFalse(window.updateBanner.isVisible)
        XCTAssertNil(window.pendingUpdateReleaseURL)
    }

    @MainActor func test_update_button_opens_release_url_through_injected_opener() throws {
        let opened = MainActorURLBox()
        let window = try makeWindow(
            appID: "me.spaceinbox.swiftynotes.tests.update.openrelease",
            directoryOpener: { url in opened.value = url },
        )
        let releaseURL = URL(string: "https://github.com/makoni/swifty-notes-gtk/releases/tag/v9.9.9")!
        window.handleUpdateCheckResult(.updateAvailable(version: "9.9.9", releaseURL: releaseURL), manual: false)

        window.openPendingUpdateReleasePage()

        XCTAssertEqual(opened.value, releaseURL)
    }

    @MainActor func test_update_button_is_noop_before_any_successful_check() throws {
        let opened = MainActorURLBox()
        let window = try makeWindow(
            appID: "me.spaceinbox.swiftynotes.tests.update.openrelease.nil",
            directoryOpener: { url in opened.value = url },
        )

        window.openPendingUpdateReleasePage()

        XCTAssertNil(opened.value)
    }

    @MainActor func test_force_update_available_promotes_equal_remote_version_via_handle_result() throws {
        let window = try makeWindow(
            appID: "me.spaceinbox.swiftynotes.tests.update.forceflag",
            forceUpdateAvailable: true,
        )
        let releaseURL = URL(string: "https://github.com/makoni/swifty-notes-gtk/releases/tag/v0.0.1")!

        window.handleUpdateCheckResult(.updateAvailable(version: "0.0.1", releaseURL: releaseURL), manual: false)

        XCTAssertTrue(window.updateBanner.isVisible)
        XCTAssertEqual(window.pendingUpdateReleaseURL, releaseURL)
    }

    @MainActor private func makeWindow(
        appID: String,
        forceUpdateAvailable: Bool = false,
        directoryOpener: @escaping (URL) throws -> Void = { _ in },
    ) throws -> MainWindow {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let app = Application(id: appID)
        try app.register()
        return MainWindow(
            application: app,
            state: AppState(),
            stateStore: WorkspaceStateStore(
                stateFileURL: temp.appendingPathComponent("workspace.json", isDirectory: false),
            ),
            repository: NotesRepository(notesDirectory: temp),
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
            forceUpdateAvailable: forceUpdateAvailable,
            directoryOpener: directoryOpener,
        )
    }
}

@MainActor
private final class MainActorURLBox {
    var value: URL?
}
#endif
