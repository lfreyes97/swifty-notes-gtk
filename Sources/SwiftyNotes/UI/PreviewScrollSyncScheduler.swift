import Adwaita
import Foundation

/// Coalesces bursts of editor-scroll change notifications into a single
/// preview-sync callback on the next main-loop drain.
///
/// GTK emits `Adjustment::value-changed` aggressively while the user
/// drags or wheel-scrolls. Recomputing the preview scroll position for
/// every intermediate value adds avoidable work on top of the already
/// expensive snapshot/render path. This helper keeps only one pending
/// sync per drain while still syncing against the freshest adjustment
/// values when the callback finally runs.
@MainActor
final class PreviewScrollSyncScheduler {
    private let schedule: (@escaping @MainActor () -> Void) -> Void
    private let sync: @MainActor () -> Void

    private var hasPendingSync = false
    private var generation = 0

    init(
        schedule: @escaping (@escaping @MainActor () -> Void) -> Void = { action in
            MainContext.idle { action() }
        },
        sync: @escaping @MainActor () -> Void,
    ) {
        self.schedule = schedule
        self.sync = sync
    }

    func requestSync() {
        guard !hasPendingSync else { return }
        hasPendingSync = true
        let scheduledGeneration = generation
        schedule { [weak self] in
            guard let self, self.generation == scheduledGeneration else { return }
            self.hasPendingSync = false
            self.sync()
        }
    }

    func cancel() {
        generation += 1
        hasPendingSync = false
    }
}
