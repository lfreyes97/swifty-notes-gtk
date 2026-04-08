import Foundation
import Testing
@testable import SwiftyNotes

struct SettingsStoreTests {
    @Test
    func appSettingsStoreRoundTripsCustomNotesDirectoryAndPreferences() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let settingsFileURL = temp
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("settings.json", isDirectory: false)
        let customNotesDirectory = temp.appendingPathComponent("custom-notes", isDirectory: true)
        let store = AppSettingsStore(settingsFileURL: settingsFileURL)

        try store.save(AppSettings(
            customNotesDirectoryPath: customNotesDirectory.path(),
            wrapsEditorLines: false,
            editorFontSize: 18,
            editorTabWidth: 2,
            editorIndentStyle: .tabs,
            autosaveDelaySeconds: 5,
            appearanceMode: .dark
        ))

        let loaded = try store.load()
        #expect(loaded.customNotesDirectoryURL?.standardizedFileURL == customNotesDirectory.standardizedFileURL)
        #expect(!loaded.wrapsEditorLines)
        #expect(loaded.editorFontSize == 18)
        #expect(loaded.editorTabWidth == 2)
        #expect(loaded.editorIndentStyle == .tabs)
        #expect(loaded.autosaveDelaySeconds == 5)
        #expect(loaded.appearanceMode == .dark)
        #expect(
            loaded.resolvedNotesDirectory(
                defaultDirectory: temp.appendingPathComponent("default-notes", isDirectory: true)
            ).standardizedFileURL == customNotesDirectory.standardizedFileURL
        )
    }

    @Test
    func appSettingsDecodeOlderPayloadWithNewPreferenceDefaults() throws {
        let payload = """
        {
          "customNotesDirectoryPath": "/tmp/notes"
        }
        """

        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(payload.utf8))

        #expect(settings.customNotesDirectoryPath == "/tmp/notes")
        #expect(settings.wrapsEditorLines)
        #expect(settings.editorFontSize == 14)
        #expect(settings.editorTabWidth == 4)
        #expect(settings.editorIndentStyle == .spaces)
        #expect(settings.autosaveDelaySeconds == 2)
        #expect(settings.appearanceMode == .system)
    }

    @Test
    func appSettingsStoreMigratesOldestLegacyDefaultSettingsPrefix() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let legacyDirectory = temp.appendingPathComponent(AppIdentity.oldestLegacyIdentifier, isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        let customNotesDirectory = temp.appendingPathComponent("legacy-custom-notes", isDirectory: true)
        let legacyStore = AppSettingsStore(
            settingsFileURL: legacyDirectory.appendingPathComponent("settings.json", isDirectory: false)
        )
        try legacyStore.save(AppSettings(customNotesDirectoryPath: customNotesDirectory.path()))

        let migratedStore = AppSettingsStore(
            settingsFileURL: temp
                .appendingPathComponent(AppIdentity.identifier, isDirectory: true)
                .appendingPathComponent("settings.json", isDirectory: false)
        )

        let loaded = try migratedStore.load()
        #expect(loaded.customNotesDirectoryURL?.standardizedFileURL == customNotesDirectory.standardizedFileURL)
        #expect(FileManager.default.fileExists(
            atPath: temp
                .appendingPathComponent(AppIdentity.identifier, isDirectory: true)
                .appendingPathComponent("settings.json", isDirectory: false)
                .path()
        ))
        #expect(!FileManager.default.fileExists(
            atPath: temp
                .appendingPathComponent(AppIdentity.oldestLegacyIdentifier, isDirectory: true)
                .appendingPathComponent("settings.json", isDirectory: false)
                .path()
        ))
    }

    @Test
    func notesDirectoryRelocatorMovesNotesIntoExistingEmptyFolderAndRemovesOldPath() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = temp.appendingPathComponent("source-notes", isDirectory: true)
        let destination = temp.appendingPathComponent("destination-notes", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try "# Moved\n".write(
            to: source.appendingPathComponent("note.md", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )
        try Data([0x01, 0x02, 0x03]).write(
            to: source.appendingPathComponent("asset.bin", isDirectory: false)
        )

        try NotesDirectoryRelocator.relocate(from: source, to: destination)

        #expect(!FileManager.default.fileExists(atPath: source.path()))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("note.md").path()))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("asset.bin").path()))
    }

    @Test
    func notesDirectoryRelocatorRejectsNonEmptyDestination() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let source = temp.appendingPathComponent("source-notes", isDirectory: true)
        let destination = temp.appendingPathComponent("destination-notes", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try "# Source\n".write(
            to: source.appendingPathComponent("note.md", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )
        try "occupied".write(
            to: destination.appendingPathComponent("existing.txt", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )

        do {
            try NotesDirectoryRelocator.relocate(from: source, to: destination)
            Issue.record("Expected relocation to reject a non-empty destination folder")
        } catch {
            #expect(error.localizedDescription.contains("empty"))
        }
    }
}
