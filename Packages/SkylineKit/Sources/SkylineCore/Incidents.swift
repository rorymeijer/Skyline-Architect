import Foundation

/// Something that happened to a building (Phase 14): a fire, storm damage, a power outage…
/// Kept in a bounded log for the player.
public struct Incident: Codable, Hashable, Sendable, Identifiable {
    public var id: Int
    /// "fire" or an incident definition id from `events.json`.
    public var kind: String
    public var name: String
    public var building: BuildingID
    /// Rooms affected (for a fire: every room that burnt).
    public var rooms: [RoomID]
    public var started: Tick
    /// Nil while it is still going on (fires).
    public var ended: Tick?
    public var detail: String

    public init(id: Int, kind: String, name: String, building: BuildingID, rooms: [RoomID], started: Tick, ended: Tick?, detail: String) {
        self.id = id
        self.kind = kind
        self.name = name
        self.building = building
        self.rooms = rooms
        self.started = started
        self.ended = ended
        self.detail = detail
    }
}

/// A fire in progress: which rooms burn and how strongly (0…1), when the fire brigade
/// arrives and when the fire is next stepped.
public struct Fire: Codable, Hashable, Sendable {
    public struct Burning: Codable, Hashable, Sendable {
        public var room: RoomID
        public var intensity: Double

        public init(room: RoomID, intensity: Double) {
            self.room = room
            self.intensity = intensity
        }
    }

    public var incident: Int
    public var building: BuildingID
    /// Burning rooms in ignition order (deterministic).
    public var burning: [Burning]
    public var brigadeArrives: Tick
    public var nextStep: Tick

    public init(incident: Int, building: BuildingID, burning: [Burning], brigadeArrives: Tick, nextStep: Tick) {
        self.incident = incident
        self.building = building
        self.burning = burning
        self.brigadeArrives = brigadeArrives
        self.nextStep = nextStep
    }
}

/// Incidents of the world (Phase 14): the log, fires in progress and the id counter.
public struct IncidentState: Codable, Hashable, Sendable {
    public var log: [Incident] = []
    public var fires: [Fire] = []
    public var nextID = 1

    public init() {}

    /// Keep the log bounded (newest last).
    public static let logLimit = 60

    /// A building with a fire in progress: everyone keeps out.
    public func isOnFire(_ building: BuildingID) -> Bool { fires.contains { $0.building == building } }

    public mutating func record(_ incident: Incident) {
        log.append(incident)
        if log.count > Self.logLimit { log.removeFirst(log.count - Self.logLimit) }
    }

    public mutating func update(_ id: Int, _ body: (inout Incident) -> Void) {
        if let i = log.firstIndex(where: { $0.id == id }) { body(&log[i]) }
    }
}
