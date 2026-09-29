import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// Elevator wear and breakdowns (Phase E).
@Suite struct ElevatorWearTests {
    func shaft(_ f: SimFixture) -> RoomID { f.world.rooms.values.first { $0.definitionID == "elevator-shaft" }!.id }

    func riders(of car: RoomID, in world: GameWorld) -> Int {
        world.people.values.filter { p in
            switch p.place {
            case let .waiting(r, _, _), let .riding(r, _): r.shaft == car
            case .travelling: p.pendingRide?.shaft == car
            default: false
            }
        }.count
    }

    /// Every stop wears the shaft; below the equipment threshold a repair job opens.
    @Test func stopsWearTheShaft() throws {
        var f = try SimFixture()
        let car = shaft(f)
        f.run(until: "09:30")
        let condition = try #require(f.world.upkeep[car]?.condition)
        let stops = try #require(f.world.elevators[car]?.stats.stops)
        #expect(stops > 0 && abs(condition - (1 - Double(stops) * 0.0012)) < 1e-9)
        f.world.upkeep.update(car) { $0.condition = 0.51 }
        f.run(until: "12:30")
        #expect(f.world.facilities.jobs.contains { $0.room == car && $0.kind == .repair })
    }

    /// A worn-out car breaks down: it stands, nobody waits for or rides it, the others go
    /// by stairs; a technician repairs it and it runs again.
    @Test func wornCarsBreakDownAndAreRepaired() throws {
        var f = try SimFixture()
        let car = shaft(f)
        f.world.upkeep.update(car) { $0.condition = 0.05 }
        f.run(until: "07:00")
        var guardSteps = 0
        while f.world.elevators[car]?.isOutOfService != true && guardSteps < 240 {
            f.engine.advance(&f.world, by: 60)
            guardSteps += 1
        }
        #expect(f.world.elevators[car]?.isOutOfService == true && f.world.facilities.breakdowns == 1)
        #expect(f.world.elevators[car]?.passengers.isEmpty == true)
        f.engine.advance(&f.world, by: 60)
        #expect(riders(of: car, in: f.world) == 0)
        try f.world.validateIntegrity()
        // Everyone still gets to work by the stairs.
        f.run(until: "10:30")
        #expect(f.count { $0.role == .worker && f.inAnchorRoom($0) } >= 20)
        // A technician fixes it first thing on their shift.
        FacilitiesManagement.hire(.technician, building: f.building, world: &f.world, rules: f.engine.rules)
        f.run(until: "08:30", day: 1)
        #expect(f.world.elevators[car]?.isOutOfService != true && (f.world.upkeep[car]?.condition ?? 0) > 0.8
                && !f.world.facilities.jobs.contains { $0.room == car })   // repaired, some stops since
        f.run(until: "12:00", day: 1)
        #expect((f.world.elevators[car]?.stats.stops ?? 0) > 0)
    }

    /// Breakdowns are deterministic: same result however the ticks are batched.
    @Test func breakdownsAreDeterministic() throws {
        var a = try SimFixture(), b = try SimFixture()
        a.world.upkeep.update(shaft(a)) { $0.condition = 0.1 }
        b.world.upkeep.update(shaft(b)) { $0.condition = 0.1 }
        a.engine.advance(&a.world, by: 4 * 3600)
        for _ in 0..<(4 * 3600 / 733) { b.engine.advance(&b.world, by: 733) }
        b.engine.advance(&b.world, by: a.world.clock.tick - b.world.clock.tick)
        #expect(a.world == b.world)
    }
}
