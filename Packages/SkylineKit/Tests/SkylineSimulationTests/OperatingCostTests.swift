import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// Phase E: taxes, energy prices, waste.
@Suite struct TaxTests {
    /// The assessed value is what the building cost: plates and rooms at content prices.
    @Test func assessedValueIsTheBuildCost() throws {
        let f = try SimFixture()
        let catalog = f.library.buildCatalog
        let b = try #require(f.world.buildings[f.building])
        var expected = 0
        for p in b.floors { expected += (p.level < 0 ? catalog.rules.basementSlabCostPerModule : catalog.rules.slabCostPerModule) * p.span.count }
        for r in f.world.rooms(in: b.id) { expected += catalog.spec(r.definitionID)!.costPerModule * r.columns.count * r.floors.count }
        #expect(Taxes.assessedValue(b, world: f.world, catalog: catalog) == expected)
        let economy = try #require(f.engine.rules.economy)
        #expect(Taxes.propertyTax(b, world: f.world, catalog: catalog, rules: economy) == Int((Double(expected) * 0.004).rounded()))
    }

    /// The closing books property tax per building and profit tax on its positive result.
    @Test func closingBooksPropertyAndProfitTax() throws {
        var f = try SimFixture()
        f.engine.advance(&f.world, by: 86_400)                          // one closing (day 2, 06:00)
        let taxes = f.world.ledger.journal.filter { $0.category == .taxes }
        let property = try #require(taxes.first { $0.detail.hasPrefix("Property tax") })
        #expect(property.building == f.building && property.amount < 0)
        let profit = try #require(taxes.first { $0.detail.hasPrefix("Profit tax") })
        // 15 % of the closing's result before the profit tax (rent in, costs and property tax out).
        let closing = f.world.ledger.journal.filter { $0.tick == profit.tick && $0 != profit && $0.category != .grant }
        let result = closing.reduce(0) { $0 + $1.amount }
        #expect(profit.amount == -Int((Double(result) * 0.15).rounded()))
        print("[taxes] property \(property.amount), profit \(profit.amount) on \(result)")
    }

    /// No profit, no profit tax: only the closing's own bookings count.
    @Test func noProfitTaxOnALoss() throws {
        var f = try SimFixture()
        let now = f.world.clock.tick
        let before = f.world.ledger.totals(onDay: SimClock.day(now))
        f.world.ledger.post(Transaction(tick: now, amount: -5_000, category: .maintenance, detail: "Loss"))
        f.engine.postProfitTax(since: before, at: now, world: &f.world)
        #expect(!f.world.ledger.journal.contains { $0.category == .taxes })
        let again = f.world.ledger.totals(onDay: SimClock.day(now))
        f.world.ledger.post(Transaction(tick: now, amount: 10_000, category: .rent, detail: "Profit"))
        f.engine.postProfitTax(since: again, at: now, world: &f.world)
        #expect(f.world.ledger.journal.last?.amount == -1_500)
    }
}

@Suite struct WasteAndEnergyTests {
    /// The waste room takes up to its capacity; collection is billed per kg.
    @Test func wasteIsCollectedAndBilled() throws {
        var f = try SimFixture()
        let produced = Waste.produced(in: f.building, world: f.world, rules: f.engine.rules)
        let capacity = Waste.capacity(of: f.building, world: f.world, catalog: f.library.buildCatalog)
        #expect(capacity == 240 && produced > 0)                      // one 3-module waste room
        f.engine.advance(&f.world, by: 86_400)
        let bill = try #require(f.world.ledger.journal.first { $0.category == .waste })
        let collected = min(Waste.produced(in: f.building, world: f.world, rules: f.engine.rules), capacity)
        #expect(abs(Double(-bill.amount) - collected * 0.8) <= 1)
    }

    /// Without a waste room everything overflows and the building gets dirtier.
    @Test func overflowDirtiesTheBuilding() throws {
        func cleanliness(wasteRoom: Bool) throws -> Double {
            var f = try SimFixture()
            if !wasteRoom, let room = f.world.rooms.values.first(where: { $0.definitionID == "waste-room" }) {
                try ConstructionEngine(catalog: f.library.buildCatalog).apply(.demolishRoom(room.id), to: &f.world)
                PopulationSync.sync(&f.world, catalog: f.library.buildCatalog, rules: f.engine.rules)
            }
            f.engine.advance(&f.world, by: 86_400)
            let rooms = f.world.rooms.values.filter { $0.definitionID == "lobby" }
            return rooms.map { f.world.upkeep[$0.id]!.cleanliness }.reduce(0, +)
        }
        #expect(try cleanliness(wasteRoom: false) < cleanliness(wasteRoom: true) - 0.2)
    }

    /// Energy prices move each morning, deterministically, within half to twice the base,
    /// and scale the utilities bill.
    @Test func energyPricesMoveAndScaleUtilities() throws {
        var a = try SimFixture(), b = try SimFixture()
        a.engine.advance(&a.world, by: 5 * 86_400)
        b.engine.advance(&b.world, by: 5 * 86_400)
        let price = try #require(a.world.cities.values[0].energyPrice)
        #expect(price == b.world.cities.values[0].energyPrice && price != 1 && (0.5...2).contains(price))
        func utilities(_ p: Double) throws -> Int {
            var f = try SimFixture()
            f.world.setEnergyPrice(p, city: f.world.cities.values[0].id)
            let before = f.world.ledger.totals(onDay: 1)
            f.engine.advance(&f.world, by: 86_400)
            return f.world.ledger.totals(onDay: 1).amount(.utilities) - before.amount(.utilities)
        }
        let normal = try utilities(1), double = try utilities(2)
        #expect(abs(Double(double) - 2 * Double(normal)) <= 3)
    }
}
