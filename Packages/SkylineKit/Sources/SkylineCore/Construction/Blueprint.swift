import Foundation

/// A declarative sequence of construction steps with columns relative to a building's
/// footprint. Used for developer tools, automated captures and tests; scenarios can later
/// reuse the same format.
public struct Blueprint: Codable, Hashable, Sendable {
    public struct FloorStep: Codable, Hashable, Sendable {
        public var level: Int
        public var start: Int
        public var count: Int

        public init(level: Int, start: Int, count: Int) {
            self.level = level
            self.start = start
            self.count = count
        }
    }

    public struct RoomStep: Codable, Hashable, Sendable {
        public var definition: String
        public var start: Int
        public var count: Int
        public var lowest: Int
        public var highest: Int

        public init(definition: String, start: Int, count: Int, lowest: Int, highest: Int) {
            self.definition = definition
            self.start = start
            self.count = count
            self.lowest = lowest
            self.highest = highest
        }
    }

    /// Exactly one of `floor` / `room` is set.
    public struct Step: Codable, Hashable, Sendable {
        public var floor: FloorStep?
        public var room: RoomStep?

        public init(floor: FloorStep? = nil, room: RoomStep? = nil) {
            self.floor = floor
            self.room = room
        }
    }

    public var id: String
    public var name: String
    public var description: String
    public var steps: [Step]

    public init(id: String, name: String, description: String, steps: [Step]) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
    }

    /// The commands this blueprint issues for `building` (footprint-relative columns).
    public func commands(for building: Building) -> [BuildCommand] {
        let x0 = building.footprint.start
        return steps.compactMap { step in
            if let f = step.floor {
                return .buildFloor(building: building.id, level: f.level, span: ColumnSpan(start: x0 + f.start, count: f.count))
            }
            if let r = step.room {
                return .placeRoom(building: building.id, definition: r.definition,
                                  columns: ColumnSpan(start: x0 + r.start, count: r.count),
                                  floors: FloorSpan(lowest: r.lowest, highest: r.highest))
            }
            return nil
        }
    }
}
