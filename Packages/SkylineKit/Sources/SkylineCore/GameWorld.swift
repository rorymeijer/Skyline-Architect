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
    /// Local market (Phase 15): multipliers on rents, construction costs and tenant demand.
    public var economy: CityEconomy
    /// Today's weather and the forecast here (per city since save format 14; nil until the
    /// simulation starts it).
    public var weather: WeatherState?
    /// Today's energy price, as a multiplier (Phase E; nil = the city's base level). Moves
    /// every morning around `economy.energy`.
    public var energyPrice: Double?

    public init(id: CityID, definitionID: String, name: String, seed: UInt64, economy: CityEconomy = CityEconomy(),
                weather: WeatherState? = nil) {
        self.id = id
        self.definitionID = definitionID
        self.name = name
        self.seed = seed
        self.economy = economy
        self.weather = weather
    }
}

/// How expensive and lively a city is (Phase 15; 1 = the base game's Port Calder).
public struct CityEconomy: Codable, Hashable, Sendable {
    public var rent: Double
    public var construction: Double
    public var demand: Double
    /// Property tax level and base energy price (Phase E; nil = 1).
    public var tax: Double?
    public var energy: Double?

    public init(rent: Double = 1, construction: Double = 1, demand: Double = 1, tax: Double? = nil, energy: Double? = nil) {
        self.rent = rent
        self.construction = construction
        self.demand = demand
        self.tax = tax
        self.energy = energy
    }
}

/// Land owned (or available) in a city. Each property has its own coordinate space.
public struct Property: Codable, Hashable, Sendable, Identifiable {
    public let id: PropertyID
    public var cityID: CityID
    public var name: String
    public var plot: Plot
    /// Content plot this property was bought as (Phase 15; nil for properties of older saves
    /// until they are matched on load).
    public var plotID: String?

    public init(id: PropertyID, cityID: CityID, name: String, plot: Plot, plotID: String? = nil) {
        self.id = id
        self.cityID = cityID
        self.name = name
        self.plot = plot
        self.plotID = plotID
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
    /// Whether rooms and height are gated by building class (Phase 11; set by the start).
    public var unlocks = UnlockMode.all
    /// Fires in progress and the incident log (Phase 14).
    public var incidents = IncidentState()
    /// The scenario being played (Phase 16; nil = free play).
    public var scenario: ScenarioState?
    /// Simulation clock. Advanced only by the simulation.
    public var clock = SimClock()
    var ids = IDAllocator()

    public init(grid: GridSpec = .standard) {
        self.grid = grid
    }

    @discardableResult
    public mutating func addCity(definitionID: String, name: String, seed: UInt64, economy: CityEconomy = CityEconomy()) -> CityID {
        let id: CityID = ids.make()
        cities.insert(City(id: id, definitionID: definitionID, name: name, seed: seed, economy: economy))
        return id
    }

    @discardableResult
    public mutating func addProperty(cityID: CityID, name: String, plot: Plot, plotID: String? = nil) throws -> PropertyID {
        guard cities.contains(cityID) else { throw WorldError.unknownCity(cityID) }
        let id: PropertyID = ids.make()
        properties.insert(Property(id: id, cityID: cityID, name: name, plot: plot, plotID: plotID))
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

    /// The active scenario's restrictions (Phase C; nil in free play).
    public var restrictions: ScenarioRestrictions? { scenario?.restrictions }

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

    /// The city a building stands in.
    public func city(of building: BuildingID) -> City? {
        buildings[building].flatMap { properties[$0.propertyID] }.flatMap { cities[$0.cityID] }
    }

    /// Matches older properties to their content plot (Phase 15) and sets a city's market.
    public mutating func setPlotID(_ plotID: String, property: PropertyID) {
        properties.update(property) { $0.plotID = plotID }
    }

    public mutating func setEconomy(_ economy: CityEconomy, city: CityID) {
        cities.update(city) { $0.economy = economy }
    }

    /// Player rent setting of one unit (0.22+), clamped to 0.6…1.6 in steps of 0.1. Not
    /// construction: no command, no undo.
    public mutating func setRentFactor(_ factor: Double, room: RoomID) {
        let f = (min(max(factor, 0.6), 1.6) * 10).rounded() / 10
        rooms.update(room) { $0.rentFactor = f == 1 ? nil : f }
    }

    /// Offers a unit for rent or for sale (checks are the market's, `Leasing.setTenure`).
    public mutating func setTenure(_ tenure: Tenure?, room: RoomID) {
        rooms.update(room) { $0.tenure = tenure == .rent ? nil : tenure }
    }

    /// Sets a city's energy price (the simulation's 06:00 step; tests and captures).
    public mutating func setEnergyPrice(_ price: Double?, city: CityID) {
        cities.update(city) { $0.energyPrice = price }
    }

    /// Sets a city's weather (the simulation's 06:00 step; tests and captures).
    public mutating func setWeather(_ weather: WeatherState?, city: CityID) {
        cities.update(city) { $0.weather = weather }
    }
}
