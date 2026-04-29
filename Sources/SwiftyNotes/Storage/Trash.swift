import Foundation

/// Author-facing setting for how long a soft-deleted note lives in
/// the trash before the repository auto-permanently-deletes it on
/// app launch.
public enum TrashRetention: Equatable, Sendable, Codable {
    case never
    case days(Int)
}

/// Disk record of a single note in `notes/.trash/<uuid>/` —
/// what the repository hands the auto-prune helper so the
/// pure decision logic can be unit-tested without a file
/// system.
public struct TrashEntry: Equatable, Sendable {
    public let id: UUID
    /// `nil` for legacy entries that landed in the trash before the
    /// feature shipped and don't carry a timestamp yet. The
    /// repository stamps them on first encounter so the *next* scan
    /// sees a real value.
    public let deletedAt: Date?

    public init(id: UUID, deletedAt: Date?) {
        self.id = id
        self.deletedAt = deletedAt
    }
}
