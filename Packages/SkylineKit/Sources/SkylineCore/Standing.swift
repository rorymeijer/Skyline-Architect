import Foundation

/// A building class (`progression.json`, Phase 11): what a building must reach to be
/// promoted to it, and how high it may then be built. Classes are ordered; index 0 is the
/// class every building starts in.
public struct BuildingClass: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// Tenant members (residents and workers) living or working in the building.
    public var population: Int
    /// Reputation (0…100) needed.
    public var reputation: Double
    /// Room definition ids of which the building must contain at least one each.
    public var requiredRooms: [String]
    /// Highest floor level that may be built while in this class (nil = no limit).
    public var maxFloor: Int?

    public init(id: String, name: String, population: Int, reputation: Double, requiredRooms: [String] = [], maxFloor: Int? = nil) {
        self.id = id
        self.name = name
        self.population = population
        self.reputation = reputation
        self.requiredRooms = requiredRooms
        self.maxFloor = maxFloor
    }
}

/// A building's reputation and class (Phase 11). Changed only by the simulation's daily
/// closing. The class never drops: what it unlocked stays unlocked (DECISIONS D-036).
public struct Standing: Codable, Hashable, Sendable {
    /// Index into the content's building classes.
    public var classLevel: Int
    /// 0…100; moves a fraction of the way to the day's assessment each morning.
    public var reputation: Double
    /// Tick of each promotion, in order (`promotions[i]` = reached class i + 1).
    public var promotions: [Tick]

    public init(classLevel: Int = 0, reputation: Double = 50, promotions: [Tick] = []) {
        self.classLevel = classLevel
        self.reputation = reputation
        self.promotions = promotions
    }
}

/// Whether room types and building height are gated by building class (a start's mode).
public enum UnlockMode: String, Codable, Sendable {
    /// Sandbox: everything is available; class and reputation are still tracked.
    case all
    /// Standard game: rooms need their `unlockClass`, floors their class's `maxFloor`.
    case byClass
}

extension GameWorld {
    /// The class whose unlocks apply to a building: its own class, or everything in a sandbox.
    public func unlockedClass(of building: BuildingID) -> Int {
        unlocks == .all ? Int.max : (buildings[building]?.standing.classLevel ?? 0)
    }

    /// Stores a building's reputation and class (the simulation's daily closing).
    public mutating func setStanding(_ standing: Standing, building: BuildingID) {
        buildings.update(building) { $0.standing = standing }
    }
}

extension BuildCatalog {
    /// The first class that allows building at `level` (nil if none does).
    public func classAllowing(floor level: Int) -> Int? {
        classes.firstIndex { ($0.maxFloor ?? .max) >= level }
    }
}
