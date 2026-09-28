import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

@Suite struct LightingModelTests {
    let home = LightingSpec(color: "#FFC47E", occupied: 1, empty: 0, wattsPerModule: 7,
                            quietHours: .init(from: "22:30", to: "06:15", level: 0.06, spreadMinutes: 90))

    func at(_ h: Tick, _ m: Tick = 0) -> Tick { h * 3600 + m * 60 }

    @Test func occupancyAndQuietHoursSetTheLevel() {
        let room = RoomID(raw: 7)
        #expect(Lighting.level(home, room: room, occupied: true, secondOfDay: at(20)) == 1)
        #expect(Lighting.level(home, room: room, occupied: false, secondOfDay: at(20)) == 0)
        #expect(Lighting.level(home, room: room, occupied: true, secondOfDay: at(3)) == 0.06)    // asleep
        #expect(Lighting.level(home, room: room, occupied: true, secondOfDay: at(9)) == 1)       // quiet hours over
        #expect(Lighting.level(home, room: room, occupied: true, secondOfDay: at(20), power: 0.5) == 0.5)
        #expect(Lighting.level(home, room: room, occupied: true, secondOfDay: at(20), power: 0) == 0)
    }

    /// Homes do not all go dark at the same minute: each room starts its quiet hours up to
    /// 90 minutes after 22:30, stable per room.
    @Test func homesSwitchOffAtDifferentTimes() {
        func switchOff(_ raw: UInt32) -> Tick {
            let room = RoomID(raw: raw)
            return stride(from: at(22, 30), through: at(24), by: 60).first {
                Lighting.level(home, room: room, occupied: true, secondOfDay: $0 % 86_400) < 1
            } ?? .max
        }
        let times = (1...20).map(switchOff)
        #expect(times.allSatisfy { $0 >= at(22, 30) && $0 <= at(24) })
        #expect(Set(times).count > 10)
        #expect(times == (1...20).map(switchOff))                 // deterministic
    }

    @Test func baseContentLightsEveryRoomAndNoShaft() throws {
        let catalog = try ContentLibrary.loadBase().buildCatalog
        for spec in catalog.specs {
            #expect((spec.lighting != nil) == (spec.kind == .room), "\(spec.id)")
        }
    }
}

@Suite struct LightingEnergyTests {
    /// Evening homes use more light than the small hours; offices stand dark at night.
    @Test func loadFollowsTheDay() throws {
        var f = try SimFixture()
        f.run(until: "20:00")
        let evening = Energy.lightingWatts(of: f.building, world: f.world, engine: f.engine)
        f.run(until: "03:00", day: 1)
        let night = Energy.lightingWatts(of: f.building, world: f.world, engine: f.engine)
        f.run(until: "11:00", day: 1)
        let workday = Energy.lightingWatts(of: f.building, world: f.world, engine: f.engine)
        print("[lighting] demo tower load: 20:00 \(Int(evening)) W, 03:00 \(Int(night)) W, 11:00 \(Int(workday)) W")
        #expect(night < evening && night < workday)
        #expect(night > 0)                                        // lobbies, corridors, plant stay dimly lit
    }

    /// The meter runs hourly; the closing bills it as a traceable utilities line and resets it.
    @Test func closingBillsTheMeter() throws {
        var f = try SimFixture()
        f.run(until: "05:30", day: 1)
        let metered = f.world.buildings[f.building]!.lightingKWh
        #expect(metered > 0)
        f.run(until: "06:30", day: 1)
        let line = try #require(f.world.ledger.journal.last { $0.detail.hasPrefix("Lighting") })
        let price = try #require(f.engine.rules.economy?.lightingPricePerKWh)
        #expect(line.category == .utilities && line.building == f.building)
        #expect(line.amount < 0 && Double(-line.amount) >= metered * price - 1)
        #expect(f.world.buildings[f.building]!.lightingKWh < metered)     // reset at 06:00, one hour metered since
        print("[lighting] demo tower day: \(Int(metered)) kWh by 05:30 → \(line.detail), \(line.amount)")
    }

    /// Without power the lights are out: demolishing the electrical room darkens every room
    /// that draws electricity. (Plant rooms have no electricity demand in the content, so
    /// their dim 15 % stays on — reads as emergency lighting.)
    @Test func noPowerNoLight() throws {
        var f = try SimFixture()
        f.run(until: "20:00")
        let before = Energy.lightingWatts(of: f.building, world: f.world, engine: f.engine)
        let plant = try #require(f.world.rooms.values.first { $0.definitionID == "electrical-room" })
        try ConstructionEngine(catalog: f.library.buildCatalog).apply(.demolishRoom(plant.id), to: &f.world)
        let after = Energy.lightingWatts(of: f.building, world: f.world, engine: f.engine)
        #expect(after < before * 0.02)
        let service = Utilities.allocate(building: f.building, world: f.world, catalog: f.library.buildCatalog, rules: f.engine.rules)
        for room in f.world.rooms.values where f.library.buildCatalog.spec(room.definitionID)?.utilityDemand?["electricity"] != nil {
            #expect(service.served[room.id]?["electricity"] == 0)
        }
    }

    /// Metering happens at market events, so it is independent of the step size.
    @Test func meteringIsBatchIndependent() throws {
        var a = try SimFixture(), b = try SimFixture()
        a.engine.advance(&a.world, by: 20 * 3600)
        for _ in 0..<(20 * 3600 / 450) { b.engine.advance(&b.world, by: 450) }
        #expect(a.world.buildings[a.building]!.lightingKWh == b.world.buildings[b.building]!.lightingKWh)
        #expect(a.world == b.world)
    }
}
