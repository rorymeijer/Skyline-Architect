import Foundation
import SkylineCore
import SkylineSimulation

/// The whole estate for the UI (Phase 15): every owned property with its numbers, and the
/// land for sale.
public struct EstateSummary: Equatable, Sendable {
    public struct Holding: Equatable, Sendable {
        public var property: PropertyID
        public var name: String
        public var city: String
        public var floors: Int
        public var tenants: Int
        public var units: Int
        public var population: Int
        public var className: String
        public var reputation: Int
        /// Money booked to this property's buildings over the last 24 game hours.
        public var net24h: Int
        /// Today's weather in the property's city ("Storm 14°"; empty without weather).
        public var weather: String
    }

    public struct Offer: Equatable, Sendable {
        public var plotID: String
        public var name: String
        public var city: String
        public var price: Int
        public var frontage: Int
        public var basements: Int
        /// "rent ×1.35 · build ×1.25 · demand ×1.15"
        public var market: String
        public var affordable: Bool
    }

    public var holdings: [Holding] = []
    public var offers: [Offer] = []
    public var cities = 0
    /// Last 24 game hours: money not booked to a building (loans, interest, land, grants).
    /// Cash is one account for the whole estate (DECISIONS D-046), so these belong to no
    /// property.
    public var estateNet24h = 0
    /// Every transaction of the last 24 game hours: the holdings plus `estateNet24h`.
    public var totalNet24h = 0
    public var cash = 0

    public init() {}

    public static func make(world: GameWorld, library: ContentLibrary) -> EstateSummary {
        var s = EstateSummary()
        let catalog = library.buildCatalog
        let since = world.clock.tick >= 86_400 ? world.clock.tick - 86_400 : 0
        for property in world.properties.values {
            let buildings = world.buildings(on: property.id)
            let ids = Set(buildings.map(\.id))
            let units = buildings.flatMap { world.rooms(in: $0.id) }.filter { catalog.spec($0.definitionID)?.rentPerModule != nil }
            let best = buildings.max { $0.standing.classLevel < $1.standing.classLevel }
            let net = world.ledger.journal.filter { $0.tick >= since && $0.building.map(ids.contains) == true }.reduce(0) { $0 + $1.amount }
            let weather = world.cities[property.cityID]?.weather.flatMap { w in
                library.simulationRules.weather?.kind(w.today).map { "\($0.name) \(Int(w.temperature))°" }
            } ?? ""
            s.holdings.append(Holding(
                property: property.id, name: property.name, city: world.cities[property.cityID]?.name ?? "—",
                floors: buildings.reduce(0) { $0 + $1.floors.filter { $0.level >= 0 }.count },
                tenants: world.tenants.values.filter { ids.contains($0.buildingID) }.count, units: units.count,
                population: buildings.reduce(0) { $0 + Progression.population(of: $1.id, in: world) },
                className: best.flatMap { b in catalog.classes.indices.contains(b.standing.classLevel) ? catalog.classes[b.standing.classLevel].name : nil } ?? "—",
                reputation: Int((best?.standing.reputation ?? 0).rounded()), net24h: net, weather: weather))
        }
        s.cities = Set(world.properties.values.map(\.cityID)).count
        let recent = world.ledger.journal.filter { $0.tick >= since }
        s.estateNet24h = recent.filter { $0.building.map(world.buildings.contains) != true }.reduce(0) { $0 + $1.amount }
        s.totalNet24h = recent.reduce(0) { $0 + $1.amount }
        s.cash = world.ledger.cash
        s.offers = Estate.offers(world: world, library: library).map { o in
            let e = o.city.economy ?? CityEconomy()
            return Offer(plotID: o.plot.id, name: o.plot.name, city: o.city.name, price: o.price, frontage: o.plot.frontageModules,
                         basements: o.plot.maxBasementFloors,
                         market: String(format: "rent ×%.2f · build ×%.2f · demand ×%.2f", e.rent, e.construction, e.demand),
                         affordable: world.ledger.cash >= o.price)
        }
        return s
    }
}
