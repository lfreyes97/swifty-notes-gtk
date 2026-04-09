import Foundation
import GObjectSupport

@MainActor
public final class AutosaveCoordinator {
    private var currentSourceID: SourceID?

    public init() {}

    public func scheduleSave(
        after delay: Duration = .milliseconds(400),
        operation: @escaping @MainActor () -> Void
    ) {
        cancel()
        currentSourceID = MainContext.timeout(intervalMs: milliseconds(from: delay)) { [weak self] in
            self?.currentSourceID = nil
            operation()
            return false
        }
    }

    public func cancel() {
        guard let currentSourceID else { return }
        MainContext.cancel(sourceId: currentSourceID)
        self.currentSourceID = nil
    }

    private func milliseconds(from duration: Duration) -> UInt32 {
        let components = duration.components
        let secondsMilliseconds = components.seconds * 1_000
        let attosecondsMilliseconds = components.attoseconds / 1_000_000_000_000_000
        let totalMilliseconds = max(0, secondsMilliseconds + attosecondsMilliseconds)
        return UInt32(clamping: totalMilliseconds)
    }
}
