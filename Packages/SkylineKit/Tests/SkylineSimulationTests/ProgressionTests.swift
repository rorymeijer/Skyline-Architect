import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// A standard game (unlocks by class) with the demo tower built and, optionally, leased.
/// The blueprint is applied as in a sandbox — it is test setup, not play.
struct StandardFixture {
    var world: GameWorld
    let library: ContentLibrary
    let engine: SimulationEngine
    let construction: ConstructionEngine
    let building: BuildingID

    init(leased: Bool) throws {
        library = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.standardStartID, library: library)
        let b = game.world.buildings(on: game.activePropertyID).first!
        construction = ConstructionEngine(catalog: library.buildCatalog)
        game.world.unlocks = .all
        for c in try #require(library.blueprint("demo-tower")).commands(for: b) { try construction.apply(c, to: &game.world) }
        game.world.unlocks = .byClass
        world = game.world
        building = b.id
        engine = SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog)
        PopulationSync.sync(&world, catalog: library.buildCatalog, rules: library.simulationRules)
        if leased { Leasing.fillAll(&world, catalog: library.buildCatalog, rules: library.simulationRules) }
        engine.replanAfterConstruction(&world)
    }

    var standing: Standing { world.buildings[building]!.standing }

    mutating func setStanding(classLevel: Int? = nil, reputation: Double? = nil) {
        var s = standing
        if let classLevel { s.classLevel = classLevel }
        if let reputation { s.reputation = reputation }
        world.setStanding(s, building: building)
    }

    /// Runs whole days from the current tick (each passes one 06:00 closing).
    mutating func runDays(_ days: Int) { engine.advance(&world, by: Tick(days) * SimClock.secondsPerDay) }
}

@Suite struct UnlockTests {
    @Test func startsChooseTheUnlockMode() throws {
        let library = try ContentLibrary.loadBase()
        let sandbox = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: library)
        let standard = try NewGameFactory.make(startID: NewGameFactory.standardStartID, library: library)
        #expect(sandbox.world.unlocks == .all && standard.world.unlocks == .byClass)
        #expect(standard.world.buildings.values.allSatisfy { $0.standing == Standing() })
        #expect(library.buildCatalog.classes.map(\.name) == ["Class C", "Class B", "Class A", "Prime"])
    }

    @Test func lockedRoomsAndHeightAreRefusedUntilTheClassAllowsThem() throws {
        var f = try StandardFixture(leased: false)
        let b = f.building, footprint = f.world.buildings[b]!.footprint
        let top = f.world.buildings[b]!.builtLevels!.highest, span = f.world.buildings[b]!.plate(at: top)!.span
        let service = BuildCommand.placeRoom(building: b, definition: "service-elevator",
                                             columns: ColumnSpan(start: footprint.start + 28, count: 2), floors: FloorSpan(lowest: 1, highest: 3))
        #expect(throws: ConstructionError.locked(className: "Class B")) { try f.construction.apply(service, to: &f.world) }
        // Build up to the class C limit (floor 12); floor 13 needs class B.
        for level in (top + 1)...12 { try f.construction.apply(.buildFloor(building: b, level: level, span: span), to: &f.world) }
        #expect(throws: ConstructionError.locked(className: "Class B")) {
            try f.construction.apply(.buildFloor(building: b, level: 13, span: span), to: &f.world)
        }
        f.setStanding(classLevel: 1)
        try f.construction.apply(.buildFloor(building: b, level: 13, span: span), to: &f.world)
        #expect(throws: ConstructionError.locked(className: "Class A")) {
            try f.construction.apply(.placeRoom(building: b, definition: "sky-lobby", columns: ColumnSpan(start: span.start + 4, count: 8),
                                                floors: FloorSpan(lowest: 13, highest: 13)), to: &f.world)
        }
    }

    @Test func sandboxAllowsEverything() throws {
        var f = try StandardFixture(leased: false)
        f.world.unlocks = .all
        let top = f.world.buildings[f.building]!.builtLevels!.highest, span = f.world.buildings[f.building]!.plate(at: top)!.span
        for level in (top + 1)...14 { try f.construction.apply(.buildFloor(building: f.building, level: level, span: span), to: &f.world) }
        #expect(f.world.buildings[f.building]!.builtLevels!.highest == 14)
    }

    /// In a class C building only class-0 tenant types come by and sign.
    @Test func premiumTenantsWaitForTheClass() throws {
        var f = try StandardFixture(leased: false)
        f.runDays(4)
        let gated = Set(f.library.simulationRules.tenantTypes.filter { ($0.minClass ?? 0) > 0 }.map(\.id))
        #expect(!f.world.tenants.isEmpty)
        #expect(f.world.tenants.values.allSatisfy { !gated.contains($0.typeID) })
        #expect(f.world.market.log.allSatisfy { !gated.contains($0.typeID) })
    }
}

@Suite struct ReputationTests {
    @Test func reputationMovesTowardTheAssessment() throws {
        var f = try StandardFixture(leased: true)
        f.setStanding(reputation: 20)
        let now = f.world.clock.tick
        let a = try #require(Progression.assess(f.building, world: f.world, engine: f.engine))
        f.engine.standingDaily(at: now, moveOuts: [:], world: &f.world)
        let rules = try #require(f.engine.rules.progression)
        #expect(abs(f.standing.reputation - (20 + (a.target - 20) * rules.dailyAdjustment)) < 1e-9)
        #expect(a.target > 50)                  // a full, well-run tower
        #expect(a.occupancy == 1 && a.population == Progression.population(of: f.building, in: f.world))
    }

    @Test func moveOutsCostReputation() throws {
        let f = try StandardFixture(leased: true)
        let calm = try #require(Progression.assess(f.building, world: f.world, engine: f.engine))
        let bad = try #require(Progression.assess(f.building, world: f.world, engine: f.engine, moveOuts: 2))
        #expect(abs(calm.target - bad.target - 2 * f.engine.rules.progression!.moveOutPenalty) < 1e-9)
    }

    @Test func emptyBuildingsScoreBelowLeasedOnes() throws {
        let empty = try StandardFixture(leased: false), full = try StandardFixture(leased: true)
        let a = try #require(Progression.assess(empty.building, world: empty.world, engine: empty.engine))
        let b = try #require(Progression.assess(full.building, world: full.world, engine: full.engine))
        #expect(a.occupancy == 0 && a.population == 0 && a.satisfaction == 0.5)
        #expect(a.target < b.target)
    }

    @Test func reputationDrivesDemand() throws {
        var f = try StandardFixture(leased: false)
        f.setStanding(reputation: 0)
        #expect(Progression.demandMultiplier(world: f.world, engine: f.engine) == 0.5)
        f.setStanding(reputation: 100)
        #expect(Progression.demandMultiplier(world: f.world, engine: f.engine) == 1.5)
    }
}

@Suite struct PromotionTests {
    @Test func promotionNeedsEveryRequirement() throws {
        var f = try StandardFixture(leased: true)
        let pop = Progression.population(of: f.building, in: f.world)
        let classB = f.library.buildCatalog.classes[1]
        #expect(pop >= classB.population)                       // the leased demo tower is big enough
        f.setStanding(reputation: 40)                           // … but not reputable enough
        var reqs = Progression.requirements(for: 1, building: f.building, world: f.world, catalog: f.library.buildCatalog)
        #expect(reqs.map(\.label) == ["Population", "Reputation", "Elevator Shaft"])
        #expect(reqs.map(\.met) == [true, false, true])
        f.engine.standingDaily(at: f.world.clock.tick, moveOuts: [:], world: &f.world)
        #expect(f.standing.classLevel == 0)
        f.setStanding(reputation: 90)
        f.engine.standingDaily(at: 1234, moveOuts: [:], world: &f.world)
        #expect(f.standing.classLevel == 1 && f.standing.promotions == [1234])
        // Class A needs a service elevator and more people: not reached; one class per day anyway.
        reqs = Progression.requirements(for: 2, building: f.building, world: f.world, catalog: f.library.buildCatalog)
        #expect(!reqs.allSatisfy { $0.met })
        f.engine.standingDaily(at: 5678, moveOuts: [:], world: &f.world)
        #expect(f.standing.classLevel == 1)
    }

    @Test func classesNeverDrop() throws {
        var f = try StandardFixture(leased: true)
        f.setStanding(classLevel: 1, reputation: 5)
        for c in f.world.tenants.values { Leasing.moveOut(c.id, world: &f.world) }
        f.engine.standingDaily(at: f.world.clock.tick, moveOuts: [f.building: 15], world: &f.world)
        #expect(f.standing.classLevel == 1)
        #expect(f.standing.reputation < 5)
    }

    /// A power cut (electrical room demolished) empties units and costs reputation; the
    /// class stays.
    @Test func aPowerCutCostsReputationNotTheClass() throws {
        var f = try StandardFixture(leased: false)
        f.runDays(4)
        #expect(f.standing.classLevel == 1)
        let before = f.standing.reputation
        let plant = try #require(f.world.rooms.values.first { $0.definitionID == "electrical-room" })
        try f.construction.apply(.demolishRoom(plant.id), to: &f.world)
        f.engine.replanAfterConstruction(&f.world)
        f.runDays(5)
        print("[progression] power cut: reputation \(Int(before)) → \(Int(f.standing.reputation)), moved out \(f.world.market.movedOut)")
        #expect(f.world.market.movedOut > 0)
        #expect(f.standing.reputation < before - 10)
        #expect(f.standing.classLevel == 1)
    }

    /// Played, not set up: an empty class C demo tower fills through the market and earns
    /// class B on its own within two weeks.
    @Test func anEmptyTowerEarnsClassBByPlaying() throws {
        var f = try StandardFixture(leased: false)
        var day = 0
        while f.standing.classLevel == 0 && day < 14 {
            f.runDays(1)
            day += 1
        }
        print("[progression] class \(f.standing.classLevel) after \(day) days, reputation \(String(format: "%.1f", f.standing.reputation)), " +
              "population \(Progression.population(of: f.building, in: f.world)), tenants \(f.world.tenants.count)")
        #expect(f.standing.classLevel == 1)
        try f.world.validateIntegrity()
    }

    @Test func summaryShowsTheWayToTheNextClass() throws {
        var f = try StandardFixture(leased: true)
        f.setStanding(reputation: 40)
        let s = ProgressionSummary.make(world: f.world, engine: f.engine, building: f.building)
        #expect(s.byClass && s.className == "Class C" && s.nextClassName == "Class B" && s.maxFloor == 12)
        #expect(s.requirements.map(\.met) == [true, false, true])
        #expect(s.nextUnlocks == ["Service Elevator", "Design studio tenants", "Single professional tenants", "Floors up to 25"])
        #expect(s.lockedRooms["service-elevator"] == "Class B" && s.lockedRooms["sky-lobby"] == "Class A")
        #expect(s.assessment != nil)
        f.world.unlocks = .all
        let sandbox = ProgressionSummary.make(world: f.world, engine: f.engine, building: f.building)
        #expect(!sandbox.byClass && sandbox.lockedRooms.isEmpty && sandbox.maxFloor == nil)
    }
}

