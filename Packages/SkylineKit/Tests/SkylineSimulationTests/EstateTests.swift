import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

@Suite struct EstateTests {
    let library = try! ContentLibrary.loadBase()

    func newGame() throws -> NewGame { try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: library) }

    @Test func startsOwnTheirPlotAndOfferTheRest() throws {
        let game = try newGame()
        let start = try #require(game.world.properties[game.activePropertyID])
        #expect(start.plotID == "calder-quay-lot")
        let offers = Estate.offers(world: game.world, library: library)
        #expect(offers.map(\.plot.id) == ["calder-ferry-lane", "harrowgate-crown-yard", "saltmere-harbour-row"])
        #expect(offers.first { $0.plot.id == "harrowgate-crown-yard" }?.city.economy?.rent == 1.35)
    }

    /// The overview's 24-hour figures add up: money booked to buildings plus the estate's own
    /// (the grant and the land here); each holding shows its own city's weather.
    @Test func overviewCountsEstateMoneyAndCityWeather() throws {
        var game = try newGame()
        game.world.ledger.post(Transaction(tick: 0, amount: 2_000_000, category: .grant, detail: "Test"))
        try Estate.buy("harrowgate-crown-yard", world: &game.world, library: library)
        game.world.ledger.post(Transaction(tick: 10, amount: -5_000, category: .maintenance, detail: "Test upkeep",
                                           building: game.world.buildings(on: game.activePropertyID).first?.id))
        let harrowgate = game.world.cities.values[1]
        game.world.setWeather(WeatherState(day: 0, yesterday: "storm", today: "storm", tomorrow: "clear", temperature: 11), city: harrowgate.id)
        let s = EstateSummary.make(world: game.world, library: library)
        let all = game.world.ledger.journal.reduce(0) { $0 + $1.amount }
        #expect(s.totalNet24h == all && s.cash == game.world.ledger.cash)
        #expect(s.holdings.reduce(0) { $0 + $1.net24h } == -5_000)
        #expect(s.estateNet24h == all + 5_000)
        #expect(s.holdings.map(\.weather) == [game.world.cities.values[0].weather.flatMap { library.simulationRules.weather?.kind($0.today) }
            .map { "\($0.name) \(Int(game.world.cities.values[0].weather!.temperature))°" } ?? "", "Storm 11°"])
    }

    @Test func buyingLandAddsACityAPropertyAndAFoundation() throws {
        var game = try newGame()
        game.world.ledger.post(Transaction(tick: 0, amount: 2_000_000, category: .grant, detail: "Test"))
        let cash = game.world.ledger.cash
        let property = try Estate.buy("harrowgate-crown-yard", world: &game.world, library: library)
        let p = try #require(game.world.properties[property])
        let city = try #require(game.world.cities[p.cityID])
        #expect(city.definitionID == "harrowgate" && city.economy == CityEconomy(rent: 1.35, construction: 1.25, demand: 1.15))
        #expect(game.world.cities.count == 2 && p.plotID == "harrowgate-crown-yard")
        let building = try #require(game.world.buildings(on: property).first)
        #expect(building.foundation.basementFloors == 2 && building.name == "Crown Yard Chambers")
        #expect(game.world.ledger.cash == cash - 2_400_000)
        #expect(game.world.ledger.journal.last?.category == .land)
        #expect(!Estate.offers(world: game.world, library: library).contains { $0.plot.id == "harrowgate-crown-yard" })
        #expect(throws: EstateError.alreadyOwned("harrowgate-crown-yard")) { try Estate.buy("harrowgate-crown-yard", world: &game.world, library: library) }
        #expect(throws: EstateError.notForSale("calder-quay-lot")) {
            var w = GameWorld()
            _ = w.addCity(definitionID: "x", name: "x", seed: 1)
            try Estate.buy("calder-quay-lot", world: &w, library: library)
        }
        // A second plot in a city the estate already has does not add the city twice.
        try Estate.buy("calder-ferry-lane", world: &game.world, library: library)
        #expect(game.world.cities.count == 2 && game.world.properties.count == 3)
        try game.world.validateIntegrity()
    }

    @Test func landNeedsTheMoney() throws {
        var game = try newGame()
        game.world.ledger.post(Transaction(tick: 0, amount: -game.world.ledger.cash + 100_000, category: .grant, detail: "Spend"))
        let before = game.world
        #expect(throws: EstateError.insufficientFunds(needed: 450_000, available: 100_000)) {
            try Estate.buy("saltmere-harbour-row", world: &game.world, library: library)
        }
        #expect(game.world == before)
    }

    /// Every plot for sale can actually be bought on a fresh estate (its foundation fits).
    @Test func everyPlotForSaleIsBuildable() throws {
        for offer in Estate.offers(world: try newGame().world, library: library) {
            var game = try newGame()
            game.world.ledger.post(Transaction(tick: 0, amount: 10_000_000, category: .grant, detail: "Test"))
            let property = try Estate.buy(offer.plot.id, world: &game.world, library: library)
            let building = try #require(game.world.buildings(on: property).first)
            // The larger plots take the demo tower (32 m wide, one basement).
            if building.footprint.count >= 32 {
                let engine = ConstructionEngine(catalog: library.buildCatalog)
                for c in library.blueprint("demo-tower")!.commands(for: building) { try engine.apply(c, to: &game.world) }
            }
        }
    }

    @Test func pricesFollowTheCity() throws {
        var game = try newGame()
        let calder = try #require(game.world.buildings(on: game.activePropertyID).first)
        let crown = try Estate.buy("harrowgate-crown-yard", world: &game.world, library: library)
        let harrow = try #require(game.world.buildings(on: crown).first)
        let engine = ConstructionEngine(catalog: library.buildCatalog)
        func groundCost(_ b: Building) throws -> Int {
            try engine.validate(.buildFloor(building: b.id, level: 0, span: ColumnSpan(start: b.footprint.start, count: 20)), in: game.world).get().cost
        }
        #expect(try groundCost(harrow) == Int((Double(try groundCost(calder)) * 1.25).rounded()))
        // Rents: build a floor with an office in each and compare asking rents.
        for b in [calder, harrow] {
            for level in 0...1 {
                try engine.apply(.buildFloor(building: b.id, level: level, span: ColumnSpan(start: b.footprint.start, count: 20)), to: &game.world)
            }
            try engine.apply(.placeRoom(building: b.id, definition: "office-small", columns: ColumnSpan(start: b.footprint.start, count: 10),
                                        floors: FloorSpan(lowest: 1, highest: 1)), to: &game.world)
        }
        let rents = [calder, harrow].map { b in
            Leasing.askingRent(game.world.rooms(in: b.id).first!, world: game.world, catalog: library.buildCatalog)!
        }
        #expect(abs(Double(rents[1]) / Double(rents[0]) - 1.35) < 0.01)
    }

    /// Each city has its own market: towers in two cities both fill, from their own prospects.
    @Test func eachCityLetsItsOwnUnits() throws {
        var game = try newGame()
        game.world.ledger.post(Transaction(tick: 0, amount: 10_000_000, category: .grant, detail: "Test"))
        let saltmere = try Estate.buy("saltmere-harbour-row", world: &game.world, library: library)
        let engine = ConstructionEngine(catalog: library.buildCatalog)
        for property in [game.activePropertyID, saltmere] {
            let b = game.world.buildings(on: property).first!
            for c in library.blueprint("demo-tower")!.commands(for: b) { try engine.apply(c, to: &game.world) }
        }
        let sim = SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog)
        PopulationSync.sync(&game.world, catalog: library.buildCatalog, rules: library.simulationRules)
        sim.replanAfterConstruction(&game.world)
        sim.advance(&game.world, by: 3 * 86_400)
        func leased(_ p: PropertyID) -> Int {
            let ids = Set(game.world.buildings(on: p).map(\.id))
            return game.world.tenants.values.filter { ids.contains($0.buildingID) }.count
        }
        print("[estate] leased after 3 days: Port Calder \(leased(game.activePropertyID)), Saltmere \(leased(saltmere))")
        #expect(leased(game.activePropertyID) > 5 && leased(saltmere) > 0)
        try game.world.validateIntegrity()
    }

    /// A pre-12 property has no plot id and its city the default market.
    @Test func olderSavesAreMatchedToTheirPlots() throws {
        var w = GameWorld()
        let city = w.addCity(definitionID: "harrowgate", name: "Harrowgate", seed: 4411)
        let prop = try w.addProperty(cityID: city, name: "Crown Yard", plot: Plot(frontage: ColumnSpan(start: 0, count: 40), maxBasementFloors: 4,
                                                                                siteMargin: 40, strata: library.city("harrowgate")!.geology))
        Estate.adoptLegacy(&w, library: library)
        #expect(w.properties[prop]?.plotID == "harrowgate-crown-yard")
        #expect(w.cities[city]?.economy.rent == 1.35)
    }
}
