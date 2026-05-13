import Foundation
@testable import SwiftyNotes
import Testing

@MainActor
struct PreviewScrollSyncSchedulerTests {
    @Test
    func `request sync coalesces multiple pending requests into one callback`() {
        let scheduler = TestMainActorScheduler()
        var syncCount = 0
        let subject = PreviewScrollSyncScheduler(
            schedule: scheduler.schedule,
            sync: { syncCount += 1 },
        )

        subject.requestSync()
        subject.requestSync()
        subject.requestSync()

        #expect(syncCount == 0)

        scheduler.runPendingActions()

        #expect(syncCount == 1)
    }

    @Test
    func `request sync schedules again after previous callback drains`() {
        let scheduler = TestMainActorScheduler()
        var syncCount = 0
        let subject = PreviewScrollSyncScheduler(
            schedule: scheduler.schedule,
            sync: { syncCount += 1 },
        )

        subject.requestSync()
        scheduler.runPendingActions()
        subject.requestSync()
        scheduler.runPendingActions()

        #expect(syncCount == 2)
    }

    @Test
    func `cancel drops pending callback but allows future requests`() {
        let scheduler = TestMainActorScheduler()
        var syncCount = 0
        let subject = PreviewScrollSyncScheduler(
            schedule: scheduler.schedule,
            sync: { syncCount += 1 },
        )

        subject.requestSync()
        subject.cancel()
        scheduler.runPendingActions()

        #expect(syncCount == 0)

        subject.requestSync()
        scheduler.runPendingActions()

        #expect(syncCount == 1)
    }
}
