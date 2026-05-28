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
    static func onClick(_ button: Button, label: String = "Button", handler: @escaping @MainActor () -> Void) {
        #if os(macOS)
        // Two paths into the same deduped handler:
        //   * `clicked` signal — the standard GTK route. Fires on
        //     release when the button's own gesture wins arbitration
        //     (no motion case, programmatic activate, keyboard Enter).
        //   * CAPTURE-phase `released` with CLAIMED on press — wins
        //     the sequence on Quartz when sub-pixel motion would
        //     otherwise hand it to the drag detector, so the
        //     motion-during-click case still reaches us.
        //
        // Firing on PRESS instead breaks two important UX patterns:
        // the natural "click-on-release" feel that users expect from
        // action buttons, and drag-to-cancel gestures. The trade-off
        // is that Quartz drops the `released` callback on the
        // tightest fast clicks (~50 % of <80 ms press/release
        // sequences in our debug traces) — those clicks register on
        // the second try, which is acceptable.
        let deduped = makeDedupedHandler(for: button, label: label, handler: handler)
        button.onClicked { [weak button] in
            debugLog(label: label, widget: button, event: "clicked-signal")
            deduped(.clickedSignal)
        }
        attachReleaseHandler(to: button, label: label) { [weak button] in
            debugLog(label: label, widget: button, event: "capture-released")
            deduped(.captureRelease)
        }
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
        label: String = "ToggleButton",
        handler: @escaping @MainActor () -> Void,
    ) {
        toggle.onToggled { [weak toggle] in
            debugLog(label: label, widget: toggle, event: "toggled-signal active=\(toggle?.active.description ?? "?")")
            handler()
        }
        #if os(macOS)
        attachReleaseHandler(to: toggle, label: label) { [weak toggle] in
            debugLog(label: label, widget: toggle, event: "capture-released → flip togglesActive=\(togglesActive)")
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
    static func onMenuButtonPress(_ menuButton: MenuButton, label: String = "MenuButton") {
        #if os(macOS)
        attachReleaseHandler(to: menuButton, label: label) { [weak menuButton] in
            debugLog(label: label, widget: menuButton, event: "capture-released → popup")
            guard let menuButton else { return }
            gtk_menu_button_popup(menuButton.opaquePointer)
        }
        #endif
    }

    /// Process-wide debug flag. Set `SWIFTY_NOTES_DEBUG_CLICKS=1` in
    /// the app's environment to enable per-click trace lines on
    /// stderr. Off by default; reading the env var once at first
    /// access keeps the hot click path branch-predictor-friendly.
    /// Available on both platforms because the call sites are
    /// cross-platform (e.g. `onToggle` connects `onToggled` on
    /// Linux too) and the env-var gate keeps it a no-op when not
    /// explicitly opted in.
    nonisolated static let debugLoggingEnabled: Bool = {
        let env = ProcessInfo.processInfo.environment["SWIFTY_NOTES_DEBUG_CLICKS"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return env == "1" || env?.lowercased() == "true"
    }()

    /// Emits a single trace line for a click-pipeline event:
    ///
    ///     [click] ts=… label=… widget=… event=…
    static func debugLog(label: String, widget: AnyObject?, event: String) {
        guard debugLoggingEnabled else { return }
        let widgetID = widget.map { String(ObjectIdentifier($0).hashValue, radix: 16) } ?? "<nil>"
        let ts = String(format: "%.4f", Date().timeIntervalSinceReferenceDate)
        let line = "[click] ts=\(ts) label=\"\(label)\" widget=\(widgetID) event=\(event)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }

#if os(macOS)
    private enum ClickPathOrigin {
        case clickedSignal
        case captureRelease
    }

    /// Installs a CAPTURE-phase `GestureClick` and fires the handler
    /// on release, with a 250 ms watchdog timer as a safety net.
    ///
    /// **No `gtk_gesture_set_state(CLAIMED)` on press.** Earlier
    /// iterations of this helper claimed the sequence to keep
    /// Quartz's drag disambiguator out — that's the trick from the
    /// original sidebar fix (7e598e9). But the
    /// `SWIFTY_NOTES_DEBUG_CLICKS=1` trace showed CLAIM was actually
    /// what made GTK4-Quartz silently drop the `released` callback
    /// on fast clicks: with CLAIM, ~40 % of sub-80 ms press / release
    /// pairs lost their release; without CLAIM, the same widget
    /// tree delivers 100 % of releases AND lets a parallel
    /// `DragSource` controller (sidebar rows) win the sequence when
    /// real motion happens.
    ///
    /// The CAPTURE phase is kept so we slot in before the widget's
    /// own BUBBLE-phase gestures in dispatch order. `click` is
    /// captured by value in the callbacks so the wrapper stays alive —
    /// `widget.addController(click)` transfers GTK-side ownership but
    /// does not retain the Swift wrapper, and a weak capture would
    /// nil-out before the callback fires.
    ///
    /// The 250 ms watchdog timer remains as defence against a
    /// hypothetical future regression where `released` is genuinely
    /// dropped. In production it almost never fires; keeping it
    /// costs nothing and means a regression can't quietly resurrect
    /// the "fast click does nothing" symptom.
    ///
    /// Public so call sites that need raw control over the gesture
    /// (per-row sidebar handlers that also wire `onRightClick`
    /// elsewhere on the same row) can still benefit from the
    /// watchdog-recovered click semantics.
    static func attachReleaseHandler(
        to widget: Widget,
        label: String = "Widget",
        onRelease: @escaping @MainActor () -> Void,
    ) {
        let click = GestureClick()
        click.button = 1
        click.propagationPhase = .capture
        widget.addController(click)
        let pending = PendingClick()
        click.onPressed { [weak widget] _, _, _ in
            debugLog(label: label, widget: widget, event: "capture-pressed")
            pending.fired = false
            pending.workItem?.cancel()
            let workItem = DispatchWorkItem {
                MainActor.assumeIsolated {
                    guard !pending.fired else { return }
                    pending.fired = true
                    debugLog(label: label, widget: widget, event: "WATCHDOG-FIRED (release was lost)")
                    onRelease()
                }
            }
            pending.workItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + clickWatchdogDelay, execute: workItem)
        }
        click.onReleased { [weak widget] _, _, _ in
            pending.workItem?.cancel()
            if !pending.fired {
                pending.fired = true
                debugLog(label: label, widget: widget, event: "capture-released")
                onRelease()
            } else {
                debugLog(label: label, widget: widget, event: "capture-released ignored (watchdog already fired)")
            }
        }
    }

    /// Per-attach-site state for the watchdog timer. Held by the
    /// closures above; lives as long as the gesture (i.e. as long
    /// as the widget owning it).
    @MainActor
    private final class PendingClick {
        var workItem: DispatchWorkItem?
        var fired = false
    }

    /// 250 ms tuned from the SWIFTY_NOTES_DEBUG_CLICKS trace: every
    /// observed press-to-release delta on a real Quartz click was
    /// under 200 ms, so a 250 ms window catches lost releases
    /// quickly without ever firing the watchdog on a click that
    /// would have arrived a few ms later.
    private static let clickWatchdogDelay = 0.250

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
        label: String,
        handler: @escaping @MainActor () -> Void,
    ) -> @MainActor (ClickPathOrigin) -> Void {
        let key = ObjectIdentifier(widget)
        return { [weak widget] origin in
            let now = ContinuousClock.now
            if let last = lastClickFire[key], now - last < clickDedupWindow {
                debugLog(label: label, widget: widget, event: "DEDUP-SKIP origin=\(origin)")
                return
            }
            lastClickFire[key] = now
            debugLog(label: label, widget: widget, event: "HANDLER-INVOKE origin=\(origin)")
            handler()
        }
    }
    #endif
}
