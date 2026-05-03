#if os(macOS)
import Adwaita
import Foundation
@testable import SwiftyNotes
import XCTest

final class ExternalDocumentWindowXCTests: XCTestCase {
    @MainActor func test_external_document_window_loads_markdown_file_and_autosaves_edits() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

        let fileURL = temp.appendingPathComponent("Opened.md", isDirectory: false)
        try "# Opened\n\nBody".write(to: fileURL, atomically: true, encoding: .utf8)

        let autosaveScheduler = TestMainActorScheduler()
        let app = Application(id: "me.spaceinbox.swiftynotes.tests.externaldocument")
        try app.register()

        let window = try ExternalDocumentWindow(
            application: app,
            fileURL: fileURL,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(taskScheduler: autosaveScheduler.schedule(after:operation:)),
            autosaveDelay: .milliseconds(40),
        )

        window.present()

        XCTAssertTrue(window.debugViewMode == .split)
        XCTAssertTrue(window.debugEditorText == "# Opened\n\nBody")
        XCTAssertTrue(window.debugPreviewText.contains("Opened"))
        XCTAssertTrue(window.debugOverflowMenuSectionTitles == ["Document"])
        XCTAssertTrue(window.debugOverflowMenuItemsBySection == [
            "Document": [
                "Save As…",
                "Import into Library…",
                "Reveal in Folder",
            ],
        ])

        window.debugSetEditorText("# Updated\n\nSaved from external window")
        XCTAssertTrue(window.debugEditorModified)

        autosaveScheduler.runPendingActions()

        XCTAssertTrue(try String(contentsOf: fileURL, encoding: .utf8) == "# Updated\n\nSaved from external window")
        XCTAssertFalse(window.debugEditorModified)
        XCTAssertTrue(window.debugPreviewText.contains("Saved from external window"))
    }

    @MainActor func test_external_document_window_reloads_changed_file_after_poll() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)

        let fileURL = temp.appendingPathComponent("Reloaded.md", isDirectory: false)
        try "# Before\n\nBody".write(to: fileURL, atomically: true, encoding: .utf8)

        let app = Application(id: "me.spaceinbox.swiftynotes.tests.externaldocumentreload")
        try app.register()

        let window = try ExternalDocumentWindow(
            application: app,
            fileURL: fileURL,
            renderer: MarkdownRenderer(),
            autosave: AutosaveCoordinator(),
        )

        window.present()

        try "# After\n\nChanged on disk".write(to: fileURL, atomically: true, encoding: .utf8)
        window.debugPollForExternalChanges()

        XCTAssertTrue(window.debugEditorText == "# After\n\nChanged on disk")
        XCTAssertTrue(window.debugPreviewText.contains("After"))
        XCTAssertTrue(window.debugPreviewText.contains("Changed on disk"))
    }
}
#endif
