import Foundation

public enum CityTag {}
public typealias CityID = EntityID<CityTag>
public enum PropertyTag {}
public typealias PropertyID = EntityID<PropertyTag>

/// A city the player operates in. Economic variables arrive with Phase 9/15; the
/// definition id links back to content for everything not stored per save.
public struct City: Codable, Hashable, Sendable, Identifiable {
    public let id: CityID
    /// Content definition id (e.g. `"port-calder"`).
    public var definitionID: String
    public var name: String
    /// Seed for procedural content of this city (backdrop skyline, etc.).
    public var seed: UInt64

    public init(id: CityID, definitionID: String, name: String, seed: UInt64) {
        self.id = id
        self.definitionID = definitionID
        self.name = name
        self.seed = seed
    }
}

/// Land owned (or available) in a city. Each property has its own coordinate space.
public struct Property: Codable, Hashable, Sendable, Identifiable {
    public let id: PropertyID
    public var cityID: CityID
    public var name: String
    public var plot: Plot

    public init(id: PropertyID, cityID: CityID, name: String, plot: Plot) {
        self.id = id
        self.cityID = cityID
        self.name = name
        self.plot = plot
    }
}

public enum WorldError: Error, Equatable, CustomStringConvertible {
    case unknownCity(CityID)
    case unknownProperty(PropertyID)
    case footprintOutsidePlot(ColumnSpan, plot: ColumnSpan)
    case footprintOverlapsBuilding(BuildingID)
    case basementTooDeep(requested: Int, allowed: Int)
    case pilesTooShort(pileDepth: Double, requiredBelow: Double)
    case invalidFoundation(String)

    public var description: String {
        switch self {
        case .unknownCity(let id): "Unknown city \(id)"
        case .unknownProperty(let id): "Unknown property \(id)"
        case .footprintOutsidePlot(let f, let p): "Footprint \(f) lies outside plot \(p)"
        case .footprintOverlapsBuilding(let id): "Footprint overlaps building \(id)"
        case .basementTooDeep(let r, let a): "\(r) basement floors requested, plot allows \(a)"
        case .pilesTooShort(let d, let r): "Piles reach \(d) m but must extend below \(r) m"
        case .invalidFoundation(let why): "Invalid foundation: \(why)"
        }
    }
}

/// Root of all authoritative game state. Value type: copying it yields an independent
/// snapshot (cheap until mutated thanks to copy-on-write arrays).
public struct GameWorld: Codable, Sendable, Equatable {
    public var grid: GridSpec
    public private(set) var cities = EntityStore<City>()
    public private(set) var properties = EntityStore<Property>()
    public internal(set) var buildings = EntityStore<Building>()
    public internal(set) var rooms = EntityStore<Room>()
    /// Simulated people (Phase 4). Mutated only by the simulation.
    public var people = EntityStore<Person>()
    /// Elevator cars, one per elevator shaft (Phase 6). Mutated only by the simulation.
    public var elevators = EntityStore<ElevatorCar>()
    /// Households and businesses renting units (Phase 8). Mutated only by the simulation.
    public var tenants = EntityStore<Tenant>()
    /// Rental market state (Phase 8).
    public var market = MarketState()
    /// Money (Phase 9). Changed only through `Ledger.post`.
    public var ledger = Ledger()
    /// Wear and cleanliness per room (Phase 10), kept in step with `rooms` by the simulation.
    public var upkeep = EntityStore<Upkeep>()
    /// Facilities jobs and counters (Phase 10).
    public var facilities = FacilitiesState()
    /// Simulation clock. Advanced only by the simulation.
    public var clock = SimClock()
    var ids = IDAllocator()

    public init(grid: GridSpec = .standard) {
        self.grid = grid
    }

    @discardableResult
    public mutating func addCity(definitionID: String, name: String, seed: UInt64) -> CityID {
        let id: CityID = ids.make()
        cities.insert(City(id: id, definitionID: definitionID, name: name, seed: seed))
        return id
    }

    @discardableResult
    public mutating func addProperty(cityID: CityID, name: String, plot: Plot) throws -> PropertyID {
        guard cities.contains(cityID) else { throw WorldError.unknownCity(cityID) }
        let id: PropertyID = ids.make()
        properties.insert(Property(id: id, cityID: cityID, name: name, plot: plot))
        return id
    }

    /// Adds a building after validating footprint and foundation against the plot.
    @discardableResult
    public mutating func addBuilding(
        propertyID: PropertyID, name: String, footprint: ColumnSpan, foundation: Foundation
    ) throws -> BuildingID {
        guard let property = properties[propertyID] else { throw WorldError.unknownProperty(propertyID) }
        let plot = property.plot
        guard footprint.count > 0, plot.frontage.contains(footprint) else {
            throw WorldError.footprintOutsidePlot(footprint, plot: plot.frontage)
        }
        if let clash = buildings(on: propertyID).first(where: { $0.footprint.overlaps(footprint) }) {
            throw WorldError.footprintOverlapsBuilding(clash.id)
        }
        guard foundation.basementFloors >= 0 else {
            throw WorldError.invalidFoundation("negative basement floors")
        }
        guard foundation.basementFloors <= plot.maxBasementFloors else {
            throw WorldError.basementTooDeep(requested: foundation.basementFloors, allowed: plot.maxBasementFloors)
        }
        guard foundation.pileSpacing > 0 else { throw WorldError.invalidFoundation("pile spacing must be positive") }
        let raftBottomDepth = -foundation.raftBottomY(grid: grid)
        guard foundation.pileDepth > raftBottomDepth else {
            throw WorldError.pilesTooShort(pileDepth: foundation.pileDepth, requiredBelow: raftBottomDepth)
        }
        let id: BuildingID = ids.make()
        buildings.insert(Building(id: id, propertyID: propertyID, name: name, footprint: footprint, foundation: foundation))
        return id
    }

    /// Buildings on a property, in construction order.
    public func buildings(on propertyID: PropertyID) -> [Building] {
        buildings.filter { $0.propertyID == propertyID }
    }

    /// Allocates a fresh person id (used by the simulation's population system).
    public mutating func makePersonID() -> PersonID { ids.make() }

    /// Player rent setting of a building (Phase 9), clamped to 0.6…1.6. Not construction:
    /// no command, no undo.
    public mutating func setRentLevel(_ level: Double, building: BuildingID) {
        buildings.update(building) { $0.rentLevel = min(max(level, 0.6), 1.6) }
    }

    /// Allocates a fresh tenant id (used by the simulation's leasing system).
    public mutating func makeTenantID() -> TenantID { ids.make() }

    /// Rooms of a building, in placement order.
    public func rooms(in buildingID: BuildingID) -> [Room] {
        rooms.filter { $0.buildingID == buildingID }
    }

    /// The room occupying a cell of a building, if any.
    public func room(in buildingID: BuildingID, column: Int, floor: Int) -> Room? {
        rooms.first { $0.buildingID == buildingID && $0.occupies(column: column, floor: floor) }
    }

    public func properties(in cityID: CityID) -> [Property] {
        properties.filter { $0.cityID == cityID }
    }
}
