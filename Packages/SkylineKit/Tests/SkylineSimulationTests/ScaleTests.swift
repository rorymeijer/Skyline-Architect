import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// Phase 19: the generated stress tower and the optimisations measured with `skyline-bench`.
/// Timings live in PERFORMANCE.md; these tests pin behaviour, not speed.
@Suite struct ScaleTests {
    let library = try! ContentLibrary.loadBase()
    var engine: SimulationEngine { SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog) }

    @Test func stressTowerBuildsAndIsServed() throws {
        let (world, property) = try StressTower.world(zones: 3, width: StressTower.minimumWidth(zones: 3), library: library)
        let building = try #require(world.buildings(on: property).first)
        #expect(building.builtLevels == FloorSpan(lowest: -1, highest: StressTower.topFloor(zones: 3)))
        #expect(StressTower.topFloor(zones: 3) == 62)
        let rooms = world.rooms(in: building.id)
        #expect(rooms.filter { $0.definitionID == "sky-lobby" }.count == 2)
        #expect(rooms.filter { $0.definitionID == "elevator-express" }.map(\.floors.highest).sorted() == [21, 42])
        // Every unit gets all its utilities from its zone's plant.
        let service = Utilities.allocate(building: building.id, world: world, catalog: library.buildCatalog, rules: library.simulationRules)
        let units = rooms.filter { library.buildCatalog.spec($0.definitionID)?.rentPerModule != nil }
        #expect(units.count == 114 && units.allSatisfy { service.minimum($0.id) > 0.99 })
        try world.validateIntegrity()
    }

    /// Everyone in a 63-storey, three-zone tower reaches work through local banks, express
    /// shuttles and sky lobbies, and the daily closing runs.
    @Test func stressTowerRunsADay() throws {
        var (world, _) = try StressTower.world(zones: 3, width: StressTower.minimumWidth(zones: 3), library: library)
        let rules = library.simulationRules, catalog = library.buildCatalog
        PopulationSync.sync(&world, catalog: catalog, rules: rules)
        Leasing.fillAll(&world, catalog: catalog, rules: rules)
        let sim = engine
        sim.replanAfterConstruction(&world)
        sim.advance(&world, by: 5 * 3600)                       // 11:00
        let workers = world.people.values.filter { $0.role == .worker }
        let atWork = workers.filter { if case let .room(r, _) = $0.place { r == $0.workRoom } else { false } }.count
        #expect(workers.count > 150 && atWork == workers.count)
        #expect(world.people.values.allSatisfy { !$0.unreachable })
        sim.advance(&world, by: 19 * 3600 + 60)                  // past the next closing
        #expect(world.tenants.count == 114)
        try world.validateIntegrity()
    }

    /// Sharing one utility allocation per building (daily review, market hour) gives exactly
    /// the appraisal of allocating per unit.
    @Test func sharedServicesGiveTheSameAppraisal() throws {
        var (world, property) = try StressTower.world(zones: 2, width: StressTower.minimumWidth(zones: 2), library: library)
        let rules = library.simulationRules
        Leasing.fillAll(&world, catalog: library.buildCatalog, rules: rules)
        let sim = engine
        let services = sim.utilityServices(world, buildings: world.buildings(on: property).map(\.id))
        for tenant in world.tenants.values.prefix(40) {
            let room = try #require(world.rooms[tenant.room]), type = try #require(rules.tenantType(tenant.typeID))
            #expect(Leasing.appraise(room, for: type, world: world, engine: sim, services: services)
                    == Leasing.appraise(room, for: type, world: world, engine: sim))
        }
    }

    /// Cached banks equal freshly computed ones, follow strategy changes and are dropped
    /// when the structure changes.
    @Test func cachedBanksMatchComputedBanks() throws {
        let (built, property) = try StressTower.world(zones: 3, width: StressTower.minimumWidth(zones: 3), library: library)
        var world = built
        let sim = engine
        sim.replanAfterConstruction(&world)
        let building = try #require(world.buildings(on: property).first).id
        let fresh = ElevatorBanks.banks(in: world, rules: library.simulationRules, building: building)
        #expect(sim.banks(of: building, in: world) == fresh && fresh.count == 4)   // 3 local banks + the two touching expresses
        let low = try #require(fresh.first)
        ElevatorBanks.setStrategy(.destination, bank: low.id, in: &world, rules: library.simulationRules)
        #expect(sim.bank(of: low.cars[1], in: world)?.strategy == .destination)
        // Removing a shaft changes the structure: the cache is rebuilt.
        let construction = ConstructionEngine(catalog: library.buildCatalog)
        try construction.apply(.demolishRoom(low.cars[1]), to: &world)
        sim.replanAfterConstruction(&world)
        #expect(sim.banks(of: building, in: world) == ElevatorBanks.banks(in: world, rules: library.simulationRules, building: building))
        #expect(sim.bank(of: low.id, in: world)?.cars == [low.id])
    }

    /// F2: warming the route cache ahead (the app does it in the background) changes nothing
    /// but speed: the day plays out exactly as with a cold cache.
    @Test func warmRouteCacheChangesNothing() throws {
        var (cold, _) = try StressTower.world(zones: 2, width: StressTower.minimumWidth(zones: 2), library: library)
        let rules = library.simulationRules, catalog = library.buildCatalog
        PopulationSync.sync(&cold, catalog: catalog, rules: rules)
        Leasing.fillAll(&cold, catalog: catalog, rules: rules)
        var warm = cold
        let a = engine, b = engine
        a.replanAfterConstruction(&cold)
        b.replanAfterConstruction(&warm)
        b.warmRouteCache(warm)
        #expect(b.navigation.metrics.queries > 0)
        a.advance(&cold, by: 24 * 3600 + 600)
        b.advance(&warm, by: 24 * 3600 + 600)
        #expect(cold == warm)
    }

    /// F2: a broken-down car is left out of route queries without rebuilding the graph.
    @Test func breakdownKeepsTheGraph() throws {
        var (world, _) = try StressTower.world(zones: 2, width: StressTower.minimumWidth(zones: 2), library: library)
        let rules = library.simulationRules, catalog = library.buildCatalog
        PopulationSync.sync(&world, catalog: catalog, rules: rules)
        Leasing.fillAll(&world, catalog: catalog, rules: rules)
        let sim = engine
        sim.replanAfterConstruction(&world)
        sim.advance(&world, by: 3 * 3600)
        let builds = sim.navigation.metrics.graphBuilds
        let car = try #require(world.rooms.values.first { $0.definitionID == "elevator-shaft" }).id
        world.upkeep.update(car) { $0.condition = 0 }
        var steps = 0
        while world.elevators[car]?.isOutOfService != true && steps < 600 {
            sim.advance(&world, by: 30)
            steps += 1
        }
        #expect(world.elevators[car]?.isOutOfService == true)
        sim.advance(&world, by: 1800)
        #expect(sim.navigation.metrics.graphBuilds == builds)
        #expect(world.people.values.allSatisfy { p in
            if case let .waiting(r, _, _) = p.place { r.shaft != car } else { true }
        })
    }
}
