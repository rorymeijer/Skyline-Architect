import Foundation
import Testing
import SkylineCore
@testable import SkylineContent
@testable import SkylineSimulation

/// Phase C: scenario restrictions, scripted events and scoring.
@Suite struct ScenarioScriptTests {
    let library = try! ContentLibrary.loadBase()
    var sim: SimulationEngine { SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog) }

    func built(_ id: String) throws -> NewGame {
        var game = try NewGameFactory.make(scenarioID: id, library: library)
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        let engine = ConstructionEngine(catalog: library.buildCatalog)
        for c in try #require(library.blueprint("demo-tower")).commands(for: building) {
            if case let .placeRoom(_, def, _, _) = c, game.world.restrictions?.forbids(def) == true { continue }
            try engine.apply(c, to: &game.world)
        }
        PopulationSync.sync(&game.world, catalog: library.buildCatalog, rules: library.simulationRules)
        sim.replanAfterConstruction(&game.world)
        return game
    }

    @Test func restrictionsAreEnforced() throws {
        var game = try built("lean-tower")
        let r = try #require(game.world.restrictions)
        #expect(r.forbids("apartment-studio") && r.maxFloor == 12 && r.rentIsFixed && r.staffForbidden)
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        let engine = ConstructionEngine(catalog: library.buildCatalog)
        #expect(!game.world.rooms.values.contains { $0.definitionID == "apartment-studio" })
        let floor8 = try #require(building.plate(at: 8))
        #expect(engine.validate(.placeRoom(building: building.id, definition: "apartment-studio",
                                           columns: ColumnSpan(start: floor8.span.start, count: 6), floors: FloorSpan(lowest: 8, highest: 8)),
                                in: game.world) == .failure(.forbiddenInScenario))
        for level in 9...12 {
            let span = game.world.buildings[building.id]!.plate(at: level - 1)!.span
            try engine.apply(.buildFloor(building: building.id, level: level, span: span), to: &game.world)
        }
        let top = game.world.buildings[building.id]!.plate(at: 12)!.span
        #expect(engine.validate(.buildFloor(building: building.id, level: 13, span: top), in: game.world) == .failure(.aboveScenarioHeight(max: 12)))
        #expect(!Economy.setRentLevel(1.2, building: building.id, in: &game.world))
        let office = try #require(game.world.rooms.values.first { $0.definitionID == "office-small" })
        #expect(!Economy.setRentFactor(1.2, room: office.id, in: &game.world, catalog: library.buildCatalog))
        #expect(FacilitiesManagement.hire(.janitor, building: building.id, world: &game.world, rules: library.simulationRules) == nil)
        // Three Properties caps loans at 2M.
        var three = try NewGameFactory.make(scenarioID: "three-properties", library: library)
        let economy = try #require(library.simulationRules.economy)
        var loans = 0
        while Economy.borrow(&three.world, rules: economy) { loans += 1 }
        #expect(three.world.ledger.loans == 2_000_000 && loans == 4)
    }

    /// Opening Day's events: the briefing news at 08:00 on day 1, the occupancy subsidy on
    /// day 4 (paid when six units are let), the trade fair's demand shock on day 6.
    @Test func eventsFireOnTheirDayAndHour() throws {
        var game = try built("opening-day")
        game.world.scenario?.objectives[0].target = 1000              // not won early: events keep firing
        let engine = sim
        engine.advance(&game.world, by: 2 * 3600 + 60)                     // day 1, 08:01
        #expect(game.world.scenario?.news?.count == 1 && game.world.scenario?.fired == [0])
        Leasing.fillAll(&game.world, catalog: library.buildCatalog, rules: library.simulationRules)
        let cash = game.world.ledger.cash
        engine.advance(&game.world, by: 3 * SimClock.secondsPerDay)          // day 4, 08:01 — not yet
        #expect(game.world.scenario?.fired == [0])
        engine.advance(&game.world, by: 2 * 3600)                           // day 4, 10:01
        #expect(game.world.scenario?.fired == [0, 1])
        #expect(game.world.ledger.journal.contains { $0.category == .grant && $0.amount == 250_000 && $0.detail.hasPrefix("Subsidy") })
        #expect(game.world.ledger.cash > cash)
        engine.advance(&game.world, by: 2 * SimClock.secondsPerDay)         // day 6, 10:01
        let shock = try #require(game.world.scenario?.shocks?.first)
        #expect(shock.tenantType == "call-centre" && shock.multiplier == 2.5)
        #expect(engine.scenarioDemand(for: "call-centre", at: game.world.clock.tick, world: game.world) == 2.5)
        #expect(engine.scenarioDemand(for: "couple", at: game.world.clock.tick, world: game.world) == 1)
        engine.advance(&game.world, by: 2 * SimClock.secondsPerDay)
        #expect(engine.scenarioDemand(for: "call-centre", at: game.world.clock.tick, world: game.world) == 1)
    }

    /// A grant needs its condition; a fine is charged only when the condition is not met;
    /// weather and fire events act on the scenario's city and building.
    @Test func conditionsWeatherAndFire() throws {
        var game = try built("opening-day")
        game.world.scenario?.events = [
            ScenarioEvent(day: 1, hour: 7, kind: .grant, message: "Needs 100 units", amount: 1000, when: ScenarioObjective(metric: .occupiedUnits, target: 100)),
            ScenarioEvent(day: 1, hour: 7, kind: .fine, message: "Needs 100 units", amount: 700, when: ScenarioObjective(metric: .occupiedUnits, target: 100)),
            ScenarioEvent(day: 1, hour: 7, kind: .weather, message: "Storm", weather: "storm"),
            ScenarioEvent(day: 1, hour: 8, kind: .fire, message: "Fire!"),
        ]
        sim.advance(&game.world, by: 2 * 3600 + 60)
        let grants = game.world.ledger.journal.filter { $0.category == .grant && abs($0.amount) < 1000 || $0.amount == 1000 }
        #expect(!grants.contains { $0.amount == 1000 } && grants.contains { $0.amount == -700 })
        #expect(game.world.cities.values[0].weather?.today == "storm")
        #expect(game.world.incidents.log.contains { $0.kind == "fire" })
        #expect(game.world.scenario?.news?.map(\.text).first == "Needs 100 units — not earned this time.")
    }

    /// Winning scores stars and points; a loss scores partial points and no stars.
    @Test func scoring() throws {
        let game = try built("opening-day")
        var s = try #require(game.world.scenario)
        s.measured = [24, 20_000]                                        // targets 12 units, $5,000 profit
        let fast = sim.score(s, won: true, at: 2 * SimClock.secondsPerDay, world: game.world)
        #expect(fast.stars == 3)
        // 1000 + 50 × 8 days left + 250 + 250 (both at least doubled) + 2 × reputation 50.
        #expect(fast.score == 1000 + 400 + 500 + 100)
        s.measured = [12, 5_000]
        let slow = sim.score(s, won: true, at: 9 * SimClock.secondsPerDay, world: game.world)
        #expect(slow.stars == 1 && slow.score == 1000 + 50 + 100)
        s.measured = [6, nil]
        let lost = sim.score(s, won: false, at: 10 * SimClock.secondsPerDay, world: game.world)
        #expect(lost.stars == 0 && lost.score == 50)
    }

    /// The Opening Day win is scored.
    @Test func wonScenarioCarriesItsScore() throws {
        var game = try built("opening-day")
        Leasing.fillAll(&game.world, catalog: library.buildCatalog, rules: library.simulationRules)
        sim.advance(&game.world, by: 4 * SimClock.secondsPerDay)
        let result = try #require(game.world.scenario?.result)
        #expect(result.won && (result.stars ?? 0) >= 1 && (result.score ?? 0) >= 1000)
        print("[scenario] Opening Day won with \(result.stars ?? 0) stars, \(result.score ?? 0) points")
    }

    /// The panel and browser show news and restrictions in words.
    @Test func reportsShowNewsAndRestrictions() throws {
        var game = try built("lean-tower")
        sim.advance(&game.world, by: 3 * 3600)
        let summary = try #require(ScenarioSummary.make(world: game.world, engine: sim, library: library))
        #expect(summary.restrictions == ["No Studio Apartment", "Floors up to 12", "Fixed rents", "No staff"])
        #expect(summary.news.count == 1 && summary.news[0].hasPrefix("D1 08:00 · Offices only"))
        let brief = try #require(ScenarioBrief.all(library: library).first { $0.id == "lean-tower" })
        #expect(brief.restrictions.count == 4 && brief.events == 2)
    }
}
