import Adwaita
import Foundation

/// In-app banner shown above the editor when a newer GitHub release is
/// available. AdwBanner only supports a single action button, so this
/// rolls a thin horizontal layout instead — Label + "Update" button +
/// flat close button — wrapped in a Revealer for the slide-down reveal
/// animation that matches AdwBanner's behaviour.
@MainActor
final class UpdateBanner {
    let revealer = Revealer()
    private let container = Box(orientation: .horizontal, spacing: 8)
    private let label = Label("")
    private let updateButton = Button(label: "Update")
    private let closeButton = Button(icon: .windowClose)

    private var onUpdateHandler: (() -> Void)?
    private var onDismissHandler: (() -> Void)?

    init() {
        revealer.transitionType = GTK_REVEALER_TRANSITION_TYPE_SLIDE_DOWN
        revealer.transitionDuration = 200
        revealer.revealChild = false

        container.addCSSClass(.accent)
        container.addCSSClass(.toolbar)
        container.marginTop = 0
        container.marginBottom = 0

        label.hexpand = true
        label.halign = .start
        label.wrap = true
        label.marginStart = 12
        label.marginEnd = 12
        label.marginTop = 8
        label.marginBottom = 8

        updateButton.addCSSClass(.suggestedAction)
        updateButton.marginTop = 6
        updateButton.marginBottom = 6
        Self.installClickHandler(on: updateButton) { [weak self] in
            self?.onUpdateHandler?()
        }

        closeButton.addCSSClass(.flat)
        closeButton.addCSSClass(.circular)
        closeButton.tooltipText = "Dismiss"
        closeButton.setAccessibleLabel("Dismiss update notification")
        closeButton.marginTop = 6
        closeButton.marginBottom = 6
        closeButton.marginEnd = 6
        Self.installClickHandler(on: closeButton) { [weak self] in
            self?.dismiss()
        }

        container.append(label)
        container.append(updateButton)
        container.append(closeButton)

        revealer.child = container
    }

    /// Add the banner to a vertical container above the editor area.
    func attach(to parent: Box) {
        parent.append(revealer)
    }

    func show(version: String) {
        label.text = "Version \(version) is available."
        revealer.revealChild = true
    }

    func dismiss() {
        revealer.revealChild = false
        onDismissHandler?()
    }

    var isVisible: Bool { revealer.revealChild }

    func onUpdate(_ handler: @escaping () -> Void) {
        onUpdateHandler = handler
    }

    func onDismiss(_ handler: @escaping () -> Void) {
        onDismissHandler = handler
    }

    /// On macOS GTK4-Quartz, a `Button.onClicked` handler silently drops
    /// the click whenever the cursor moves sub-pixel between press and
    /// release: a competing drag-detection gesture wakes up, claims the
    /// pointer sequence, and `clicked` never emits. The same workaround
    /// used for the sidebar rows and the note context-menu items fixes
    /// it here — install our own `GestureClick` on the CAPTURE phase
    /// (fires before Button's internal BUBBLE-phase gesture) and claim
    /// the sequence on the press so no later drag detector can steal it.
    private static func installClickHandler(on button: Button, handler: @escaping () -> Void) {
        #if os(macOS)
        let click = GestureClick()
        click.button = 1
        gtk_event_controller_set_propagation_phase(click.opaquePointer, GTK_PHASE_CAPTURE)
        button.addController(click)
        click.onPressed { [weak click] _, _, _ in
            guard let click else { return }
            gtk_gesture_set_state(click.opaquePointer, GTK_EVENT_SEQUENCE_CLAIMED)
        }
        click.onReleased { _, _, _ in handler() }
        #else
        button.onClicked(handler)
        #endif
    }
}
