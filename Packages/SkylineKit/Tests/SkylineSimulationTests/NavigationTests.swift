import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// The demo tower extended upward: floors 9–12 over the same plate, reached only through a
/// second stairwell that starts on floor 8. Trips above floor 8 must transfer.
struct TransferFixture {
    var f: SimFixture
    let construction: ConstructionEngine
    var upperStairs: RoomID
    var offices: [RoomID] = []

    /// Footprint start: blueprint columns are footprint-relative.
    let x0: Int

    init() throws {
        f = try SimFixture()
        construction = ConstructionEngine(catalog: f.library.buildCatalog)
        let b = f.building
        x0 = f.world.buildings[b]!.footprint.start
        let apartment = try #require(f.world.rooms.values.first { $0.floors.lowest == 8 && $0.definitionID == "apartment-studio" })
        try construction.apply(.demolishRoom(apartment.id), to: &f.world)
        for level in 9...12 { try construction.apply(.buildFloor(building: b, level: level, span: ColumnSpan(start: x0 + 4, count: 24)), to: &f.world) }
        upperStairs = try Self.place(construction, "stairs", ColumnSpan(start: x0 + 21, count: 4), 8...12, in: b, world: &f.world)
        for level in 9...12 {
            offices.append(try Self.place(construction, "office-small", ColumnSpan(start: x0 + 4, count: 10), level...level, in: b, world: &f.world))
        }
        PopulationSync.sync(&f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules)
    }

    static func place(_ c: ConstructionEngine, _ definition: String, _ columns: ColumnSpan, _ floors: ClosedRange<Int>,
                      in b: BuildingID, world: inout GameWorld) throws -> RoomID {
        try c.apply(.placeRoom(building: b, definition: definition, columns: columns,
                               floors: FloorSpan(lowest: floors.lowerBound, highest: floors.upperBound)), to: &world)
        return world.room(in: b, column: columns.start, floor: floors.lowerBound)!.id
    }

    var building: Building { f.world.buildings[f.building]! }
    var lowerStairs: RoomID { f.world.rooms.values.first { $0.definitionID == "stairs" && $0.floors.lowest == -1 }!.id }

    func plan(to floor: Int, x: Double = 6) -> [Leg]? {
        let street = RoutePlanner.street(of: building, rules: f.library.simulationRules)!
        return RoutePlanner.plan(from: street, to: Spot(floor: floor, x: Double(x0) + x), building: building, world: f.world,
                                 navigation: f.engine.navigation, catalog: f.library.buildCatalog,
                                 rules: f.library.simulationRules, now: 100)
    }
}

private func stairs(_ legs: [Leg]) -> [(RoomID, Int, Int)] {
    legs.compactMap { if case let .stairs(s, a, b, _, _, _, _) = $0 { (s, a, b) } else { nil } }
}

@Suite struct NavigationGraphTests {
    @Test func graphHasPortalsPerServedFloorAndChainsFloors() throws {
        let t = try TransferFixture()
        let graph = t.f.engine.navigation.graph(for: t.building, world: t.f.world, catalog: t.f.library.buildCatalog,
                                                rules: t.f.library.simulationRules)
        // Lower stairs serve B1…8 (10 floors), upper stairs 8…12 (5 floors); elevators are not walkable yet.
        #expect(graph.portals.count == 15)
        // 9 + 4 storeys, both directions, plus one walk link on floor 8 in both directions.
        #expect(graph.edgeCount == 2 * 13 + 2)
    }

    @Test func routesTransferBetweenStairwells() throws {
        let t = try TransferFixture()
        let legs = try #require(t.plan(to: 11))
        let climbs = stairs(legs)
        #expect(climbs.count == 2)
        #expect(climbs[0] == (t.lowerStairs, 0, 8))
        #expect(climbs[1] == (t.upperStairs, 8, 11))
        // Legs are contiguous in time, the transfer walk happens on floor 8.
        #expect(zip(legs, legs.dropFirst()).allSatisfy { $0.end == $1.start })
        #expect(legs.contains { if case .walk(8, _, _, _, _) = $0 { true } else { false } })
        // Down again: the same shafts in reverse order.
        let back = try #require(RoutePlanner.plan(from: Spot(floor: 11, x: Double(t.x0) + 6), to: Spot(floor: -1, x: Double(t.x0) + 3), building: t.building,
                                                  world: t.f.world, navigation: t.f.engine.navigation,
                                                  catalog: t.f.library.buildCatalog, rules: t.f.library.simulationRules, now: 0))
        #expect(stairs(back).map(\.0) == [t.upperStairs, t.lowerStairs])
    }

    @Test func multiStoreyClimbsAreOneLegAndShortRoutesWin() throws {
        let t = try TransferFixture()
        let legs = try #require(t.plan(to: 5))
        #expect(stairs(legs).count == 1)
        #expect(stairs(legs)[0] == (t.lowerStairs, 0, 5))
        #expect(legs.count == 3)            // walk in, climb, walk to the spot
    }

    @Test func missingConnectionIsUnreachable() throws {
        var t = try TransferFixture()
        try t.construction.apply(.demolishRoom(t.upperStairs), to: &t.f.world)
        t.f.engine.navigation.refresh(world: t.f.world, catalog: t.f.library.buildCatalog)
        #expect(t.plan(to: 11) == nil)
        #expect(t.plan(to: 8) != nil)
        #expect(t.f.engine.navigation.metrics.failures == 1)
    }
}

@Suite struct RouteCacheTests {
    @Test func repeatedQueriesHitTheCache() throws {
        let t = try TransferFixture()
        let first = t.plan(to: 11)
        let second = t.plan(to: 11)
        #expect(first == second)
        let m = t.f.engine.navigation.metrics
        #expect(m.queries == 2 && m.cacheHits == 1 && m.graphBuilds == 1 && m.cachedRoutes == 1)
    }

    @Test func constructionInvalidatesGraphAndCache() throws {
        var t = try TransferFixture()
        _ = t.plan(to: 11)
        // A room that is not transport leaves the graph alone…
        try t.construction.apply(.demolishRoom(t.offices[0]), to: &t.f.world)
        #expect(t.f.engine.navigation.refresh(world: t.f.world, catalog: t.f.library.buildCatalog) == false)
        // …a new stairwell rebuilds it and forgets cached routes.
        _ = try TransferFixture.place(t.construction, "stairs", ColumnSpan(start: t.x0 + 14, count: 4), 9...10,
                                      in: t.f.building, world: &t.f.world)
        #expect(t.f.engine.navigation.refresh(world: t.f.world, catalog: t.f.library.buildCatalog))
        #expect(t.f.engine.navigation.metrics.cachedRoutes == 0)
        _ = t.plan(to: 11)
        #expect(t.f.engine.navigation.metrics.graphBuilds == 2)
    }

    /// Cached answers are exactly what a fresh search returns: a run with a warm cache equals
    /// a run whose cache is thrown away every step (as after loading a save).
    @Test func cacheNeverChangesOutcomes() throws {
        var warm = try TransferFixture(), cold = try TransferFixture()
        let total: Tick = 14 * 3600
        for _ in 0..<(total / 600) {
            warm.f.engine.advance(&warm.f.world, by: 600)
            SimulationEngine(rules: cold.f.library.simulationRules, catalog: cold.f.library.buildCatalog)
                .advance(&cold.f.world, by: 600)
        }
        #expect(warm.f.world == cold.f.world)
        #expect(warm.f.engine.navigation.metrics.cacheHits > 0)
    }
}

@Suite struct ReplanningTests {
    /// Advance until someone is on `leg` kind at the current tick.
    private func runUntil(_ t: inout TransferFixture, limit: Tick = 6 * 3600, _ match: (Person, Leg) -> Bool) -> PersonID? {
        for _ in 0..<(limit / 5) {
            t.f.engine.advance(&t.f.world, by: 5)
            let now = t.f.world.clock.tick
            for p in t.f.world.people {
                if case let .travelling(legs, _) = p.place, let leg = legs.first(where: { now < $0.end }), match(p, leg) { return p.id }
            }
        }
        return nil
    }

    @Test func tripsReplanAroundAReplacedStairwell() throws {
        var t = try TransferFixture()
        let upper = t.upperStairs, offices = t.offices
        // Someone climbing the lower stairs on the way to an upper office.
        let id = try #require(runUntil(&t) { p, leg in
            if case let .stairs(s, 0, 8, _, _, _, _) = leg, s != upper, let w = p.workRoom { return offices.contains(w) }
            return false
        })
        try t.construction.apply(.demolishRoom(upper), to: &t.f.world)
        let replacement = try TransferFixture.place(t.construction, "stairs", ColumnSpan(start: t.x0 + 24, count: 4), 8...12,
                                                    in: t.f.building, world: &t.f.world)
        let report = t.f.engine.replanAfterConstruction(&t.f.world)
        #expect(report.replanned >= 1)
        guard case let .travelling(legs, _) = t.f.world.people[id]!.place else { Issue.record("not travelling"); return }
        #expect(stairs(legs).map(\.0).contains(replacement))
        #expect(!stairs(legs).map(\.0).contains(upper))
        // They still arrive.
        t.f.engine.advance(&t.f.world, by: t.f.world.people[id]!.nextEventTick - t.f.world.clock.tick)
        #expect(t.f.inAnchorRoom(t.f.world.people[id]!))
        try t.f.world.validateIntegrity()
    }

    @Test func peopleOnARemovedStairwellWithNoAlternativeLeave() throws {
        var t = try TransferFixture()
        let upper = t.upperStairs
        let id = try #require(runUntil(&t) { _, leg in
            if case let .stairs(s, _, _, _, _, _, _) = leg { return s == upper }
            return false
        })
        try t.construction.apply(.demolishRoom(upper), to: &t.f.world)
        let report = t.f.engine.replanAfterConstruction(&t.f.world)
        #expect(report.stranded >= 1)
        let p = t.f.world.people[id]!
        #expect(p.place == .outside && p.unreachable)
        #expect(p.nextEventTick > t.f.world.clock.tick)
        // Valid trips elsewhere are untouched; advancing keeps working.
        t.f.engine.advance(&t.f.world, by: 3600)
        try t.f.world.validateIntegrity()
    }

    @Test func advanceReplansAutomatically() throws {
        var t = try TransferFixture()
        let upper = t.upperStairs
        let id = try #require(runUntil(&t) { _, leg in
            if case let .stairs(s, _, _, _, _, _, _) = leg { return s == upper }
            return false
        })
        try t.construction.apply(.demolishRoom(upper), to: &t.f.world)
        t.f.engine.advance(&t.f.world, by: 1)
        #expect(t.f.world.people[id]!.place == .outside)
    }
}

@Suite struct NavigationScaleTests {
    /// 200 floors, stair shafts in 20-storey segments alternating between two columns (every
    /// trip above floor 20 transfers), two offices per floor. Timings go to PERFORMANCE.md.
    @Test func tallTowerWithTransfersRunsADay() throws {
        var f = try SimFixture(tower: false)
        let c = ConstructionEngine(catalog: f.library.buildCatalog)
        let b = f.building
        let x0 = f.world.buildings[b]!.footprint.start
        let floors = 200
        for level in 0..<floors where f.world.buildings[b]!.plate(at: level) == nil {
            try c.apply(.buildFloor(building: b, level: level, span: ColumnSpan(start: x0, count: 32)), to: &f.world)
        }
        for segment in 0..<(floors / 20) {
            let lo = segment * 20, hi = min(lo + 20, floors - 1)
            try c.apply(.placeRoom(building: b, definition: "stairs", columns: ColumnSpan(start: x0 + (segment.isMultiple(of: 2) ? 12 : 28), count: 4),
                                   floors: FloorSpan(lowest: lo, highest: hi)), to: &f.world)
        }
        for level in 1..<floors {
            for start in [0, 16] {
                try c.apply(.placeRoom(building: b, definition: "office-small", columns: ColumnSpan(start: x0 + start, count: 12),
                                       floors: FloorSpan(lowest: level, highest: level)), to: &f.world)
            }
        }
        PopulationSync.sync(&f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules)
        let workers = f.count { $0.role == .worker }
        #expect(workers == 2 * 3 * (floors - 1))

        let clock = ContinuousClock()
        var engineTime = Duration.zero
        var steps = 0
        var checkedMorning = false
        let end: Tick = 24 * 3600
        while f.world.clock.tick < end {
            let n = min(240, end - f.world.clock.tick)     // 10× speed: 240 ticks per real second
            engineTime += clock.measure { f.engine.advance(&f.world, by: n) }
            steps += 1
            if !checkedMorning, SimClock.secondOfDay(f.world.clock.tick) >= 10 * 3600 + 1800 {
                checkedMorning = true
                #expect(f.count { $0.role == .worker && f.inAnchorRoom($0) } == workers)
            }
        }
        #expect(checkedMorning)
        #expect(f.count { $0.unreachable } == 0)
        let m = f.engine.navigation.metrics
        print("[scale] floors=\(floors) people=\(workers) portals=\(m.portals) edges=\(m.edges) queries=\(m.queries) " +
              "hits=\(m.cacheHits) builds=\(m.graphBuilds) day=\(engineTime) per-step=\(engineTime / steps)")
        #expect(m.graphBuilds == 1)
        #expect(m.hitRate > 0.3)
    }
}
