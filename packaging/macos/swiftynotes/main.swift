// =============================================================================
// macOS .app entry point for Swifty Notes.
// =============================================================================
//
// Hands off to the same `SwiftyNotesLauncher.run(...)` that drives the Linux
// `swiftynotes` executable target — the Xcode build wraps that logic into
// a regular macOS `.app` bundle (Info.plist, code signing, archive,
// notarization) and adds the few macOS-specific bits the bundle launch
// path needs:
//
//   1. Filter Xcode's debug-only argv. When Xcode launches a debug build it
//      passes `-NSDocumentRevisionsDebugMode YES`, `-ApplePersistenceIgnoreState
//      YES`, and similar Cocoa-specific flags. GApplication aborts on the
//      first unknown CLI option, which from the user's chair looks like
//      the app launched and immediately disappeared.
//      `SwiftyNotesLauncher.run(arguments:)` defaults to
//      `CommandLine.arguments.dropFirst()`, which would pick those up.
//      Pass an empty array instead — the launcher already handles its
//      own internal CLI mode without needing argv.
//
//   2. `XDG_DATA_DIRS=/opt/homebrew/share` is supplied through the shared
//      scheme's "Run > Environment Variables" for Cmd+R, and through the
//      Info.plist's `LSEnvironment` for `open .app` / Launch Services
//      launches. swift-adwaita 1.3.0 also prepends the Homebrew prefix
//      programmatically as a final safety net (see DemoAppLib's
//      `ensureHomebrewSchemasOnPath`), but Swifty Notes doesn't go through
//      DemoAppLib.
// =============================================================================

import Darwin
import Foundation
import SwiftyNotes

// Set GTK / GLib runtime-resource discovery env vars before
// `SwiftyNotesLauncher.run(arguments:)` calls into GTK. Two cases the
// app needs to behave correctly under:
//
//   1. **Bundled (post-`scripts/bundle-macos-app.sh`)**. The .app
//      contains its own `Contents/Resources/glib-2.0/schemas/`, icon
//      themes, and GdkPixbuf loader cache. The app is relocatable so
//      paths must be derived from `Bundle.main.resourcePath` at
//      runtime — hardcoding into Info.plist's `LSEnvironment` would
//      pin the bundle to its build-time location.
//
//   2. **Unbundled developer build (Cmd+R or `swift run`)**. Resources
//      live in /opt/homebrew/share. The Xcode scheme already sets
//      `XDG_DATA_DIRS=/opt/homebrew/share` for Cmd+R; this code adds a
//      safety-net fallback for `open .app`, `swift run`, or Xcode
//      profiling sessions where scheme env didn't reach us.
//
// We detect "bundled" by probing for `gschemas.compiled` inside the
// bundle's Resources — that file is what `bundle-macos-app.sh` writes
// to mark the bundle as self-contained. If present, prepend
// bundle-relative paths to whatever the environment already has
// (scheme env wins when set); if absent, fall back to brew.
ensureRuntimeResourcePathsForBundleIfNeeded()

SwiftyNotesLauncher.run(arguments: [])

private func ensureRuntimeResourcePathsForBundleIfNeeded() {
    let fileManager = FileManager.default

    // Bundle.main.resourcePath is the absolute path to `Contents/Resources/`
    // when running inside a .app, or nil for non-bundled processes. We
    // also handle the latter (e.g. raw `swift run swiftynotes` on macOS
    // for ad-hoc smoke tests) by falling through to brew below.
    let resourcePath = Bundle.main.resourcePath

    let bundledSchemasPath = resourcePath.map { "\($0)/glib-2.0/schemas/gschemas.compiled" }
    let isBundled = bundledSchemasPath.map { fileManager.fileExists(atPath: $0) } ?? false

    if isBundled, let resourcePath {
        // Bundled mode: prepend Resources/ to XDG_DATA_DIRS so GLib /
        // libadwaita finds the in-bundle schemas + icon themes before
        // anything else. Preserve whatever was there (rare but
        // possible if a power user exported it before launch).
        let existingXDG = ProcessInfo.processInfo.environment["XDG_DATA_DIRS"] ?? ""
        let newXDG: String = existingXDG.isEmpty
            ? resourcePath
            : "\(resourcePath):\(existingXDG)"
        setenv("XDG_DATA_DIRS", newXDG, 1)

        // GDK_PIXBUF_MODULE_FILE accepts a single absolute path to the
        // loaders.cache; the cache lists each loader by a relative
        // filename which GdkPixbuf resolves against the cache file's
        // own directory (this is why the bundle script strips
        // absolute prefixes from cache entries before signing).
        let pixbufCachePath = "\(resourcePath)/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
        if fileManager.fileExists(atPath: pixbufCachePath) {
            setenv("GDK_PIXBUF_MODULE_FILE", pixbufCachePath, 1)
        }
    } else if ProcessInfo.processInfo.environment["XDG_DATA_DIRS"] == nil {
        // Unbundled mode and no env var set yet (e.g. `open .app` on a
        // developer build that hasn't been through bundle-macos-app.sh
        // yet). Fall back to brew so libadwaita's `gtk_init` doesn't
        // abort on missing schemas — same path the scheme already uses
        // for Cmd+R.
        setenv("XDG_DATA_DIRS", "/opt/homebrew/share", 1)
    }
}
