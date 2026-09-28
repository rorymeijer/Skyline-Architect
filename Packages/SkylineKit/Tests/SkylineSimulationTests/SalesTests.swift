import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// Flats for sale next to flats for rent (0.20.3).
@Suite struct SalesTests {
    /// The demo tower with its studios vacant and offered for sale.
    func studiosForSale() throws -> (SimFixture, [Room]) {
        var f = try SimFixture()
        let studios = f.world.rooms.values.filter { $0.definitionID == "apartment-studio" }
        for s in studios {
            if let t = f.world.tenants.values.first(where: { $0.room == s.id }) { Leasing.moveOut(t.id, world: &f.world) }
            try Leasing.setTenure(.forSale, room: s.id, world: &f.world, rules: f.engine.rules, catalog: f.library.buildCatalog)
        }
        return (f, studios.compactMap { f.world.rooms[$0.id] })
    }

    @Test func onlyVacantUnsoldFlatsCanBeOfferedForSale() throws {
        var f = try SimFixture()
        let rules = f.engine.rules, catalog = f.library.buildCatalog
        let office = try #require(f.world.rooms.values.first { $0.definitionID == "office-small" })
        let studio = try #require(f.world.rooms.values.first { $0.definitionID == "apartment-studio" })
        #expect(throws: Leasing.TenureError.noBuyers) { try Leasing.setTenure(.forSale, room: office.id, world: &f.world, rules: rules, catalog: catalog) }
        #expect(throws: Leasing.TenureError.occupied) { try Leasing.setTenure(.forSale, room: studio.id, world: &f.world, rules: rules, catalog: catalog) }
        let tenant = try #require(f.world.tenants.values.first { $0.room == studio.id })
        Leasing.moveOut(tenant.id, world: &f.world)
        try Leasing.setTenure(.forSale, room: studio.id, world: &f.world, rules: rules, catalog: catalog)
        #expect(f.world.rooms[studio.id]?.tenure == .forSale)
        try Leasing.setTenure(.rent, room: studio.id, world: &f.world, rules: rules, catalog: catalog)
        #expect(f.world.rooms[studio.id]?.tenure == nil)
    }

    /// Households buy flats for sale: the price (asking rent × 100) is booked as a sale, the
    /// flat is privately owned, and the owner pays a quarter of the rent as service charges.
    @Test func householdsBuyAndPayServiceCharges() throws {
        var (f, studios) = try studiosForSale()
        let prices = Dictionary(uniqueKeysWithValues: studios.map { ($0.id, Leasing.salePrice($0, world: f.world, catalog: f.library.buildCatalog, rules: f.engine.rules)!) })
        f.run(until: "07:00", day: 3)
        let owners = f.world.tenants.values.filter(\.isOwner)
        print("[sales] \(owners.count) of \(studios.count) studios sold in 3 days")
        #expect(!owners.isEmpty)
        for o in owners {
            let room = try #require(f.world.rooms[o.room])
            #expect(room.tenure == .owned && room.definitionID == "apartment-studio")
            #expect(o.purchasePrice == prices[room.id])
            #expect(f.world.ledger.journal.contains { $0.category == .sales && $0.tenant == o.id && $0.amount == o.purchasePrice })
            let rent = Leasing.askingRent(room, world: f.world, catalog: f.library.buildCatalog)!
            #expect(o.rent == Int((Double(rent) * 0.25).rounded()))
            if o.since < 2 * SimClock.secondsPerDay {
                #expect(f.world.ledger.journal.contains { $0.tenant == o.id && $0.detail.hasPrefix("Service charges") && $0.amount == o.rent })
            }
        }
        // Businesses never buy; the offices kept renting.
        #expect(f.world.tenants.values.filter { !$0.isOwner }.allSatisfy { f.world.rooms[$0.room]?.tenure == nil })
        try f.world.validateIntegrity()
    }

    /// A sold flat cannot be demolished or cut by a shaft.
    @Test func soldFlatsBelongToTheirOwners() throws {
        var (f, studios) = try studiosForSale()
        let couple = try #require(f.engine.rules.tenantType("couple"))
        Leasing.sign(couple, into: studios[0], at: f.world.clock.tick, world: &f.world, rules: f.engine.rules, catalog: f.library.buildCatalog, satisfaction: 0.7)
        let sold = try #require(f.world.rooms[studios[0].id])
        #expect(throws: Leasing.TenureError.sold) {
            try Leasing.setTenure(.rent, room: sold.id, world: &f.world, rules: f.engine.rules, catalog: f.library.buildCatalog)
        }
        let construction = ConstructionEngine(catalog: f.library.buildCatalog)
        #expect(construction.validate(.demolishRoom(sold.id), in: f.world) == .failure(.privatelyOwned))
        let stairs = BuildCommand.placeRoom(building: sold.buildingID, definition: "stairs", columns: ColumnSpan(start: sold.columns.start + 1, count: 4),
                                            floors: FloorSpan(lowest: sold.floors.lowest, highest: sold.floors.lowest + 1))
        #expect(construction.validate(stairs, in: f.world) == .failure(.privatelyOwned))
    }

    /// Owners hold on three times as long as renters; their flat is then resold between
    /// private parties: no new sale for the player, the flat stays owned.
    @Test func ownersStayLongerAndTheirFlatsAreResold() throws {
        var (f, studios) = try studiosForSale()
        let r = f.engine.rules
        let grumpy = r.tenantTypes.map { t -> TenantType in var t = t; t.leaveBelow = 1; return t }  // every review is bad
        let rules = SimulationRules(schedules: r.schedules, names: r.names, elevators: r.elevators, tenantTypes: grumpy,
                                    economy: r.economy, facilities: r.facilities, progression: r.progression, weather: r.weather, events: r.events)
        let engine = SimulationEngine(rules: rules, catalog: f.library.buildCatalog)
        let couple = try #require(rules.tenantType("couple"))
        Leasing.sign(couple, into: studios[0], at: f.world.clock.tick, world: &f.world, rules: rules, catalog: f.library.buildCatalog, satisfaction: 0.7)
        let owner = try #require(f.world.tenants.values.first { $0.room == studios[0].id })
        let renter = try #require(f.world.tenants.values.first { !$0.isOwner })
        let sales = f.world.ledger.journal.filter { $0.category == .sales }.count
        func closings(_ n: Int) { for _ in 0..<n { engine.advance(&f.world, by: SimClock.secondsPerDay) } }
        closings(4)
        #expect(!f.world.tenants.contains(renter.id) && f.world.tenants.contains(owner.id))
        closings(6)
        #expect(!f.world.tenants.contains(owner.id))
        #expect(f.world.rooms[studios[0].id]?.tenure == .owned)
        if let next = f.world.tenants.values.first(where: { $0.room == studios[0].id }) {
            #expect(next.purchasePrice == 0)                                  // bought from the previous owner
        }
        #expect(f.world.ledger.journal.filter { $0.category == .sales && $0.room == studios[0].id }.count == 1)
        #expect(f.world.ledger.journal.filter { $0.category == .sales }.count >= sales + 1)
    }
}
