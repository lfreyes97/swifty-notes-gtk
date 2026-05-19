import Adwaita
import Foundation

/// GTK4 on Quartz has a long-standing drag-detection regression: any
/// sub-pixel pointer motion between press and release wakes up an
/// internal pan/drag gesture that races the button's own click gesture
/// for the pointer sequence. The drag gesture wins, claims the
/// sequence, and `Button.clicked` (plus the toggled/popup behaviour
/// derived from it) never fires. Symptom: toolbar buttons, mode
/// toggles, the hamburger button, and items inside hand-built menus
/// all behave as if the click was swallowed unless the cursor stays
/// perfectly still during the press.
///
/// The reliable fix used across the codebase (sidebar rows, note +
/// folder context menus, update banner, …) is:
///
///   1. Attach an explicit `GestureClick` on the **CAPTURE** phase so
///      it fires before the widget's own BUBBLE-phase gestures.
///   2. Claim the sequence the moment we observe the press
///      (`GTK_EVENT_SEQUENCE_CLAIMED`) — that denies every other
///      interested gesture (the button's internal click, any drag
///      detector that wakes up later).
///   3. Treat our own `released` signal as the click trigger.
///
/// Wrapping this once and applying everywhere avoids hand-copying the
/// pattern and forgetting `#if os(macOS)` around it. Linux falls
/// straight through to the widget's normal click path.
@MainActor
enum MacOSClickWorkaround {
    /// Wires `handler` so it fires when the user releases a primary
    /// click on `button`, even when Quartz's drag detector would
    /// otherwise eat the click.
    ///
    /// On macOS we listen on BOTH the button's regular `clicked`
    /// signal AND a CAPTURE-phase GestureClick — each covers a
    /// failure mode the other misses:
    ///
    /// * The CAPTURE-phase `released` catches the original
    ///   drag-detection regression: when the cursor drifts even a
    ///   sub-pixel between press and release, GTK4-Quartz's pan
    ///   detector wakes up and denies the button's own gesture, so
    ///   `clicked` never emits. Our gesture wins the sequence
    ///   (CAPTURE fires before BUBBLE, claim runs on press) and
    ///   fires `released` regardless of motion.
    ///
    /// * The `clicked` signal catches the "fast click" failure mode
    ///   that the gesture path alone misses: short press+release
    ///   events delivered tightly together on Quartz sometimes don't
    ///   reach our gesture's `released` handler (it appears the
    ///   sequence state-machine is still processing the press when
    ///   release arrives and either coalesces or drops it). The
    ///   button's own signal pipeline doesn't suffer that race, so
    ///   `onClicked` fires reliably on those clicks.
    ///
    /// In practice the two paths are mutually exclusive — a real
    /// motion-during-click click goes through CAPTURE-release, a
    /// fast still click goes through `clicked`. But to defend
    /// against an unlikely overlap (no-motion click where both paths
    /// resolve), the handler is wrapped in a per-button 200 ms
    /// dedup. Programmatic activation paths (Enter key, focus +
    /// space, accessibility activation) also go through `clicked`,
    /// so they keep working without test-only debug helpers.
    static func onClick(_ button: Button, handler: @escaping @MainActor () -> Void) {
        #if os(macOS)
        let deduped = makeDedupedHandler(for: button, handler: handler)
        button.onClicked(deduped)
        attachReleaseHandler(to: button, onRelease: deduped)
        #else
        button.onClicked(handler)
        #endif
    }

    /// For ToggleButton: registers `onToggled` for the actual behaviour
    /// and additionally installs a capture-phase release that forces
    /// `active = true` (or `.toggle()` for stand-alone toggles) on
    /// click. ToggleButton doesn't expose a `clicked` signal in
    /// swift-adwaita, so we can't add the same dual-path fallback
    /// used by ``onClick(_:handler:)``. If a fast click drops the
    /// gesture release on Quartz, the user can simply click again
    /// — toggles are visually obvious about their state, unlike
    /// fire-and-forget action buttons.
    static func onToggle(
        _ toggle: ToggleButton,
        togglesActive: Bool = true,
        handler: @escaping @MainActor () -> Void,
    ) {
        toggle.onToggled(handler)
        #if os(macOS)
        attachReleaseHandler(to: toggle) { [weak toggle] in
            guard let toggle else { return }
            if togglesActive {
                toggle.active.toggle()
            } else {
                toggle.active = true
            }
        }
        #endif
    }

    /// Forces the menu to popup on release. `MenuButton`'s normal
    /// auto-popup hangs off its internal click handling, which is
    /// eaten by the drag detector on Quartz. Unlike `Button` we
    /// can't listen on a public `clicked` signal here (MenuButton
    /// doesn't expose one in swift-adwaita), so we rely on the
    /// CAPTURE-release path alone. `gtk_menu_button_popup` is
    /// idempotent, so any rare double-fire collapses to a single
    /// popup anyway.
    static func onMenuButtonPress(_ menuButton: MenuButton) {
        #if os(macOS)
        attachReleaseHandler(to: menuButton) { [weak menuButton] in
            guard let menuButton else { return }
            gtk_menu_button_popup(menuButton.opaquePointer)
        }
        #endif
    }

#if os(macOS)
    /// Generic press/release plumbing shared by Button / ToggleButton /
    /// MenuButton. The widget keeps a strong reference to the gesture
    /// (via `addController`), so we only need a weak ref back through
    /// the closure to avoid retain cycles.
    private static func attachReleaseHandler(
        to widget: Widget,
        onRelease: @escaping @MainActor () -> Void,
    ) {
        let click = GestureClick()
        click.button = 1
        gtk_event_controller_set_propagation_phase(click.opaquePointer, GTK_PHASE_CAPTURE)
        widget.addController(click)
        click.onPressed { [weak click] _, _, _ in
            guard let click else { return }
            gtk_gesture_set_state(click.opaquePointer, GTK_EVENT_SEQUENCE_CLAIMED)
        }
        click.onReleased { _, _, _ in onRelease() }
    }

    /// Per-button last-fire timestamp keyed by `ObjectIdentifier`. The
    /// entry persists for the lifetime of the button (which is the
    /// lifetime of the app for toolbar / banner / menu buttons), so
    /// the map stays bounded by the widget count. Read/written only
    /// from the main thread under `@MainActor` isolation, so no
    /// locking is needed.
    private static var lastClickFire: [ObjectIdentifier: ContinuousClock.Instant] = [:]
    private static let clickDedupWindow: Duration = .milliseconds(200)

    /// Wraps `handler` so it runs at most once per 200 ms per widget.
    /// Both the `clicked` signal path and the CAPTURE-release path
    /// invoke the same returned closure; whichever fires first wins
    /// and the other path's invocation is swallowed.
    private static func makeDedupedHandler(
        for widget: AnyObject,
        handler: @escaping @MainActor () -> Void,
    ) -> @MainActor () -> Void {
        let key = ObjectIdentifier(widget)
        return {
            let now = ContinuousClock.now
            if let last = lastClickFire[key], now - last < clickDedupWindow {
                return
            }
            lastClickFire[key] = now
            handler()
        }
    }
    #endif
}
