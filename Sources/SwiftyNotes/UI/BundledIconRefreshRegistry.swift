import Adwaita
import Foundation

/// Drives a live re-render of every bundled-SVG widget whenever
/// libadwaita reports a dark/light theme change.
///
/// **Why:** On macOS we work around a `GtkSymbolicPaintable` bug by
/// loading our shipped symbolic SVGs through `Image(filename:)` rather
/// than the icon theme lookup (`Image(iconName:)`). The filename path
/// goes through librsvg, which renders the SVG as-is — no automatic
/// symbolic recolouring against `@theme_fg_color`. We compensate by
/// pre-tinting a copy of each SVG to a light shade when the app is in
/// dark mode (see ``MainWindow.cachedDarkVariantPath``), but that
/// pre-tint happens once at widget creation. Without this registry,
/// flipping macOS between Light Mode and Dark Mode while Swifty Notes
/// is running leaves the bundled icons stuck on whichever variant they
/// were originally created with, while everything else (theme-resolved
/// icons, text colours, backgrounds) tracks the change — visibly
/// inconsistent.
///
/// **What it does:** Each Button / SplitButton / ToolbarView that
/// contains a bundled icon registers a single closure with the
/// registry at construction time. The closure knows how to rebuild
/// that widget's icon content from scratch using the current theme.
/// On every `notify::dark` signal from `AdwStyleManager`, the registry
/// runs every closure. Closures return `false` to unregister
/// themselves once their target widget is no longer alive — keeps the
/// list compact across long-running sessions.
///
/// **Why a singleton:** The `notify::dark` signal is global, fired
/// once per theme flip. A single shared subscriber that fans out is
/// cheaper than one subscription per widget; it also avoids leaking
/// libadwaita signal handlers when widgets are detached.
///
/// **Linux note:** No-op outside macOS. Linux uses
/// `Image(iconName:)` directly (the bundled-icon workaround only
/// activates for `table-symbolic`, which has no symbolic-recolour
/// concern), so the icons there track theme changes through normal
/// `GtkSymbolicPaintable` and don't need this registry. The
/// `#if os(macOS)` gates ensure we don't pay subscription cost on
/// Linux at all.
@MainActor
final class BundledIconRefreshRegistry {
    /// Process-wide instance. First access subscribes to
    /// ``StyleManager/onDarkChanged`` (on macOS); subsequent
    /// accesses are constant-time.
    static let shared = BundledIconRefreshRegistry()

    /// Registered rebuild closures. Each returns `true` to stay
    /// in the list, `false` to be filtered out on the next flip.
    private var refreshes: [() -> Bool] = []

    private init() {
        #if os(macOS)
        // The signal stays connected for the lifetime of the process —
        // we deliberately don't store the SignalConnection because
        // there's no realistic point at which we'd disconnect (the
        // singleton lives until app exit). Returning the connection
        // would only invite a confusing "should I keep this?" question
        // at every call site.
        _ = StyleManager.default.onDarkChanged { [weak self] in
            self?.runAll()
        }
        #endif
    }

    /// Adds `refresh` to the list of closures invoked on dark/light
    /// theme changes. The closure should:
    ///
    /// 1. Resolve the widget it cares about (typically via a weak
    ///    capture).
    /// 2. Rebuild that widget's icon content using the current value
    ///    of ``StyleManager.default.dark``.
    /// 3. Return `true` if the widget is still around and the closure
    ///    should stay registered, `false` to be unregistered (the
    ///    weak reference returned `nil`).
    ///
    /// On non-macOS builds the registry never fires, so the closure
    /// is effectively dead code there. Callers should still gate the
    /// `register` call behind `#if os(macOS)` to keep the closure
    /// itself out of the Linux binary.
    func register(_ refresh: @escaping () -> Bool) {
        refreshes.append(refresh)
    }

    private func runAll() {
        // Replace in-place with the survivors — closures that returned
        // false drop out. Using `filter` over a mutating loop keeps
        // this readable; the list never grows beyond a couple dozen
        // entries (one per top-level header / toolbar / sort button)
        // so the allocation cost is negligible.
        refreshes = refreshes.filter { $0() }
    }
}
