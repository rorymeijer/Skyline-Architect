import Foundation
import Testing
import SkylineCore
@testable import SkylineContent
@testable import SkylineSimulation

@Suite struct ScenarioTests {
    let library = try! ContentLibrary.loadBase()
    var sim: SimulationEngine { SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog) }

    func builtScenario(_ id: String, blueprint: String = "demo-tower") throws -> NewGame {
        var game = try NewGameFactory.make(scenarioID: id, library: library)
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        let engine = ConstructionEngine(catalog: library.buildCatalog)
        for c in try #require(library.blueprint(blueprint)).commands(for: building) { try engine.apply(c, to: &game.world) }
        PopulationSync.sync(&game.world, catalog: library.buildCatalog, rules: library.simulationRules)
        sim.replanAfterConstruction(&game.world)
        return game
    }

    @Test func everyScenarioStarts() throws {
        #expect(library.orderedScenarios.map(\.id) == ["opening-day", "harbour-revival", "three-properties", "crown-prestige", "skyline", "lean-tower"])
        for def in library.orderedScenarios {
            let game = try NewGameFactory.make(scenarioID: def.id, library: library)
            let s = try #require(game.world.scenario)
            #expect(game.scenarioID == def.id && s.objectives == def.objectives && s.deadlineDay == Tick(def.days))
            #expect(s.measured.count == def.objectives.count && s.result == nil && s.streak == 0)
            #expect(game.world.unlocks == .byClass)
            try game.world.validateIntegrity()
        }
        let harbour = try NewGameFactory.make(scenarioID: "harbour-revival", library: library)
        #expect(harbour.world.ledger.cash == 1_500_000)
        #expect(harbour.world.cities.values.map(\.definitionID) == ["saltmere"])
        #expect(harbour.world.properties.values.first?.plotID == "saltmere-harbour-row")
        #expect(throws: ContentError.self) { try NewGameFactory.make(scenarioID: "nope", library: library) }
    }

    /// The easy scenario can be won by building the demo tower: twelve units let and a
    /// profitable closing within its ten days.
    @Test func openingDayIsWinnableWithTheDemoTower() throws {
        var game = try builtScenario("opening-day")
        var days = 0
        while game.world.scenario?.result == nil, days < 10 {
            sim.advance(&game.world, by: SimClock.secondsPerDay)
            days += 1
        }
        let s = try #require(game.world.scenario)
        print("[scenario] opening day after \(days) days: measured \(s.measured), result \(String(describing: s.result))")
        let result = try #require(s.result)
        #expect(result.won && result.reason == "Every objective met")
        #expect(SimClock.day(result.tick) == Tick(days))
        #expect(s.measured[0]! >= 12 && s.measured[1]! >= 5000)
        // Decided once: later closings leave the result alone.
        sim.advance(&game.world, by: 2 * SimClock.secondsPerDay)
        #expect(game.world.scenario?.result == result)
    }

    /// Every scenario city lets the demo tower on its own market (no developer leasing).
    @Test func scenarioTowersFindTenants() throws {
        for id in ["harbour-revival", "crown-prestige"] {
            var game = try builtScenario(id)
            sim.advance(&game.world, by: 5 * SimClock.secondsPerDay)
            let declines = DeclineReason.allCases.map { "\($0): \(game.world.market.declines($0))" }
            print("[scenario] \(id): \(game.world.tenants.count) tenants after 5 days, declines \(declines), measured \(game.world.scenario!.measured)")
            #expect(game.world.tenants.count >= 8)
        }
    }

    @Test func timeRunsOutAtTheDeadlineClosing() throws {
        var game = try NewGameFactory.make(scenarioID: "harbour-revival", library: library)
        sim.advance(&game.world, by: 29 * SimClock.secondsPerDay + 3600)
        #expect(game.world.scenario?.result == nil)
        #expect(game.world.scenario?.measured == [0, 0])
        sim.advance(&game.world, by: SimClock.secondsPerDay)
        let result = try #require(game.world.scenario?.result)
        #expect(!result.won && result.reason == "Time ran out" && SimClock.day(result.tick) == 30)
    }

    @Test func bankruptcyLosesTheScenario() throws {
        var game = try NewGameFactory.make(scenarioID: "opening-day", library: library)
        game.world.ledger.post(Transaction(tick: 0, amount: -3_000_000, category: .grant, detail: "Test debt"))
        sim.advance(&game.world, by: 8 * SimClock.secondsPerDay)
        let result = try #require(game.world.scenario?.result)
        #expect(game.world.ledger.bankrupt && !result.won && result.reason == "Bankrupt")
    }

    /// Objectives must hold for `holdDays` closings in a row; a miss resets the streak.
    @Test func objectivesMustHoldInARow() throws {
        var game = try NewGameFactory.make(startID: NewGameFactory.standardStartID, library: library)
        game.world.scenario = ScenarioState(id: "test", name: "Test", objectives: [ScenarioObjective(metric: .properties, target: 2)],
                                            deadlineDay: 10, holdDays: 2)
        let engine = sim
        engine.scenarioDaily(at: 86_400, world: &game.world)
        #expect(game.world.scenario?.streak == 0 && game.world.scenario?.measured == [1])
        game.world.ledger.post(Transaction(tick: 0, amount: 1_000_000, category: .grant, detail: "Test"))
        let bought = try Estate.buy("saltmere-harbour-row", world: &game.world, library: library)
        engine.scenarioDaily(at: 2 * 86_400, world: &game.world)
        #expect(game.world.scenario?.streak == 1 && game.world.scenario?.result == nil)
        // Dropping below the target breaks the streak (simulated by a second objective).
        game.world.scenario?.objectives.append(ScenarioObjective(metric: .cash, target: 1e12))
        engine.scenarioDaily(at: 3 * 86_400, world: &game.world)
        #expect(game.world.scenario?.streak == 0)
        game.world.scenario?.objectives.removeLast()
        engine.scenarioDaily(at: 4 * 86_400, world: &game.world)
        engine.scenarioDaily(at: 5 * 86_400, world: &game.world)
        #expect(game.world.scenario?.result?.won == true && SimClock.day(game.world.scenario!.result!.tick) == 5)
        #expect(game.world.properties.contains(bought))
    }

    @Test func metrics() throws {
        var game = try builtScenario("opening-day")
        // Construction is not operating profit: the first day has none yet.
        #expect(Scenarios.measure(.dailyProfit, world: game.world, engine: sim) == 0)
        #expect(Scenarios.measure(.averageWait, world: game.world, engine: sim) == nil)
        #expect(Scenarios.measure(.properties, world: game.world, engine: sim) == 1)
        #expect(Scenarios.measure(.buildingClass, world: game.world, engine: sim) == 0)
        #expect(Scenarios.measure(.cash, world: game.world, engine: sim) == Double(game.world.ledger.cash))
        sim.advance(&game.world, by: 2 * SimClock.secondsPerDay)
        let population = try #require(Scenarios.measure(.population, world: game.world, engine: sim))
        #expect(population == Double(game.world.people.values.filter { $0.tenantID != nil }.count) && population > 0)
        #expect(Scenarios.measure(.occupiedUnits, world: game.world, engine: sim) == Double(game.world.tenants.count))
        let wait = try #require(Scenarios.measure(.averageWait, world: game.world, engine: sim))
        #expect(wait > 0 && wait < 300)
        let today = try #require(game.world.ledger.days.last)
        #expect(Scenarios.measure(.dailyProfit, world: game.world, engine: sim)
                == Double([LedgerCategory.rent, .turnover, .maintenance, .utilities, .wages, .interest, .taxes, .waste].reduce(0) { $0 + today.amount($1) }))
        #expect(ScenarioObjective(metric: .averageWait, target: 45).isMet(by: 44) && !ScenarioObjective(metric: .averageWait, target: 45).isMet(by: 46))
        #expect(!ScenarioObjective(metric: .population, target: 1).isMet(by: nil))
    }

    /// A scenario run is deterministic and batch-independent like the rest of the simulation.
    @Test func scenarioRunIsBatchIndependent() throws {
        var a = try builtScenario("opening-day")
        var b = a
        sim.advance(&a.world, by: 3 * SimClock.secondsPerDay)
        for _ in 0..<(3 * 24) { sim.advance(&b.world, by: 3600) }
        #expect(a.world.scenario == b.world.scenario)
    }

    @Test func invalidScenariosAreRejected() throws {
        let good = try #require(library.scenario("opening-day"))
        var cases: [ScenarioDefinition] = []
        var s = good; s.startID = "nowhere"; cases.append(s)
        s = good; s.days = 0; cases.append(s)
        s = good; s.holdDays = 11; cases.append(s)
        s = good; s.objectives = []; cases.append(s)
        s = good; s.objectives = [ScenarioObjective(metric: .buildingClass, target: 9)]; cases.append(s)
        s = good; s.objectives = [ScenarioObjective(metric: .reputation, target: 120)]; cases.append(s)
        s = good; s.objectives = [ScenarioObjective(metric: .averageWait, target: 0)]; cases.append(s)
        for bad in cases {
            var lib = library
            lib.orderedScenarios = []
            #expect(throws: ContentError.self) { try lib.register(scenarios: [bad]) }
        }
        var lib = library
        lib.orderedScenarios = []
        #expect(throws: ContentError.self) { try lib.register(scenarios: [good, good]) }
    }
}

@Suite struct ScenarioSummaryTests {
    let library = try! ContentLibrary.loadBase()

    @Test func briefsDescribeEveryScenario() throws {
        let briefs = ScenarioBrief.all(library: library)
        #expect(briefs.count == library.orderedScenarios.count)
        let harbour = try #require(briefs.first { $0.id == "harbour-revival" })
        #expect(harbour.setting == "Harbour Row, Saltmere · $1,500,000 · 30 days")
        #expect(harbour.objectives == ["Population ≥ 120", "Daily profit ≥ $4,000"] && harbour.holdDays == 3 && harbour.difficulty == "Medium")
        let crown = try #require(briefs.first { $0.id == "crown-prestige" })
        #expect(crown.objectives == ["Building class ≥ Class A", "Reputation ≥ 70", "Average elevator wait ≤ 45 s"])
        #expect(briefs.first { $0.id == "skyline" }?.objectives.first == "Population ≥ 1,500")
    }

    @Test func liveSummaryFollowsTheWorld() throws {
        let sim = SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog)
        var game = try NewGameFactory.make(scenarioID: "opening-day", library: library)
        #expect(ScenarioSummary.make(world: try NewGameFactory.make(startID: NewGameFactory.standardStartID, library: library).world,
                                     engine: sim, library: library) == nil)
        var s = try #require(ScenarioSummary.make(world: game.world, engine: sim, library: library))
        #expect(s.name == "Opening Day" && s.daysLeft == 10 && s.result == nil)
        #expect(s.rows.map(\.label) == ["Units let ≥ 12", "Daily profit ≥ $5,000"])
        #expect(s.rows.map(\.current) == ["0", "$0"] && s.rows.allSatisfy { !$0.met && $0.fraction == 0 })
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        for c in try #require(library.blueprint("demo-tower")).commands(for: building) {
            try ConstructionEngine(catalog: library.buildCatalog).apply(c, to: &game.world)
        }
        PopulationSync.sync(&game.world, catalog: library.buildCatalog, rules: library.simulationRules)
        sim.replanAfterConstruction(&game.world)
        sim.advance(&game.world, by: SimClock.secondsPerDay + 3600)
        s = try #require(ScenarioSummary.make(world: game.world, engine: sim, library: library))
        #expect(s.daysLeft == 9 && s.rows[0].fraction > 0)
        sim.advance(&game.world, by: 3 * SimClock.secondsPerDay)
        s = try #require(ScenarioSummary.make(world: game.world, engine: sim, library: library))
        #expect(s.result?.won == true && s.daysLeft == 0 && s.rows.allSatisfy(\.met))
    }
}
