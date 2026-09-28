import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// The demo tower with no tenants: the market has to fill it.
private func emptyTower() throws -> SimFixture {
    var f = try SimFixture()
    for t in f.world.tenants.values { Leasing.moveOut(t.id, world: &f.world) }
    return f
}

private func room(_ f: SimFixture, _ definition: String, floor: Int, left: Bool = true) throws -> Room {
    let rooms = f.world.rooms.values.filter { $0.definitionID == definition && $0.floors.lowest == floor }
        .sorted { $0.columns.start < $1.columns.start }
    return try #require(left ? rooms.first : rooms.last)
}

@Suite struct TenantModelTests {
    @Test func fillAllSignsDefaultTypesWithMembers() throws {
        let f = try SimFixture()
        #expect(f.world.tenants.count == 15)
        let byType = Dictionary(grouping: f.world.tenants.values, by: \.typeID).mapValues(\.count)
        #expect(byType == ["consultancy": 8, "couple": 7])
        for tenant in f.world.tenants {
            let members = f.world.people.values.filter { $0.tenantID == tenant.id }
            #expect(!members.isEmpty)
            #expect(members.allSatisfy { $0.anchorRoom == tenant.room })
            #expect(tenant.rent == Leasing.askingRent(f.world.rooms[tenant.room]!, world: f.world, catalog: f.library.buildCatalog))
        }
        #expect(f.world.tenants.values.contains { $0.name.hasSuffix("household") })
        #expect(f.world.tenants.values.contains { !$0.name.hasSuffix("household") })
        try f.world.validateIntegrity()
    }

    /// No two tenants share a name, even past the 30 surnames of the name pool (then
    /// double-barrelled names are used); members carry their household's name.
    @Test func tenantNamesAreUnique() throws {
        var f = try SimFixture()
        #expect(Set(f.world.tenants.values.map(\.name)).count == f.world.tenants.count)
        let rules = f.library.simulationRules
        let couple = try #require(rules.tenantType("couple")), consultancy = try #require(rules.tenantType("consultancy"))
        let home = try #require(f.world.rooms.values.first { $0.definitionID.hasPrefix("apartment") })
        let office = try #require(f.world.rooms.values.first { $0.definitionID.hasPrefix("office") })
        for _ in 0..<40 {
            let people = Leasing.sign(couple, into: home, at: 0, world: &f.world, rules: rules, catalog: f.library.buildCatalog, satisfaction: 0.6)
            let tenant = try #require(f.world.tenants.values.last)
            #expect(people.allSatisfy { f.world.people[$0]!.name.hasSuffix(tenant.name.replacingOccurrences(of: " household", with: "")) })
            Leasing.sign(consultancy, into: office, at: 0, world: &f.world, rules: rules, catalog: f.library.buildCatalog, satisfaction: 0.6)
        }
        let names = f.world.tenants.values.map(\.name)
        #expect(Set(names).count == names.count)
        #expect(names.contains { $0.contains("-") && $0.hasSuffix(" household") })
    }

    @Test func demolishingAUnitEndsTheLease() throws {
        var f = try SimFixture()
        let office = try room(f, "office-small", floor: 1)
        let tenant = try #require(f.world.tenants.values.first { $0.room == office.id })
        try ConstructionEngine(catalog: f.library.buildCatalog).apply(.demolishRoom(office.id), to: &f.world)
        PopulationSync.sync(&f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules)
        #expect(!f.world.tenants.contains(tenant.id))
        #expect(!f.world.people.values.contains { $0.tenantID == tenant.id })
        try f.world.validateIntegrity()
    }

    @Test func peopleWithoutTenantsAreAdopted() throws {
        var f = try SimFixture()
        let ids = f.world.tenants.values.map(\.id)
        for p in f.world.people.values { f.world.people.update(p.id) { $0.tenantID = nil } }
        for id in ids { f.world.tenants.remove(id) }
        PopulationSync.sync(&f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules)
        #expect(f.world.tenants.count == 15)
        #expect(f.world.people.values.allSatisfy { $0.tenantID != nil })
        try f.world.validateIntegrity()
    }
}

@Suite struct AppraisalTests {
    @Test func criteriaReflectTheBuilding() throws {
        let f = try emptyTower()
        let rules = f.library.simulationRules
        let couple = try #require(rules.tenantType("couple"))
        func appraise(_ r: Room) throws -> UnitAppraisal { try #require(Leasing.appraise(r, for: couple, world: f.world, engine: f.engine)) }
        // View improves with height.
        let low = try appraise(try room(f, "apartment-studio", floor: 5)), high = try appraise(try room(f, "apartment-studio", floor: 8))
        #expect(high.view > low.view)
        let lowRoom = try room(f, "apartment-studio", floor: 5), highRoom = try room(f, "apartment-studio", floor: 8)
        #expect(Double(high.rentPerMonth) / Double(highRoom.columns.count)
                > Double(low.rentPerMonth) / Double(lowRoom.columns.count))   // +1 % per storey
        // An office right above the basement plant room hears it; one higher up does not.
        let office = try #require(rules.tenantType("consultancy"))
        let quiet = try #require(Leasing.appraise(try room(f, "office-small", floor: 3, left: false), for: office, world: f.world, engine: f.engine))
        let nearPlant = try #require(Leasing.appraise(try room(f, "office-small", floor: 1, left: true), for: office, world: f.world, engine: f.engine))
        #expect(nearPlant.noise <= quiet.noise)
        #expect((0...1).contains(high.total) && high.affordable)
    }

    @Test func expensiveUnitsAreUnaffordableAndAccessNeedsARoute() throws {
        var f = try emptyTower()
        let rules = f.library.simulationRules
        var cheap = try #require(rules.tenantType("call-centre"))
        cheap.budgetPerModule = 100
        let office = try room(f, "office-small", floor: 4)
        let a = try #require(Leasing.appraise(office, for: cheap, world: f.world, engine: f.engine))
        #expect(!a.affordable && a.weakest == .tooExpensive)
        // Without any vertical transport the upper units cannot be reached.
        let c = ConstructionEngine(catalog: f.library.buildCatalog)
        for shaft in f.world.rooms.values where ["stairs", "elevator-shaft"].contains(shaft.definitionID) {
            try c.apply(.demolishRoom(shaft.id), to: &f.world)
        }
        f.engine.replanAfterConstruction(&f.world)
        let consultancy = try #require(rules.tenantType("consultancy"))
        let b = try #require(Leasing.appraise(office, for: consultancy, world: f.world, engine: f.engine))
        #expect(b.access == 0 && b.accessSeconds == .infinity && b.total == 0 && b.weakest == .poorAccess)
    }
}

@Suite struct MarketTests {
    /// Starting empty, prospects arrive over three days and fill part of the tower; every
    /// signing and decline is logged and counted; the run is reproducible.
    @Test func marketFillsAnEmptyTowerDeterministically() throws {
        func run() throws -> GameWorld {
            var f = try emptyTower()
            f.engine.advance(&f.world, by: 3 * 86_400)
            return f.world
        }
        let world = try run()
        let m = world.market
        #expect(m.prospects > 20)
        #expect(m.signed == world.tenants.count && m.signed >= 8)
        #expect(m.prospects == m.signed + m.declined.reduce(0, +))
        #expect(world.tenants.values.contains { $0.typeID != "consultancy" && $0.typeID != "couple" })
        #expect(world.people.values.allSatisfy { $0.tenantID != nil })
        #expect(m.log.count == min(MarketState.logLimit, m.prospects - m.declines(.noVacancy) + m.movedOut))
        try world.validateIntegrity()
        #expect(try run() == world)
        print("[market] 3 days: prospects \(m.prospects), signed \(m.signed), declined " +
              zip(DeclineReason.allCases, m.declined).map { "\($0.rawValue) \($1)" }.joined(separator: ", "))
    }

    /// Tenants who can no longer reach their unit review it badly and leave after three days.
    @Test func unreachableTenantsMoveOut() throws {
        var f = try SimFixture()
        let c = ConstructionEngine(catalog: f.library.buildCatalog)
        for shaft in f.world.rooms.values where ["stairs", "elevator-shaft"].contains(shaft.definitionID) {
            try c.apply(.demolishRoom(shaft.id), to: &f.world)
        }
        f.engine.advance(&f.world, by: 4 * 86_400 + 60)
        let upper = f.world.tenants.values.filter { f.world.rooms[$0.room]!.floors.lowest > 0 }
        #expect(upper.isEmpty)
        #expect(f.world.market.movedOut >= 14)
        #expect(f.world.market.log.contains { $0.outcome == .movedOut && $0.reason == .poorAccess })
        try f.world.validateIntegrity()
    }

    @Test func satisfiedTenantsStay() throws {
        var f = try SimFixture()
        f.engine.advance(&f.world, by: 4 * 86_400)
        #expect(f.world.market.movedOut == 0)
        #expect(f.world.tenants.values.allSatisfy { $0.satisfaction > 0.3 })
    }
}

@Suite struct TenantContentTests {
    @Test func tenantTypesAreValid() throws {
        let rules = try ContentLibrary.loadBase().simulationRules
        #expect(rules.tenantTypes.count == 12)                      // 6 households and firms, 6 amenity operators (0.22)
        let rooms: Set<String> = ["office-small", "apartment-studio", "shop", "restaurant", "fitness", "cinema", "theater", "sky-bar"]
        #expect(rules.tenantTypes.allSatisfy { $0.problems(schedules: rules.schedules, rooms: rooms).isEmpty })
        var bad = rules.tenantTypes[0]
        bad.schedules = ["resident-commuter"]                       // wrong role for a business
        #expect(!bad.problems(schedules: rules.schedules, rooms: rooms).isEmpty)
    }
}

@Suite struct LeasingReportTests {
    @Test func reportsDescribeLeasedAndVacantUnits() throws {
        var f = try SimFixture()
        f.run(until: "10:00")
        let leased = try room(f, "office-small", floor: 2)
        let report = try #require(UnitReport.make(room: leased, world: f.world, engine: f.engine))
        let occupant = try #require(report.occupant)
        #expect(occupant.members == 3 && occupant.present == 3 && occupant.typeName == "Consultancy")
        #expect(report.leasable && report.interest.isEmpty)
        // Vacate it: the report now lists interest per type, best first.
        Leasing.moveOut(f.world.tenants.values.first { $0.room == leased.id }!.id, world: &f.world)
        let vacant = try #require(UnitReport.make(room: leased, world: f.world, engine: f.engine))
        #expect(vacant.occupant == nil && vacant.interest.count == 3)
        #expect(zip(vacant.interest, vacant.interest.dropFirst()).allSatisfy { $0.appraisal.total >= $1.appraisal.total })
        let lobby = try #require(f.world.rooms.values.first { $0.definitionID == "lobby" })
        #expect(UnitReport.make(room: lobby, world: f.world, engine: f.engine)?.leasable == false)

        let summary = LeasingSummary.make(world: f.world, engine: f.engine, buildings: [f.building])
        #expect(summary.units == 15 && summary.leased == 14 && summary.businesses == 7 && summary.households == 7)
        #expect(summary.rentRoll == f.world.tenants.values.reduce(0) { $0 + $1.rent })
    }
}
