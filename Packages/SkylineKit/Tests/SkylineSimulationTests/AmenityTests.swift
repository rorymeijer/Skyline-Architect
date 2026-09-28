import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// Amenities and visitors (0.22): shops, a restaurant, a cinema, a fitness club, a theatre
/// and a sky bar in the demo plaza, all leased.
@Suite struct AmenityTests {
    func plaza() throws -> SimFixture { try SimFixture(blueprint: "demo-plaza") }

    /// A customer inside an amenity: a visitor at their venue, or an occupant away from their unit.
    func isVisiting(_ p: Person, in f: SimFixture) -> Bool {
        guard case let .room(r, _) = p.place, p.role == .visitor || r != p.anchorRoom, let room = f.world.rooms[r] else { return false }
        return f.engine.rules.amenity(for: room.definitionID) != nil
    }

    func takings(_ f: SimFixture) -> Int { f.world.tenants.values.reduce(0) { $0 + ($1.sales?.takings ?? 0) } }

    @Test func everyAmenityHasAnOperatorAndAnInterior() throws {
        let lib = try ContentLibrary.loadBase()
        let rules = lib.simulationRules
        #expect(rules.amenities.map(\.room) == ["shop", "restaurant", "fitness", "cinema", "theater", "sky-bar"])
        for a in rules.amenities {
            #expect(!rules.tenantTypes(for: a.room).isEmpty, "\(a.room)")
            #expect(a.problems(rooms: lib.orderedRooms).isEmpty, "\(a.room)")
        }
        var bad = rules.amenities[0]
        bad.room = "nowhere"
        bad.closes = bad.opens
        #expect(bad.problems(rooms: lib.orderedRooms).count == 2)
    }

    @Test func openingHoursMayRunPastMidnight() throws {
        let bar = try #require(try ContentLibrary.loadBase().simulationRules.amenity(for: "sky-bar"))
        #expect(bar.isOpen(atSecondOfDay: 23 * 3600) && bar.isOpen(atSecondOfDay: 1800))
        #expect(!bar.isOpen(atSecondOfDay: 3 * 3600) && !bar.isOpen(atSecondOfDay: 12 * 3600))
        #expect(bar.secondsUntilClosing(atSecondOfDay: 23 * 3600) == 2 * 3600)
    }

    /// At lunch some office workers eat at the restaurant or browse the shops instead of
    /// going out; each visit is booked on the operator's takings.
    @Test func workersLunchInTheBuilding() throws {
        var f = try plaza()
        f.run(until: "12:40")
        let lunching = f.count { $0.role == .worker && isVisiting($0, in: f) }
        print("[amenities] \(lunching) workers at lunch in the building, takings \(takings(f))")
        #expect(lunching > 0)
        #expect(takings(f) > 0)
        f.run(until: "14:30")
        #expect(f.count { $0.role == .worker && isVisiting($0, in: f) } < lunching)
    }

    /// Street visitors come by during opening hours, stay and leave; at the next morning's
    /// closing the landlord gets the turnover share and yesterday's figures are kept.
    @Test func streetVisitorsComeStayLeaveAndPay() throws {
        var f = try plaza()
        f.run(until: "20:30")
        let inside = f.count { $0.role == .visitor && isVisiting($0, in: f) }
        #expect(inside > 0)
        #expect(f.world.tenants.values.contains { ($0.sales?.streetVisits ?? 0) > 0 })
        f.run(until: "06:30", day: 1)
        let share = f.world.ledger.journal.filter { $0.category == .turnover }
        #expect(!share.isEmpty && share.allSatisfy { $0.amount > 0 })
        let sold = f.world.tenants.values.compactMap(\.sales)
        #expect(sold.contains { $0.lastVisits > 0 && $0.lastStreetVisits > 0 && $0.lastTakings > 0 })
        #expect(sold.allSatisfy { $0.visits <= $0.lastVisits })
        // The share is the content's fraction of the day's takings.
        let restaurant = try #require(f.world.tenants.values.first { f.world.rooms[$0.room]?.definitionID == "restaurant" })
        let paid = share.filter { $0.tenant == restaurant.id }.map(\.amount).reduce(0, +)
        #expect(paid == Int((Double(restaurant.sales!.lastTakings) * 0.07).rounded()))
        // Nobody who left lingers: departed visitors are purged hourly.
        #expect(f.count { $0.role == .visitor && $0.place == .outside && $0.nextGoal == nil } == 0)
        print("[amenities] \(sold.map(\.lastVisits).reduce(0, +)) visits yesterday, share \(share.map(\.amount).reduce(0, +))")
        try f.world.validateIntegrity()
    }

    /// A vacant amenity is closed: nobody comes (the market may let some of them again
    /// during the day; those still vacant in the evening never had a customer).
    @Test func vacantAmenitiesDrawNobody() throws {
        var f = try plaza()
        let venues = f.world.rooms.values.filter { f.engine.rules.amenity(for: $0.definitionID) != nil }.map(\.id)
        for t in f.world.tenants.values where venues.contains(t.room) { Leasing.moveOut(t.id, world: &f.world) }
        f.run(until: "08:55")
        #expect(f.count { $0.role == .visitor } == 0)
        f.run(until: "21:00")
        let vacant = Set(venues.filter { v in !f.world.tenants.values.contains { $0.room == v } })
        #expect(!vacant.isEmpty)
        #expect(f.count { p in p.visit.map(vacant.contains) ?? false } == 0)
        #expect(f.count { p in if case let .room(r, _) = p.place { vacant.contains(r) } else { false } } == 0)
    }

    /// Open amenities make the other units of the building more attractive.
    @Test func amenitiesAddAppeal() throws {
        var f = try plaza()
        let studio = try #require(f.world.rooms.values.first { $0.definitionID == "apartment-studio" })
        let couple = try #require(f.engine.rules.tenantType("couple"))
        let with = try #require(Leasing.appraise(studio, for: couple, world: f.world, engine: f.engine))
        #expect(abs(with.amenities - 0.14) < 1e-9)                          // six kinds: 0.02 + 0.03 + 0.03 + 0.02 + 0.02 + 0.02
        for t in f.world.tenants.values where f.engine.rules.amenity(for: f.world.rooms[t.room]!.definitionID) != nil {
            Leasing.moveOut(t.id, world: &f.world)
        }
        let without = try #require(Leasing.appraise(studio, for: couple, world: f.world, engine: f.engine))
        #expect(without.amenities == 0 && without.total < with.total)
    }

    /// Demolishing a venue sends its customers away; the world stays consistent.
    @Test func demolishingAVenueSendsCustomersAway() throws {
        var f = try plaza()
        f.run(until: "20:15")
        let cinema = try #require(f.world.rooms.values.first { $0.definitionID == "cinema" })
        #expect(f.count { $0.visit == cinema.id } > 0)
        let construction = ConstructionEngine(catalog: f.library.buildCatalog)
        try construction.apply(.demolishRoom(cinema.id), to: &f.world)
        PopulationSync.sync(&f.world, catalog: f.library.buildCatalog, rules: f.engine.rules)
        #expect(f.count { $0.visit == cinema.id } == 0)
        try f.world.validateIntegrity()
        f.run(until: "22:00")
        try f.world.validateIntegrity()
    }

    /// Same result however the ticks are batched.
    @Test func visitsAreDeterministic() throws {
        var a = try plaza(), b = try plaza()
        a.run(until: "13:10")
        for _ in 0..<((a.world.clock.tick - b.world.clock.tick) / 997) { b.engine.advance(&b.world, by: 997) }
        b.engine.advance(&b.world, by: a.world.clock.tick - b.world.clock.tick)
        #expect(a.world == b.world)
    }
}
