import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

struct SimFixture {
    var world: GameWorld
    let library: ContentLibrary
    let engine: SimulationEngine
    let building: BuildingID

    /// `elevator: false` demolishes the demo tower's elevator shaft (stairs-only tests).
    init(tower: Bool = true, elevator: Bool = true) throws {
        library = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: library)
        let b = game.world.buildings(on: game.activePropertyID).first!
        if tower {
            let construction = ConstructionEngine(catalog: library.buildCatalog)
            for c in library.blueprint("demo-tower")!.commands(for: b) { try construction.apply(c, to: &game.world) }
            if !elevator, let shaft = game.world.rooms.values.first(where: { $0.definitionID == "elevator-shaft" }) {
                try construction.apply(.demolishRoom(shaft.id), to: &game.world)
            }
        }
        world = game.world
        building = b.id
        engine = SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog)
        PopulationSync.sync(&world, catalog: library.buildCatalog, rules: library.simulationRules)
        Leasing.fillAll(&world, catalog: library.buildCatalog, rules: library.simulationRules)
        engine.replanAfterConstruction(&world)              // cars and upkeep, as the app does on install
    }

    /// Advance to a time of day ("HH:MM") on day 0 (or later day).
    mutating func run(until hhmm: String, day: Tick = 0) {
        let parts = hhmm.split(separator: ":").map { Tick($0)! }
        let target = day * 86_400 + parts[0] * 3600 + parts[1] * 60 - SimClock.startSecondOfDay
        engine.advance(&world, by: target - world.clock.tick)
    }

    func count(_ where: (Person) -> Bool) -> Int { world.people.values.filter(`where`).count }

    func inAnchorRoom(_ p: Person) -> Bool {
        if case let .room(r, _) = p.place { return r == p.anchorRoom }
        return false
    }
}

@Suite struct PopulationTests {
    @Test func roomsGetOccupantsFromContent() throws {
        let f = try SimFixture()
        // 8 offices (10 or 11 m, 0.3 per module → 3 each) + 7 studios × 2 residents.
        #expect(f.count { $0.role == .worker } == 24)
        #expect(f.count { $0.role == .resident } == 14)
        #expect(f.world.people.values.allSatisfy { !$0.name.isEmpty && $0.place == .outside })
        try f.world.validateIntegrity()
    }

    @Test func syncIsIdempotentAndFollowsDemolition() throws {
        var f = try SimFixture()
        #expect(PopulationSync.sync(&f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules) == (0, 0))
        let office = try #require(f.world.rooms.values.first { $0.definitionID == "office-small" })
        try ConstructionEngine(catalog: f.library.buildCatalog).apply(.demolishRoom(office.id), to: &f.world)
        let result = PopulationSync.sync(&f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules)
        #expect(result.removed == 3)
        #expect(f.count { $0.workRoom == office.id } == 0)
        try f.world.validateIntegrity()
    }
}

@Suite struct DailyRhythmTests {
    @Test func residentsMoveInAndWorkersArriveInTheMorning() throws {
        var f = try SimFixture()
        f.run(until: "06:15")
        #expect(f.count { $0.role == .resident && f.inAnchorRoom($0) } == 14)
        f.run(until: "07:00")
        #expect(f.count { $0.role == .worker && f.inAnchorRoom($0) } == 0)
        f.run(until: "09:30")
        #expect(f.count { $0.role == .worker && f.inAnchorRoom($0) } == 24)
        // Residents commute out in the morning.
        #expect(f.count { $0.role == .resident && $0.place == .outside } == 14)
    }

    @Test func lunchAndEveningFollowTheSchedule() throws {
        var f = try SimFixture()
        f.run(until: "12:45")
        #expect(f.count { $0.role == .worker && $0.place == .outside } >= 20)
        f.run(until: "14:00")
        #expect(f.count { $0.role == .worker && f.inAnchorRoom($0) } == 24)
        f.run(until: "22:30")
        #expect(f.count { $0.role == .worker && $0.place == .outside } == 24)
        #expect(f.count { $0.role == .resident && f.inAnchorRoom($0) } == 14)
        // Next morning they go again.
        f.run(until: "09:30", day: 1)
        #expect(f.count { $0.role == .worker && f.inAnchorRoom($0) } == 24)
    }

    @Test func peopleClimbStairsBetweenFloors() throws {
        var f = try SimFixture()
        var sawStairs = false
        for _ in 0..<(3 * 3600 / 30) {
            f.engine.advance(&f.world, by: 30)
            for p in f.world.people {
                if case let .travelling(legs, _) = p.place,
                   let s = PersonMotion.sample(legs, at: Double(f.world.clock.tick), grid: f.world.grid), s.onStairs {
                    sawStairs = true
                }
            }
        }
        #expect(sawStairs)
    }

    @Test func floorsWithoutStairsAreUnreachable() throws {
        var f = try SimFixture(elevator: false)
        let stairs = try #require(f.world.rooms.values.first { $0.definitionID == "stairs" })
        try ConstructionEngine(catalog: f.library.buildCatalog).apply(.demolishRoom(stairs.id), to: &f.world)
        f.run(until: "10:00")
        #expect(f.count { $0.role == .worker && f.inAnchorRoom($0) } == 0)
        #expect(f.count { $0.unreachable } > 0)
    }
}

@Suite struct DeterminismAcrossSpeedsTests {
    /// The same number of ticks gives the same world whether run in 1-tick steps (slow
    /// speed) or huge batches (fast speed): speed never changes outcomes.
    @Test func batchSizeDoesNotChangeTheResult() throws {
        var fine = try SimFixture(), coarse = try SimFixture()
        let total: Tick = 5 * 3600
        for _ in 0..<(total / 7) { fine.engine.advance(&fine.world, by: 7) }
        fine.engine.advance(&fine.world, by: total % 7)
        coarse.engine.advance(&coarse.world, by: total)
        #expect(fine.world == coarse.world)
        #expect(fine.world.clock.tick == total)
    }

    @Test func hostConvertsRealTimeToWholeTicks() {
        var host = SimulationHost(speed: .normal)
        var ticks: Tick = 0
        for _ in 0..<60 { ticks += host.ticksToRun(realDelta: 1.0 / 60) }
        #expect(ticks == 23 || ticks == 24)     // one real second ≈ 24 ticks at 1×
        host.speed = .fastest
        #expect(host.ticksToRun(realDelta: 0.1) == 24)
        host.speed = .paused
        #expect(host.ticksToRun(realDelta: 1) == 0)
    }

    @Test func schedulesAreValid() throws {
        let rules = try ContentLibrary.loadBase().simulationRules
        #expect(SimulationRules.validate(schedules: rules.schedules, names: rules.names).isEmpty)
    }
}
