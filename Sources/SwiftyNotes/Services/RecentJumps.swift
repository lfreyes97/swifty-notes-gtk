import Foundation

/// Newest-first list of heading ids the user recently jumped to from
/// the Ctrl+G command palette. Capped so the "Recent jumps" group never
/// dwarfs the rest of the list.
///
/// Stored in-memory on ``MainWindow`` for now; Phase 9 lifts it into
/// `WorkspaceState` for cross-session persistence.
struct RecentJumps: Equatable, Sendable {
    static let cap = 5

    private(set) var ids: [String]

    init() {
        self.ids = []
    }

    init(ids: [String]) {
        var seen = Set<String>()
        var deduped: [String] = []
        for id in ids {
            if seen.insert(id).inserted {
                deduped.append(id)
            }
        }
        self.ids = Array(deduped.prefix(Self.cap))
    }

    mutating func record(_ id: String) {
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
        if ids.count > Self.cap {
            ids.removeLast(ids.count - Self.cap)
        }
    }
}
