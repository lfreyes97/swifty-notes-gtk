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
    typealias EditorPositioning = (Heading) -> Double?
    typealias PreviewPositioning = (Heading) -> Double?

    private let onActive: (String?) -> Void
    private let editorScroll: ScrolledWindow
    private let previewScroll: ScrolledWindow
    private let editorPositionsFor: EditorPositioning
    private let previewPositionsFor: PreviewPositioning
    private let resolveHeadings: HeadingResolver

    /// Anchor offset, in pixels, below the visible top of the scrolled
    /// surface. Headings whose y is at or above this line activate.
    let anchorOffset: Double = 80

    private var editorConnection: SignalConnection?
    private var previewConnection: SignalConnection?
    private var pendingTick = false

    init(
        editorScroll: ScrolledWindow,
        previewScroll: ScrolledWindow,
        resolveHeadings: @escaping HeadingResolver,
        previewPositionsFor: @escaping PreviewPositioning,
        editorPositionsFor: @escaping EditorPositioning,
        onActive: @escaping (String?) -> Void,
    ) {
        self.editorScroll = editorScroll
        self.previewScroll = previewScroll
        self.resolveHeadings = resolveHeadings
        self.previewPositionsFor = previewPositionsFor
        self.editorPositionsFor = editorPositionsFor
        self.onActive = onActive
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
            positions = headings.compactMap { heading in
                editorPositionsFor(heading).map { (heading.id, $0) }
            }
        case .split, .preview:
            scrollTop = previewScroll.verticalAdjustment.value
            positions = headings.compactMap { heading in
                previewPositionsFor(heading).map { (heading.id, $0) }
            }
        }
        let active = ScrollSpyResolver.activeHeadingID(
            positions: positions,
            scrollTop: scrollTop,
            anchorOffset: anchorOffset,
        )
        onActive(active)
    }

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
