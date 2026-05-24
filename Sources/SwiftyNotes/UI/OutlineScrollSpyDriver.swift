import Adwaita
import Foundation

/// Glue between the rendered preview (or editor) and the
/// ``ScrollSpyResolver`` pure logic. Hooks the appropriate
/// `verticalAdjustment` signal, debounces through `MainContext.idle`,
/// resolves the active heading, and reports it back.
///
/// Two parallel handlers live here because the active scroll target
/// depends on the current view mode: in Editor / Split modes the
/// preview is the visually dominant target, while in Preview-only mode
/// the editor isn't visible at all. The MainWindow swaps the watched
/// pane through ``rebind(mode:)`` whenever it changes the view mode.
@MainActor
final class OutlineScrollSpyDriver {
    typealias HeadingResolver = () -> [Heading]
    typealias PositionLookup = ([Heading]) -> [(id: String, y: Double)]

    private let onActive: (String?) -> Void
    private let editorScroll: ScrolledWindow
    private let previewScroll: ScrolledWindow
    private let editorPositions: PositionLookup
    private let previewPositions: PositionLookup
    private let resolveHeadings: HeadingResolver

    /// Anchor offset, in pixels, below the visible top of the scrolled
    /// surface. Headings whose y is at or above this line activate.
    let anchorOffset: Double = 80

    private var editorConnection: SignalConnection?
    private var previewConnection: SignalConnection?
    private var pendingTick = false
    /// Wall-clock instant past which scroll-spy ticks resume firing
    /// the resolver. Set by ``suppress(until:)`` whenever a click /
    /// palette pick / Ctrl+G jump triggers a programmatic scroll —
    /// otherwise the in-flight animation's intermediate scrollTop
    /// values would let the resolver pick whatever heading is still
    /// above the anchor *right now*, overriding the click's explicit
    /// active-id and producing the "selects the heading above the
    /// clicked one" symptom users report.
    private var suppressedUntil: ContinuousClock.Instant?

    init(
        editorScroll: ScrolledWindow,
        previewScroll: ScrolledWindow,
        resolveHeadings: @escaping HeadingResolver,
        previewPositions: @escaping PositionLookup,
        editorPositions: @escaping PositionLookup,
        onActive: @escaping (String?) -> Void,
    ) {
        self.editorScroll = editorScroll
        self.previewScroll = previewScroll
        self.resolveHeadings = resolveHeadings
        self.previewPositions = previewPositions
        self.editorPositions = editorPositions
        self.onActive = onActive
    }

    /// Park the scroll-spy resolver for `interval` from `now`. While
    /// the suppression window is active, scroll ticks still fire but
    /// skip the resolver — the most recent `onActive` value (which
    /// the click handler set explicitly) stays authoritative.
    /// Re-entry just bumps the deadline forward.
    func suppress(for interval: Duration) {
        let deadline = ContinuousClock.now.advanced(by: interval)
        if let current = suppressedUntil, current > deadline {
            return
        }
        suppressedUntil = deadline
    }

    /// Wires `onValueChanged` on the appropriate adjustment for the
    /// current view mode. Idempotent — calling twice with the same
    /// mode reuses the existing subscription.
    func rebind(mode: EditorViewMode) {
        editorConnection?.disconnect()
        previewConnection?.disconnect()
        editorConnection = nil
        previewConnection = nil

        // Always evaluate once on (re)bind so the active highlight is
        // correct without the user having to scroll first.
        tick(for: mode)

        switch mode {
        case .editor:
            editorConnection = editorScroll.verticalAdjustment.onValueChanged { [weak self] in
                self?.scheduleTick(for: .editor)
            }
        case .split, .preview:
            previewConnection = previewScroll.verticalAdjustment.onValueChanged { [weak self] in
                self?.scheduleTick(for: mode)
            }
        }
    }

    private func scheduleTick(for mode: EditorViewMode) {
        guard !pendingTick else { return }
        pendingTick = true
        MainContext.idle { [weak self] in
            guard let self else { return }
            pendingTick = false
            tick(for: mode)
        }
    }

    private func tick(for mode: EditorViewMode) {
        if let suppressedUntil, suppressedUntil > ContinuousClock.now {
            return
        }
        suppressedUntil = nil
        let headings = resolveHeadings()
        guard !headings.isEmpty else {
            onActive(nil)
            return
        }
        let positions: [(id: String, y: Double)]
        let scrollTop: Double
        switch mode {
        case .editor:
            scrollTop = editorScroll.verticalAdjustment.value
            positions = editorPositions(headings)
        case .split, .preview:
            scrollTop = previewScroll.verticalAdjustment.value
            positions = previewPositions(headings)
        }
        let active = ScrollSpyResolver.activeHeadingID(
            positions: positions,
            scrollTop: scrollTop,
            anchorOffset: anchorOffset,
        )
        onActive(active)
    }

    #if DEBUG
    /// Test surface — drives a single tick synchronously without
    /// having to feed the GLib main loop. The production tick path
    /// (`scheduleTick`) waits for `MainContext.idle`, which doesn't
    /// pump in the unit-test environment.
    func debugTick(mode: EditorViewMode) { tick(for: mode) }
    #endif

    deinit {
        // Disconnect synchronously so the bound closures stop firing
        // before the MainWindow tears down its widgets — otherwise the
        // callback can land on a dangling self.
        MainActor.assumeIsolated {
            editorConnection?.disconnect()
            previewConnection?.disconnect()
        }
    }
}
