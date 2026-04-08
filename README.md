# Swifty Notes

Native GTK markdown notes for Linux, written in Swift with `swift-adwaita`.

## Features

- file-backed markdown notes stored as plain `.md` files
- GTK/libadwaita UI with notes sidebar, live Markdown editor, and inspector-style preview
- first-launch seeded example note (`Markdown Showcase`)
- autosave, manual save, import/export, duplicate, rename, delete, and open-notes-folder flows
- settings window for choosing and moving the notes storage folder
- editor preferences for line wrapping, font size, tab width, and spaces-vs-tabs indentation
- configurable autosave delay and appearance override (follow system, light, dark)
- CLI for listing, reading, creating, and replacing notes by stable ID
- workspace persistence for selection, search, sort mode, sidebar/preview visibility, and window layout
- native Wayland UI smoke coverage with headless Weston + AT-SPI

## Project layout

- `Sources/SwiftyNotes/main.swift` starts either the GTK app or the CLI entrypoint.
- `Sources/SwiftyNotes/UI/` contains the main window, sidebar, editor, and preview widgets.
- `Sources/SwiftyNotes/Storage/` contains note persistence and workspace-state persistence.
- `Sources/SwiftyNotes/Services/MarkdownRenderer.swift` converts markdown into the native GTK preview model.
- `Tests/SwiftyNotesTests/` contains repository/MainWindow regressions, CLI tests, and Wayland UI smoke tests.

## Requirements

- Swift 6 toolchain
- Linux desktop environment with GTK 4, libadwaita, and GtkSourceView 5 available
- local checkout of [`swift-adwaita`](https://github.com/stackotter/swift-adwaita) at `../swift-adwaita` because `Package.swift` references it as a path dependency

## Build and run

```bash
swift build
swift run SwiftyNotes
```

## Tests

Run the full suite:

```bash
swift test --no-parallel
```

Run one regression:

```bash
swift test --filter 'mainWindowPresentRendersPreviewForInitiallySelectedNote' --no-parallel
```

Run one Wayland smoke test:

```bash
swift test --filter 'appLaunchesUnderHeadlessWaylandWithAccessibleWindowAndSeededControls' --no-parallel
```

The smoke tests require a working session bus and tools such as `weston` and `pyatspi`.

## CLI

The same executable exposes a CLI:

```bash
swift run SwiftyNotes -- cli list
swift run SwiftyNotes -- cli get <note-id>
swift run SwiftyNotes -- cli get <note-id> --raw
swift run SwiftyNotes -- cli create --content '# Title\n\nBody'
swift run SwiftyNotes -- cli update <note-id> --stdin
```

`update` replaces the full markdown content of the target note.

## Storage

- Notes directory by default: `XDG_DATA_HOME/me.spaceinbox.SwiftyNotes/notes`
- Configurable notes directory: set in the app via **Settings** and persisted in `XDG_CONFIG_HOME/me.spaceinbox.SwiftyNotes/settings.json`
- Workspace state: `XDG_STATE_HOME/me.spaceinbox.SwiftyNotes/workspace.json`

If the notes directory is empty on first launch, the app creates the `Markdown Showcase` note automatically.

When you change the notes folder in Settings, the app moves the existing notes directory to the new location. The CLI follows the same configured folder automatically unless `--notes-dir` is passed explicitly.

## Settings

The Settings window currently lets you configure:

- notes storage location
- editor line wrapping
- editor font size
- editor tab width
- spaces vs tabs indentation
- autosave delay
- appearance override

## Preview architecture

The preview is fully native GTK. The rendering pipeline is:

`swift-markdown` -> `HTMLFormatter` -> local HTML subset parser -> `RenderedBlock` -> GTK widgets

There is no WebKit/WebView dependency.

## License

MIT. See [LICENSE](LICENSE).
