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
    public var totalNet24h = 0

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
            s.holdings.append(Holding(
                property: property.id, name: property.name, city: world.cities[property.cityID]?.name ?? "—",
                floors: buildings.reduce(0) { $0 + $1.floors.filter { $0.level >= 0 }.count },
                tenants: world.tenants.values.filter { ids.contains($0.buildingID) }.count, units: units.count,
                population: buildings.reduce(0) { $0 + Progression.population(of: $1.id, in: world) },
                className: best.flatMap { b in catalog.classes.indices.contains(b.standing.classLevel) ? catalog.classes[b.standing.classLevel].name : nil } ?? "—",
                reputation: Int((best?.standing.reputation ?? 0).rounded()), net24h: net))
        }
        s.cities = Set(world.properties.values.map(\.cityID)).count
        s.totalNet24h = s.holdings.reduce(0) { $0 + $1.net24h }
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
