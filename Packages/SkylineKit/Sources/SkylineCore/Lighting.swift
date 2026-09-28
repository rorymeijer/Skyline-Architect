import Foundation

/// How a room type is lit (`rooms.json` → `lighting`, Phase 12). One model feeds both the
/// energy the simulation bills and the light the renderer draws.
public struct LightingSpec: Codable, Hashable, Sendable {
    /// Evening hours when the occupants dim or switch off (homes going to bed).
    public struct QuietHours: Codable, Hashable, Sendable {
        /// "HH:MM"; each room starts up to `spreadMinutes` later (stable per room).
        public var from: String
        public var to: String
        public var level: Double
        public var spreadMinutes: Int

        public init(from: String, to: String, level: Double, spreadMinutes: Int) {
            self.from = from
            self.to = to
            self.level = level
            self.spreadMinutes = spreadMinutes
        }
    }

    /// Light colour, "#RRGGBB" (interpreted by the renderer).
    public var color: String
    /// Level (0…1) while someone is in the room, and while it is empty.
    public var occupied: Double
    public var empty: Double
    /// Electric load at level 1, per module of width per floor.
    public var wattsPerModule: Double
    public var quietHours: QuietHours?

    public init(color: String, occupied: Double, empty: Double, wattsPerModule: Double, quietHours: QuietHours? = nil) {
        self.color = color
        self.occupied = occupied
        self.empty = empty
        self.wattsPerModule = wattsPerModule
        self.quietHours = quietHours
    }

    /// Validation problems (empty if valid).
    public var problems: [String] {
        var p: [String] = []
        if !(0...1).contains(occupied) || !(0...1).contains(empty) { p.append("lighting levels must be 0…1") }
        if wattsPerModule < 0 { p.append("lighting wattsPerModule must be ≥ 0") }
        if let q = quietHours {
            if Lighting.parseTime(q.from) == nil || Lighting.parseTime(q.to) == nil { p.append("lighting quietHours need HH:MM times") }
            if !(0...1).contains(q.level) || !(0...240).contains(q.spreadMinutes) { p.append("lighting quietHours level 0…1, spread 0…240 min") }
        }
        return p
    }
}

/// Room lighting levels (Phase 12). Pure functions of the room, its occupancy, the time of
/// day and its power supply — deterministic, never saved.
public enum Lighting {
    /// Level 0…1 of a room's lights. `power` is the served electricity fraction (a room
    /// without power is dark).
    public static func level(_ spec: LightingSpec, room: RoomID, occupied: Bool, secondOfDay: Tick, power: Double = 1) -> Double {
        var level = occupied ? spec.occupied : spec.empty
        if let q = spec.quietHours, let from = parseTime(q.from), let to = parseTime(q.to) {
            let offset = Tick(room.raw &* 2_654_435_761 % UInt32(max(q.spreadMinutes, 1) * 60))
            let day = Tick(SimClock.secondsPerDay)
            let start = (from + offset) % day, end = (to + offset) % day
            let quiet = start <= end ? (secondOfDay >= start && secondOfDay < end) : (secondOfDay >= start || secondOfDay < end)
            if quiet { level = min(level, q.level) }
        }
        return level * min(max(power, 0), 1)
    }

    /// Rooms somebody is in right now.
    public static func occupiedRooms(_ world: GameWorld) -> Set<RoomID> {
        var rooms = Set<RoomID>()
        for p in world.people { if case let .room(r, _) = p.place { rooms.insert(r) } }
        return rooms
    }

    /// Electric load of a lit room in watts.
    public static func watts(_ spec: LightingSpec, room: Room, level: Double) -> Double {
        spec.wattsPerModule * Double(room.columns.count * room.floors.count) * level
    }

    /// "HH:MM" → seconds after midnight.
    static func parseTime(_ s: String) -> Tick? {
        let parts = s.split(separator: ":")
        guard parts.count == 2, let h = Tick(parts[0]), let m = Tick(parts[1]), h < 24, m < 60 else { return nil }
        return h * 3600 + m * 60
    }
}
