import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

private func room(_ f: SimFixture, _ id: String) throws -> Room {
    try #require(f.world.rooms.values.first { $0.definitionID == id })
}

@Suite struct UtilityTests {
    @Test func demoTowerIsFullySupplied() throws {
        let f = try SimFixture()
        let s = Utilities.allocate(building: f.building, world: f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules)
        for u in ["electricity", "water", "hvac", "data"] {
            #expect(s.supply[u]! >= s.demand[u]!, "\(u) supply \(s.supply[u]!) demand \(s.demand[u]!)")
            #expect(s.shortOf(u).isEmpty)
        }
        #expect(f.world.rooms.values.allSatisfy { s.score($0.id) == 1 })
    }

    @Test func removingEquipmentCausesShortages() throws {
        var f = try SimFixture()
        let electrical = try room(f, "electrical-room")
        try ConstructionEngine(catalog: f.library.buildCatalog).apply(.demolishRoom(electrical.id), to: &f.world)
        let s = Utilities.allocate(building: f.building, world: f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules)
        let office = try room(f, "office-small")
        #expect(s.supply["electricity"] ?? 0 == 0)
        #expect(s.shortOf("electricity").contains(office.id))
        #expect(s.score(office.id) < 1 && s.score(office.id) >= 0.7)   // three of four utilities remain
    }

    /// Consumers are served lowest floor first from the nearest equipment in range; when the
    /// capacity is used up, higher floors go short. The sky tower's climate plant is too small.
    @Test func capacityRunsOutFromTheTop() throws {
        let f = try SkyFixture()
        let s = Utilities.allocate(building: f.building, world: f.world, catalog: f.library.buildCatalog, rules: f.engine.rules)
        #expect(s.demand["hvac"]! > s.supply["hvac"]!)
        func hvac(_ floor: Int) -> Double {
            let r = f.world.rooms.values.first { $0.floors.lowest == floor && $0.definitionID == "office-small" }!
            return s.served[r.id]?["hvac"] ?? 0
        }
        #expect(hvac(1) == 1)
        #expect(hvac(40) < hvac(1))
    }

    @Test func failedEquipmentSuppliesNothing() throws {
        var f = try SimFixture()
        let plants = f.world.rooms.values.filter { $0.definitionID == "mechanical" }.map(\.id)   // basement and floor 8
        #expect(plants.count == 2)
        for id in plants { f.world.upkeep.update(id) { $0.condition = 0.05 } }
        let s = Utilities.allocate(building: f.building, world: f.world, catalog: f.library.buildCatalog, rules: f.library.simulationRules)
        #expect(s.broken == plants.sorted())
        #expect(s.supply["hvac"] == 0 && !s.shortOf("hvac").isEmpty)
    }
}

@Suite struct UpkeepAndStaffTests {
    @Test func roomsGetDirtyAndWornAndJobsOpen() throws {
        var f = try SimFixture()
        f.engine.advance(&f.world, by: 5 * 86_400)
        let office = try room(f, "office-small")
        let u = try #require(f.world.upkeep[office.id])
        #expect(u.cleanliness < 0.8 && u.condition < 1)
        #expect(f.world.facilities.jobs.contains { $0.kind == .clean })
        try f.world.validateIntegrity()
    }

    /// Hired janitors and technicians come in for their shift, travel to jobs (stairs and
    /// elevators), restore rooms, go home in the evening and are paid daily.
    @Test func staffWorkTheirShiftAndGetPaid() throws {
        var f = try SimFixture()
        f.engine.advance(&f.world, by: 3 * 86_400)                     // let dirt build up
        let rules = f.library.simulationRules
        FacilitiesManagement.hire(.janitor, building: f.building, world: &f.world, rules: rules)
        FacilitiesManagement.hire(.janitor, building: f.building, world: &f.world, rules: rules)
        FacilitiesManagement.hire(.technician, building: f.building, world: &f.world, rules: rules)
        let openBefore = f.world.facilities.jobs.count
        var sawWorking = false, sawTravelling = false
        let start = f.world.clock.tick
        while f.world.clock.tick < start + 86_400 {
            f.engine.advance(&f.world, by: 60)
            for p in f.world.people where p.role.isStaff {
                if case .room = p.place, p.job?.until != nil { sawWorking = true }
                if case .travelling = p.place { sawTravelling = true }
            }
            if SimClock.timeString(f.world.clock.tick) == "21:00" {
                #expect(f.world.people.values.filter { $0.role.isStaff }.allSatisfy { $0.place == .outside })
            }
        }
        #expect(sawWorking && sawTravelling)
        #expect(f.world.facilities.cleaned > 0)
        #expect(f.world.facilities.jobs.count < openBefore + 10)
        let wages = f.world.ledger.journal.filter { $0.category == .wages }
        #expect(wages.last?.amount == -(2 * rules.facilities!.janitorWagePerDay + rules.facilities!.technicianWagePerDay))
        try f.world.validateIntegrity()
    }

    @Test func dismissingStaffFreesTheirJob() throws {
        var f = try SimFixture()
        let rules = f.library.simulationRules
        FacilitiesManagement.hire(.janitor, building: f.building, world: &f.world, rules: rules)
        #expect(FacilitiesManagement.staff(.janitor, in: f.world).count == 1)
        #expect(FacilitiesManagement.dismiss(.janitor, world: &f.world))
        #expect(FacilitiesManagement.staff(.janitor, in: f.world).isEmpty)
        #expect(!FacilitiesManagement.dismiss(.janitor, world: &f.world))
        try f.world.validateIntegrity()
    }

    /// Without technicians the plant room wears out and fails; tenants lose climate and
    /// water, their services score drops.
    @Test func neglectedEquipmentFails() throws {
        var f = try SimFixture()
        f.engine.advance(&f.world, by: 26 * 86_400)
        let plants = f.world.rooms.values.filter { $0.definitionID == "mechanical" }
        #expect(plants.allSatisfy { f.world.upkeep[$0.id]!.condition < f.library.simulationRules.facilities!.failureBelow })
        let office = try room(f, "office-small")
        let consultancy = try #require(f.library.simulationRules.tenantType("consultancy"))
        let a = try #require(Leasing.appraise(office, for: consultancy, world: f.world, engine: f.engine))
        #expect(a.services < 0.7)
    }
}

@Suite struct ServiceElevatorTests {
    /// A shaft marked serviceOnly is invisible to tenants' routes but usable by staff.
    @Test func onlyStaffUseServiceElevators() throws {
        var f = try SimFixture(elevator: false)
        let c = ConstructionEngine(catalog: f.library.buildCatalog)
        let x0 = f.world.buildings[f.building]!.footprint.start
        try c.apply(.placeRoom(building: f.building, definition: "service-elevator", columns: ColumnSpan(start: x0 + 16, count: 3),
                               floors: FloorSpan(lowest: -1, highest: 8)), to: &f.world)
        f.engine.replanAfterConstruction(&f.world)
        let building = f.world.buildings[f.building]!
        let street = try #require(RoutePlanner.street(of: building, rules: f.library.simulationRules))
        let target = Spot(floor: 8, x: Double(x0) + 24)
        let publicTrip = try #require(RoutePlanner.plan(from: street, to: target, building: building, world: f.world, navigation: f.engine.navigation,
                                                        catalog: f.library.buildCatalog, rules: f.library.simulationRules, now: 0, mode: .public))
        let staffTrip = try #require(RoutePlanner.plan(from: street, to: target, building: building, world: f.world, navigation: f.engine.navigation,
                                                       catalog: f.library.buildCatalog, rules: f.library.simulationRules, now: 0, mode: .staff))
        #expect(publicTrip.ride == nil)
        #expect(publicTrip.legs.contains { if case .stairs = $0 { true } else { false } })
        #expect(staffTrip.ride != nil)
    }
}

@Suite struct ServicesAppraisalTests {
    @Test func missingUtilitiesDeterProspects() throws {
        var f = try SimFixture()
        for t in f.world.tenants.values { Leasing.moveOut(t.id, world: &f.world) }
        let c = ConstructionEngine(catalog: f.library.buildCatalog)
        let electrical = try room(f, "electrical-room")
        try c.apply(.demolishRoom(electrical.id), to: &f.world)             // no power anywhere
        f.engine.advance(&f.world, by: 2 * 86_400)
        #expect(f.world.market.declines(.poorServices) > 0)
        #expect(f.world.tenants.count < 15)
    }
}
