import Foundation
import SkylineCore

/// Fires in progress and the incident log for the UI (Phase 14).
public struct IncidentSummary: Equatable, Sendable {
    public struct ActiveFire: Equatable, Sendable {
        public var incident: Int
        public var detail: String
        public var burningRooms: Int
        public var minutes: Int
        /// Minutes until the brigade arrives (0 = on site).
        public var brigadeInMinutes: Int
        /// The first burning room (for the camera).
        public var room: RoomID?
    }

    public struct Entry: Equatable, Sendable {
        public var id: Int
        public var kind: String
        public var when: String
        public var detail: String
        public var ongoing: Bool
    }

    public var fires: [ActiveFire] = []
    /// Newest first.
    public var recent: [Entry] = []
    public var latestID = 0

    public init() {}

    public static func make(world: GameWorld, limit: Int = 12) -> IncidentSummary {
        var s = IncidentSummary()
        let now = world.clock.tick
        for fire in world.incidents.fires {
            guard let incident = world.incidents.log.first(where: { $0.id == fire.incident }) else { continue }
            s.fires.append(ActiveFire(incident: fire.incident, detail: incident.detail, burningRooms: fire.burning.count,
                                      minutes: Int((now - incident.started) / 60),
                                      brigadeInMinutes: fire.brigadeArrives > now ? Int((fire.brigadeArrives - now + 59) / 60) : 0,
                                      room: fire.burning.first?.room))
        }
        s.recent = world.incidents.log.suffix(limit).reversed().map { i in
            Entry(id: i.id, kind: i.kind, when: "Day \(SimClock.day(i.started) + 1) · \(SimClock.timeString(i.started))",
                  detail: i.detail, ongoing: i.ended == nil)
        }
        s.latestID = world.incidents.log.last?.id ?? 0
        return s
    }
}
