import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

private func place(_ p: Person) -> String {
    switch p.place {
    case .outside: "outside"
    case .room: "room"
    case .travelling: "travelling"
    case .waiting: "waiting"
    case .riding: "riding"
    }
}

@Suite struct ElevatorRoutingTests {
    private func plan(_ f: SimFixture, to floor: Int) throws -> RoutePlanner.Trip {
        let building = f.world.buildings[f.building]!
        let street = try #require(RoutePlanner.street(of: building, rules: f.library.simulationRules))
        let x = Double(building.footprint.start) + 3
        return try #require(RoutePlanner.plan(from: street, to: Spot(floor: floor, x: x), building: building, world: f.world,
                                              navigation: f.engine.navigation, catalog: f.library.buildCatalog,
                                              rules: f.library.simulationRules, now: 0))
    }

    @Test func shortTripsTakeStairsLongTripsTheElevator() throws {
        let f = try SimFixture()
        let shaft = try #require(f.world.rooms.values.first { $0.definitionID == "elevator-shaft" })
        #expect(try plan(f, to: 1).ride == nil)
        #expect(try plan(f, to: 2).ride == nil)
        let high = try plan(f, to: 8)
        #expect(high.ride == Ride(shaft: shaft.id, fromFloor: 0, toFloor: 8, x: high.ride!.x))
        // The walking part ends at the landing where the ride starts.
        guard case let .walk(0, _, toX, _, _)? = high.legs.last else { Issue.record("expected a walk"); return }
        #expect(toX == high.ride!.x)
    }
}

@Suite struct ElevatorDispatchTests {
    @Test func carsAreCreatedForShaftsAndFollowDemolition() throws {
        var f = try SimFixture()
        #expect(f.world.elevators.count == 1)                 // created by the fixture's sync
        f.engine.advance(&f.world, by: 1)
        let shaft = try #require(f.world.rooms.values.first { $0.definitionID == "elevator-shaft" })
        #expect(f.world.elevators.values.map(\.id) == [shaft.id])
        #expect(f.world.elevators[shaft.id]!.floor == 0)
        try ConstructionEngine(catalog: f.library.buildCatalog).apply(.demolishRoom(shaft.id), to: &f.world)
        f.engine.advance(&f.world, by: 1)
        #expect(f.world.elevators.isEmpty)
    }

    /// Morning: people queue, ride and arrive; capacity is never exceeded; every rider is in
    /// the car; the world stays consistent; nobody is left waiting once the rush is over.
    @Test func morningRushIsServed() throws {
        var f = try SimFixture()
        let capacity = f.library.simulationRules.elevators[0].capacity
        var sawWaiting = false, sawRiding = false, maxLoad = 0
        var longestWait: Tick = 0
        for _ in 0..<(4 * 3600 / 10) {
            f.engine.advance(&f.world, by: 10)
            for car in f.world.elevators { maxLoad = max(maxLoad, car.passengers.count) }
            for p in f.world.people {
                switch p.place {
                case let .waiting(_, _, since):
                    sawWaiting = true
                    longestWait = max(longestWait, f.world.clock.tick - since)
                case .riding: sawRiding = true
                default: break
                }
            }
            if f.world.clock.tick % 1800 == 0 { try f.world.validateIntegrity() }
        }
        #expect(sawWaiting && sawRiding)
        #expect(maxLoad <= capacity)
        #expect(longestWait < 10 * 60)
        f.run(until: "10:30")
        #expect(f.count { place($0) == "waiting" || place($0) == "riding" } == 0)
        #expect(f.count { $0.role == .worker && f.inAnchorRoom($0) } == 24)
        #expect(f.count { $0.unreachable } == 0)
    }

    @Test func fullDayRhythmStillHoldsWithElevators() throws {
        var f = try SimFixture()
        f.run(until: "22:30")
        #expect(f.count { $0.role == .worker && $0.place == .outside } == 24)
        #expect(f.count { $0.role == .resident && f.inAnchorRoom($0) } == 14)
        #expect(f.world.elevators.values.allSatisfy { $0.passengers.isEmpty })
        try f.world.validateIntegrity()
    }

    @Test func removingTheShaftReroutesWaitingAndRidingPeople() throws {
        var f = try SimFixture()
        // First moment someone rides.
        var guardSteps = 0
        while !f.world.people.values.contains(where: { place($0) == "riding" }) && guardSteps < 20_000 {
            f.engine.advance(&f.world, by: 1)
            guardSteps += 1
        }
        let riders = f.world.people.values.filter { place($0) == "riding" }.map(\.id)
        #expect(!riders.isEmpty)
        let shaft = try #require(f.world.rooms.values.first { $0.definitionID == "elevator-shaft" })
        try ConstructionEngine(catalog: f.library.buildCatalog).apply(.demolishRoom(shaft.id), to: &f.world)
        let report = f.engine.replanAfterConstruction(&f.world)
        #expect(report.replanned >= riders.count)
        for id in riders {
            guard case let .travelling(legs, _) = f.world.people[id]!.place else { Issue.record("rider not re-planned"); continue }
            #expect(legs.contains { if case .stairs = $0 { true } else { false } })
        }
        #expect(f.count { place($0) == "waiting" || place($0) == "riding" } == 0)
        try f.world.validateIntegrity()
        f.run(until: "10:30")
        #expect(f.count { $0.role == .worker && f.inAnchorRoom($0) } == 24)
    }
}

@Suite struct ElevatorScaleTests {
    /// 60 floors, two elevator shafts and a stairwell over the full height, two offices per
    /// floor. Everyone must be at work by late morning. Timings go to PERFORMANCE.md.
    @Test func sixtyFloorTowerMorning() throws {
        var f = try SimFixture(tower: false)
        let c = ConstructionEngine(catalog: f.library.buildCatalog)
        let b = f.building
        let x0 = f.world.buildings[b]!.footprint.start
        let floors = 60
        for level in 0..<floors where f.world.buildings[b]!.plate(at: level) == nil {
            try c.apply(.buildFloor(building: b, level: level, span: ColumnSpan(start: x0, count: 32)), to: &f.world)
        }
        let top = FloorSpan(lowest: 0, highest: floors - 1)
        try c.apply(.placeRoom(building: b, definition: "stairs", columns: ColumnSpan(start: x0 + 10, count: 4), floors: top), to: &f.world)
        for start in [14, 17] {
            try c.apply(.placeRoom(building: b, definition: "elevator-shaft", columns: ColumnSpan(start: x0 + start, count: 3), floors: top),
                        to: &f.world)
        }
        for level in 1..<floors {
            for (start, width) in [(0, 10), (20, 12)] {
                try c.apply(.placeRoom(building: b, definition: "office-small", columns: ColumnSpan(start: x0 + start, count: width),
                                       floors: FloorSpan(lowest: level, highest: level)), to: &f.world)
            }
        }
        PopulationSync.sync(&f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules)
        Leasing.fillAll(&f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules)
        let workers = f.count { $0.role == .worker }
        let capacity = f.library.simulationRules.elevators[0].capacity
        let clock = ContinuousClock()
        var elapsed = Duration.zero
        var maxLoad = 0, peakWaiting = 0
        while SimClock.secondOfDay(f.world.clock.tick) < 11 * 3600 {
            elapsed += clock.measure { f.engine.advance(&f.world, by: 240) }
            maxLoad = max(maxLoad, f.world.elevators.values.map(\.passengers.count).max() ?? 0)
            peakWaiting = max(peakWaiting, f.count { if case .waiting = $0.place { true } else { false } })
        }
        let atWork = f.count { $0.role == .worker && f.inAnchorRoom($0) }
        print("[elevator-scale] floors=\(floors) workers=\(workers) atWork@11:00=\(atWork) peakWaiting=\(peakWaiting) " +
              "maxLoad=\(maxLoad) 5h=\(elapsed)")
        #expect(atWork == workers)
        #expect(maxLoad <= capacity)
        try f.world.validateIntegrity()
    }
}

@Suite struct HighRiseTests {
    /// The `demo-highrise` blueprint (used by the captures): one car for the whole tower,
    /// so the morning rush builds real queues, and everyone still gets to work.
    @Test func highRiseMorningQueuesAndArrivals() throws {
        let library = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: library)
        let b = game.world.buildings(on: game.activePropertyID).first!
        let construction = ConstructionEngine(catalog: library.buildCatalog)
        for c in try #require(library.blueprint("demo-highrise")).commands(for: b) { try construction.apply(c, to: &game.world) }
        var world = game.world
        PopulationSync.sync(&world, catalog: library.buildCatalog, rules: library.simulationRules)
        Leasing.fillAll(&world, catalog: library.buildCatalog, rules: library.simulationRules)
        let engine = SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog)
        let workers = world.people.values.filter { $0.role == .worker }.count
        var peak = 0, longest: Tick = 0
        while SimClock.secondOfDay(world.clock.tick) < 10 * 3600 + 1800 {
            engine.advance(&world, by: 15)
            var waiting = 0
            for p in world.people {
                if case let .waiting(_, _, since) = p.place { waiting += 1; longest = max(longest, world.clock.tick - since) }
            }
            peak = max(peak, waiting)
        }
        let atWork = world.people.values.filter { p in
            if case let .room(r, _) = p.place { return r == p.workRoom } else { return false }
        }.count
        print("[highrise] workers=\(workers) atWork@10:30=\(atWork) peakWaiting=\(peak) longestWait=\(longest)s")
        #expect(workers == 24 + 12 * 5)
        #expect(peak >= 3)                          // arrivals spread over ±40 min; measured 4
        #expect(atWork == workers)
        try world.validateIntegrity()
    }
}
