import Foundation
import Testing
import SkylineCore
@testable import SkylineContent
@testable import SkylineSimulation

/// F3: the tutorial scenario's steps, played like a player through the construction engine.
@Suite struct TutorialTests {
    let library = try! ContentLibrary.loadBase()

    @Test func tutorialStepsCompleteInOrderAndTheScenarioIsWon() throws {
        var game = try NewGameFactory.make(scenarioID: "first-tower", library: library)
        let steps = library.tutorialSteps(for: game.world)
        #expect(steps.map(\.id) == ["floors", "lobby", "stairs", "plant", "offices", "elevator", "flats", "tenants", "staff", "closing"])
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        let construction = ConstructionEngine(catalog: library.buildCatalog)
        let s = building.footprint.start, span = building.footprint
        func room(_ def: String, _ start: Int, _ width: Int, _ lo: Int, _ hi: Int? = nil) -> BuildCommand {
            .placeRoom(building: building.id, definition: def, columns: ColumnSpan(start: s + start, count: width),
                       floors: FloorSpan(lowest: lo, highest: hi ?? lo))
        }
        func current() -> String? { TutorialProgress(steps: steps, world: game.world).current.map { steps[$0].id } }
        func apply(_ commands: [BuildCommand]) throws { for c in commands { try construction.apply(c, to: &game.world) } }

        #expect(current() == "floors")
        try apply([.buildFloor(building: building.id, level: -1, span: span), .buildFloor(building: building.id, level: 0, span: span)])
        #expect(current() == "lobby")
        try apply([room("lobby", 7, 25, 0)])
        #expect(current() == "stairs")
        try apply([room("stairs", 0, 4, -1, 0)])
        #expect(current() == "plant")
        try apply([room("mechanical", 7, 4, -1), room("electrical-room", 11, 4, -1), room("telecom-room", 15, 3, -1)])
        #expect(current() == "offices")
        try apply([.buildFloor(building: building.id, level: 1, span: span), room("office-small", 7, 8, 1), room("office-small", 15, 8, 1)])
        #expect(current() == "elevator")
        let stairs = try #require(game.world.rooms.values.first { $0.definitionID == "stairs" }).id
        try apply([.buildFloor(building: building.id, level: 2, span: span), .resizeRoom(stairs, floors: FloorSpan(lowest: -1, highest: 2)),
                   room("elevator-shaft", 4, 3, -1, 2)])
        #expect(current() == "flats")
        try apply([room("apartment-studio", 7, 8, 2), room("apartment-studio", 15, 8, 2)])
        #expect(current() == "tenants")

        let sim = SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog)
        PopulationSync.sync(&game.world, catalog: library.buildCatalog, rules: library.simulationRules)
        sim.replanAfterConstruction(&game.world)
        var hours = 0
        while game.world.tenants.count < 2 && hours < 48 {
            sim.advance(&game.world, by: 3600)
            hours += 1
        }
        #expect(current() == "staff")
        try apply([room("staff-room", 18, 6, -1)])
        FacilitiesManagement.hire(.janitor, building: building.id, world: &game.world, rules: library.simulationRules, catalog: library.buildCatalog)
        let day = SimClock.day(game.world.clock.tick)
        if day == game.world.scenario?.startDay {
            #expect(current() == "closing")
        }
        var days = 0
        while game.world.scenario?.result == nil && days < 10 {
            sim.advance(&game.world, by: SimClock.secondsPerDay)
            days += 1
        }
        #expect(TutorialProgress(steps: steps, world: game.world).isFinished)
        #expect(game.world.scenario?.result?.won == true)
        print("[tutorial] market: prospects \(game.world.market.prospects), signed \(game.world.market.signed); " + DeclineReason.allCases.map { "\($0.rawValue) \(game.world.market.declines($0))" }.joined(separator: ", "))
        print("[tutorial] tenants after \(hours) h; won after \(days) more days; \(game.world.tenants.count) tenants")
    }

    @Test func conditionsMeasureTheWorld() throws {
        let game = try NewGameFactory.make(scenarioID: "first-tower", library: library)
        #expect(TutorialCondition(kind: .scenarioDay, count: 1).progress(in: game.world) == (1, true))
        #expect(TutorialCondition(kind: .rooms, count: 1, rooms: ["lobby"]).progress(in: game.world).met == false)
        #expect(TutorialCondition(kind: .staff, count: 1).progress(in: game.world).value == 0)
        // No tutorial outside a tutorial scenario.
        let free = try NewGameFactory.make(scenarioID: "opening-day", library: library)
        #expect(library.tutorialSteps(for: free.world).isEmpty)
    }

    @Test func invalidStepsAreRejected() {
        let bad = [TutorialStep(id: "a", title: "A", text: "x", done: [TutorialCondition(kind: .rooms, count: 1, rooms: ["nope"])]),
                   TutorialStep(id: "a", title: "", text: "", done: [])]
        let problems = library.tutorialProblems(bad)
        #expect(problems.contains { $0.contains("unknown room 'nope'") })
        #expect(problems.contains { $0.contains("duplicate id") })
        #expect(problems.contains { $0.contains("needs a title") })
        #expect(problems.contains { $0.contains("at least one condition") })
    }
}
