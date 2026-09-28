import Foundation
import SkylineCore

/// A generated large tower for profiling (Phase 19): zones of 20 storeys, each served by a
/// local bank of two elevators; every zone above the first has a sky lobby reached by its
/// own express shuttle from the ground. Rentable floors hold offices in even zones and
/// studios in odd ones; plant rooms sit on each lobby floor and mid-zone. Developer and
/// benchmark tool only — never part of gameplay.
public enum StressTower {
    public static let zoneFloors = 20

    /// Columns the cores take: stairs, local bank, one express per upper zone.
    static func coreWidth(zones: Int) -> Int { 10 + 3 * max(zones - 1, 0) }

    /// The narrowest footprint that leaves room for units beside the cores.
    public static func minimumWidth(zones: Int) -> Int { coreWidth(zones: zones) + 26 }

    /// Lobby of zone `z` (0 = ground).
    static func lobby(_ z: Int) -> Int { z * (zoneFloors + 1) }

    public static func topFloor(zones: Int) -> Int { lobby(zones - 1) + zoneFloors }

    public static func blueprint(zones: Int, width: Int) -> Blueprint {
        precondition(zones >= 1 && width >= minimumWidth(zones: zones))
        var steps: [Blueprint.Step] = []
        func floor(_ level: Int) { steps.append(.init(floor: .init(level: level, start: 0, count: width))) }
        func room(_ id: String, _ start: Int, _ count: Int, _ lowest: Int, _ highest: Int? = nil) {
            steps.append(.init(room: .init(definition: id, start: start, count: count, lowest: lowest, highest: highest ?? lowest)))
        }
        let top = topFloor(zones: zones)
        for level in -1...top { floor(level) }
        let e = coreWidth(zones: zones)                 // first column after the cores
        room("stairs", 0, 4, -1, top)
        for z in 0..<zones {
            let base = lobby(z)
            for shaft in 0..<2 { room("elevator-shaft", 4 + 3 * shaft, 3, z == 0 ? -1 : base, base + zoneFloors) }
            if z > 0 { room("elevator-express", 10 + 3 * (z - 1), 3, 0, base) }
            // The zone's lobby floor: lobby (ground) or sky lobby, then plant; a second plant
            // floor mid-zone, so each zone supplies its own 20 storeys.
            room(z == 0 ? "lobby" : "sky-lobby", e, 6, base)
            room("electrical-room", e + 6, 8, base)
            room("mechanical", e + 14, 8, base)
            room("telecom-room", e + 22, 4, base)
            let plantFloor = base + zoneFloors / 2
            room("electrical-room", e, 8, plantFloor)
            room("mechanical", e + 8, 12, plantFloor)
            room("telecom-room", e + 20, 6, plantFloor)
            let unit = z % 2 == 0 ? ("office-small", 12) : ("apartment-studio", 10)
            for level in base + 1...base + zoneFloors where level != plantFloor {
                var x = e
                while x + unit.1 <= width {
                    room(unit.0, x, unit.1, level)
                    x += unit.1
                }
            }
        }
        room("parking", e, min(32, width - e), -1)
        return Blueprint(id: "stress-\(zones)x\(width)", name: "Stress Tower",
                         description: "Generated: \(zones) zones of \(zoneFloors) storeys, \(width) m wide (profiling only).", steps: steps)
    }

    /// A world with one city, a plot wide enough and the tower built through the
    /// construction engine (costs ignored: the ledger is topped up first).
    public static func world(zones: Int, width: Int, library: ContentLibrary) throws -> (world: GameWorld, property: PropertyID) {
        let city = library.city("port-calder")!
        var world = GameWorld(grid: .standard)
        let cityID = world.addCity(definitionID: city.id, name: city.name, seed: city.seed, economy: city.economy ?? CityEconomy())
        let plot = Plot(frontage: ColumnSpan(start: 0, count: width + 16), maxBasementFloors: 2, siteMargin: 40, strata: city.geology)
        let property = try world.addProperty(cityID: cityID, name: "Stress Lot", plot: plot)
        // Piles long enough for the whole height (storeysPerPileMeter), at least 30 m.
        let top = blueprint(zones: zones, width: width).steps.compactMap { $0.floor?.level }.max() ?? 0
        let piles = max(30, (Double(top + 1) / (library.buildRules.storeysPerPileMeter ?? 2)).rounded(.up) + 2)
        let building = try world.addBuilding(propertyID: property, name: "Stress Tower", footprint: ColumnSpan(start: 8, count: width),
                                             foundation: Foundation(basementFloors: 1, pileDepth: piles, pileSpacing: 4))
        world.ledger.post(Transaction(tick: 0, amount: 1_000_000_000, category: .grant, detail: "Stress test"))
        let engine = ConstructionEngine(catalog: library.buildCatalog)
        for c in blueprint(zones: zones, width: width).commands(for: world.buildings[building]!) { try engine.apply(c, to: &world) }
        return (world, property)
    }
}
