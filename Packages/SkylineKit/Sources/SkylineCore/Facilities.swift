import Foundation

/// Physical state of a room (Phase 10): wear and cleanliness, 0 (bad) … 1 (new/clean).
/// Kept beside the room (same id) so construction commands and their undo stay pure.
public struct Upkeep: Codable, Hashable, Sendable, Identifiable {
    public let id: RoomID
    public var condition: Double
    public var cleanliness: Double

    public init(id: RoomID, condition: Double = 1, cleanliness: Double = 1) {
        self.id = id
        self.condition = condition
        self.cleanliness = cleanliness
    }
}

public enum JobKind: String, Codable, CaseIterable, Hashable, Sendable {
    case clean, repair
}

/// Work waiting for (or being done by) a staff member.
public struct FacilityJob: Codable, Hashable, Sendable {
    public var room: RoomID
    public var kind: JobKind
    public var created: Tick
    public var assignee: PersonID?

    public init(room: RoomID, kind: JobKind, created: Tick, assignee: PersonID? = nil) {
        self.room = room
        self.kind = kind
        self.created = created
        self.assignee = assignee
    }
}

/// What a staff member is doing: heading to or working on a job in `room`.
public struct JobAssignment: Codable, Hashable, Sendable {
    public var room: RoomID
    public var kind: JobKind
    /// Set once work has started: when it will be done.
    public var until: Tick?

    public init(room: RoomID, kind: JobKind, until: Tick? = nil) {
        self.room = room
        self.kind = kind
        self.until = until
    }
}

/// Facilities management state (saved): the open job list and what was done.
public struct FacilitiesState: Codable, Hashable, Sendable {
    public var jobs: [FacilityJob] = []
    public var cleaned = 0
    public var repaired = 0
    /// Elevator breakdowns so far (Phase E; nil in older saves = 0).
    public var breakdowns: Int?

    public init() {}
}
