import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

@Suite struct EconomyTests {
    @Test func newGamesStartWithCapital() throws {
        let lib = try ContentLibrary.loadBase()
        let game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        #expect(game.world.ledger.cash == 2_500_000)
        #expect(game.world.ledger.journal.first?.category == .grant)
    }

    /// Each 06:00 closing collects rent from every tenant and pays upkeep, utilities and
    /// interest; every transaction is attributed; cash equals the journal's sum.
    @Test func dailyClosingIsTraceable() throws {
        var f = try SimFixture()
        f.world.ledger.post(Transaction(tick: 0, amount: 1_000_000, category: .grant, detail: "Test capital"))
        let economy = try #require(f.library.simulationRules.economy)
        #expect(Economy.borrow(&f.world, rules: economy))
        f.engine.advance(&f.world, by: 86_400)                          // one closing (day 2, 06:00)
        let today = f.world.ledger.days.last!
        let rentRoll = f.world.tenants.values.reduce(0) { $0 + $1.rent / economy.rentDaysPerMonth }
        #expect(today.amount(.rent) == rentRoll)
        #expect(today.amount(.maintenance) < 0 && today.amount(.utilities) < 0 && today.amount(.interest) < 0)
        let rents = f.world.ledger.journal.filter { $0.category == .rent }
        #expect(rents.count == f.world.tenants.count && rents.allSatisfy { $0.tenant != nil && $0.room != nil })
        #expect(f.world.ledger.cash == f.world.ledger.journal.reduce(0) { $0 + $1.amount })
        print("[economy] day 2 closing: rent \(today.amount(.rent)), maintenance \(today.amount(.maintenance)), " +
              "utilities \(today.amount(.utilities)), interest \(today.amount(.interest))")
    }

    @Test func loansAreLimitedAndRepaid() throws {
        var f = try SimFixture()
        let economy = try #require(f.library.simulationRules.economy)
        var taken = 0
        while Economy.borrow(&f.world, rules: economy) { taken += 1 }
        #expect(taken == economy.maxLoans / economy.loanStep && f.world.ledger.loans == economy.maxLoans)
        #expect(Economy.repay(&f.world, rules: economy))
        #expect(f.world.ledger.loans == economy.maxLoans - economy.loanStep)
    }

    @Test func sevenDaysInTheRedIsBankruptcy() throws {
        var f = try SimFixture()
        f.world.ledger.post(Transaction(tick: 0, amount: -f.world.ledger.cash - 10_000_000, category: .grant, detail: "Debt"))
        f.engine.advance(&f.world, by: 6 * 86_400)
        #expect(!f.world.ledger.bankrupt && f.world.ledger.negativeDays == 6)
        f.engine.advance(&f.world, by: 86_400)
        #expect(f.world.ledger.bankrupt)
    }

    /// A higher rent level raises asking rents; prospects then decline for price more often.
    @Test func rentLevelDrivesAskingRentAndDemand() throws {
        func run(level: Double) throws -> MarketState {
            var f = try SimFixture()
            for t in f.world.tenants.values { Leasing.moveOut(t.id, world: &f.world) }
            Economy.setRentLevel(level, building: f.building, in: &f.world)
            f.engine.advance(&f.world, by: 2 * 86_400)
            return f.world.market
        }
        var f = try SimFixture()
        let office = f.world.rooms.values.first { $0.definitionID == "office-small" }!
        let base = Leasing.askingRent(office, world: f.world, catalog: f.library.buildCatalog)!
        Economy.setRentLevel(1.5, building: f.building, in: &f.world)
        #expect(Leasing.askingRent(office, world: f.world, catalog: f.library.buildCatalog)! == Int((Double(base) * 1.5).rounded()))
        Economy.setRentLevel(9, building: f.building, in: &f.world)
        #expect(f.world.buildings[f.building]!.rentLevel == 1.6)
        let normal = try run(level: 1), expensive = try run(level: 1.5)
        #expect(expensive.declines(.tooExpensive) > normal.declines(.tooExpensive))
        #expect(expensive.signed < normal.signed)
    }

    /// Phase E: a unit's own rent setting multiplies the building's level, in 10 % steps
    /// within 60…160 %; signed rents stay; only rentable units have one.
    @Test func unitRentFactorAdjustsOneUnit() throws {
        var f = try SimFixture()
        let catalog = f.library.buildCatalog
        let offices = f.world.rooms.values.filter { $0.definitionID == "office-small" }
        let office = offices[0], other = offices[1]
        let base = Leasing.askingRent(office, world: f.world, catalog: catalog)!
        let otherBase = Leasing.askingRent(other, world: f.world, catalog: catalog)!
        let signed = f.world.tenants.values.first { $0.room == office.id }!.rent
        #expect(Economy.setRentFactor(1.33, room: office.id, in: &f.world, catalog: catalog))
        #expect(f.world.rooms[office.id]?.rentFactor == 1.3)
        Economy.setRentLevel(1.2, building: f.building, in: &f.world)
        let rent = Leasing.askingRent(f.world.rooms[office.id]!, world: f.world, catalog: catalog)!
        #expect(abs(Double(rent) - Double(base) * 1.3 * 1.2) <= 1)
        #expect(abs(Double(Leasing.askingRent(other, world: f.world, catalog: catalog)!) - Double(otherBase) * 1.2) <= 1)
        #expect(f.world.tenants.values.first { $0.room == office.id }!.rent == signed)
        Economy.setRentFactor(0.1, room: office.id, in: &f.world, catalog: catalog)
        #expect(f.world.rooms[office.id]?.rentFactor == 0.6)
        Economy.setRentFactor(1, room: office.id, in: &f.world, catalog: catalog)
        #expect(f.world.rooms[office.id]?.rentFactor == nil)
        let lobby = f.world.rooms.values.first { $0.definitionID == "lobby" }!
        #expect(!Economy.setRentFactor(1.2, room: lobby.id, in: &f.world, catalog: catalog))
        #expect(UnitReport.make(room: f.world.rooms[office.id]!, world: f.world, engine: f.engine)?.rentFactor == 1)
    }
}
