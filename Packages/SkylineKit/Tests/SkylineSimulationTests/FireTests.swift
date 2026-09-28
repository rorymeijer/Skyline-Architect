import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// The demo tower during the working day, optionally with a fire control room on a new
/// floor 9 (its sprinklers cover ±15 floors).
struct FireFixture {
    var f: SimFixture
    let office: RoomID

    init(sprinklers: Bool) throws {
        f = try SimFixture()
        if sprinklers {
            let c = ConstructionEngine(catalog: f.library.buildCatalog)
            let b = f.world.buildings[f.building]!
            let span = b.plate(at: 8)!.span
            try c.apply(.buildFloor(building: f.building, level: 9, span: span), to: &f.world)
            try c.apply(.placeRoom(building: f.building, definition: "fire-control-room", columns: ColumnSpan(start: span.start, count: 4),
                                   floors: FloorSpan(lowest: 9, highest: 9)), to: &f.world)
            f.engine.replanAfterConstruction(&f.world)
        }
        f.run(until: "10:30")
        office = f.world.rooms.values.filter { $0.definitionID == "office-small" }.sorted { $0.floors.lowest < $1.floors.lowest }[2].id
    }

    var world: GameWorld { f.world }

    func inside() -> Int {
        f.count { p in
            guard p.buildingID == f.building else { return false }
            if case .outside = p.place { return false }
            return true
        }
    }

    /// Runs until the fire is out (at most 3 hours); returns its duration in minutes.
    mutating func burnOut() -> Tick {
        let start = f.world.clock.tick
        while !f.world.incidents.fires.isEmpty && f.world.clock.tick - start < 3 * 3600 { f.engine.advance(&f.world, by: 60) }
        return (f.world.clock.tick - start) / 60
    }
}

@Suite struct FireTests {
    @Test func everybodyLeavesByTheStairsAndNobodyGoesIn() throws {
        var x = try FireFixture(sprinklers: false)
        let before = x.inside()
        #expect(before > 20)
        let boardings = { (w: GameWorld) in w.elevators.values.reduce(0) { $0 + $1.stats.boardings } }
        #expect(x.f.engine.ignite(x.office, at: x.world.clock.tick, world: &x.f.world))
        #expect(x.world.incidents.isOnFire(x.f.building))
        x.f.engine.advance(&x.f.world, by: 120)
        let boarded = boardings(x.world)
        x.f.engine.advance(&x.f.world, by: 10 * 60)
        print("[fire] inside before \(before), after 12 min \(x.inside())")
        #expect(x.inside() == 0)
        #expect(boardings(x.world) == boarded)                     // no elevator rides during the fire
        try x.world.validateIntegrity()
    }

    @Test func aFireWithoutSprinklersBurnsUntilTheBrigadeAndCostsDearly() throws {
        var x = try FireFixture(sprinklers: false)
        let reputation = x.world.buildings[x.f.building]!.standing.reputation
        let cash = x.world.ledger.cash
        x.f.engine.ignite(x.office, at: x.world.clock.tick, world: &x.f.world)
        let minutes = x.burnOut()
        let incident = try #require(x.world.incidents.log.last)
        print("[fire] unprotected: \(minutes) min — \(incident.detail)")
        #expect(x.world.incidents.fires.isEmpty && incident.ended != nil)
        #expect(minutes >= 16)                                      // the brigade needs 16 minutes
        #expect(x.world.ledger.journal.contains { $0.detail.hasPrefix("Fire damage repairs") })
        #expect(x.world.ledger.cash < cash)
        #expect(x.world.buildings[x.f.building]!.standing.reputation <= reputation - 8 + 1e-9)
        #expect(incident.rooms.allSatisfy { r in x.world.facilities.jobs.contains { $0.room == r && $0.kind == .repair } })
        #expect(x.world.upkeep[x.office]!.condition < 0.8)
        // People come back: within an hour after the fire, the tower is busy again.
        x.f.engine.advance(&x.f.world, by: 3600)
        #expect(x.inside() > 5)
        try x.world.validateIntegrity()
    }

    @Test func sprinklersPutFiresOutSoonerWithLessDamage() throws {
        var bare = try FireFixture(sprinklers: false), protected = try FireFixture(sprinklers: true)
        bare.f.engine.ignite(bare.office, at: bare.world.clock.tick, world: &bare.f.world)
        protected.f.engine.ignite(protected.office, at: protected.world.clock.tick, world: &protected.f.world)
        let slow = bare.burnOut(), fast = protected.burnOut()
        print("[fire] unprotected \(slow) min, condition \(bare.world.upkeep[bare.office]!.condition); sprinklers \(fast) min, condition \(protected.world.upkeep[protected.office]!.condition)")
        #expect(fast < slow)
        #expect(protected.world.upkeep[protected.office]!.condition > bare.world.upkeep[bare.office]!.condition)
        #expect(FireSafety.protectedRooms(in: protected.f.building, world: protected.world, catalog: protected.f.library.buildCatalog,
                                          failureBelow: 0.15).contains(protected.office))
    }

    @Test func firesAreDeterministicAndBatchIndependent() throws {
        var a = try FireFixture(sprinklers: false), b = try FireFixture(sprinklers: false)
        a.f.engine.ignite(a.office, at: a.world.clock.tick, world: &a.f.world)
        b.f.engine.ignite(b.office, at: b.world.clock.tick, world: &b.f.world)
        a.f.engine.advance(&a.f.world, by: 3600)
        for _ in 0..<(3600 / 45) { b.f.engine.advance(&b.f.world, by: 45) }
        #expect(a.world == b.world)
    }

    @Test func wornRoomsAndPlantCatchFireMoreOften() throws {
        var x = try FireFixture(sprinklers: false)
        let office = x.world.rooms[x.office]!
        let plant = try #require(x.world.rooms.values.first { $0.definitionID == "electrical-room" })
        let base = try #require(x.f.engine.ignitionChancePerHour(office, world: x.world, protected: false))
        #expect(try #require(x.f.engine.ignitionChancePerHour(plant, world: x.world, protected: false)) == base * 3)
        #expect(try #require(x.f.engine.ignitionChancePerHour(office, world: x.world, protected: true)) == base * 0.5)
        x.f.world.upkeep.update(office.id) { $0.condition = 0.2 }
        #expect(try #require(x.f.engine.ignitionChancePerHour(office, world: x.world, protected: false)) == base * 4)
        let shaft = try #require(x.world.rooms.values.first { $0.definitionID == "stairs" })
        #expect(x.f.engine.ignitionChancePerHour(shaft, world: x.world, protected: false) == nil)
    }
}

@Suite struct WeatherIncidentTests {
    /// A stormy day damages the tower: incidents are logged, rooms lose condition and repair
    /// jobs are opened at once.
    @Test func stormsDamageTheBuilding() throws {
        var f = try SimFixture()
        for day in 0..<8 {                                              // a stormy week and a day
            f.world.setWeather(WeatherState(day: day, yesterday: "storm", today: "storm", tomorrow: "storm", temperature: 12), city: f.world.cities.values[0].id)
            f.engine.advance(&f.world, by: 86_400 - 60)
            f.engine.advance(&f.world, by: 60)
        }
        let damage = f.world.incidents.log.filter { $0.kind == "storm-damage" }
        print("[incidents] storm day: " + f.world.incidents.log.map(\.detail).joined(separator: "; "))
        #expect(!damage.isEmpty)
        for i in damage { #expect(f.world.facilities.jobs.contains { $0.room == i.rooms[0] } || f.world.facilities.repaired + f.world.facilities.cleaned > 0) }
        #expect(f.world.ledger.journal.contains { $0.detail == "Storm damage" })
        // Calm weather brings no incidents.
        var calm = try SimFixture()
        calm.world.setWeather(WeatherState(day: 0, yesterday: "clear", today: "clear", tomorrow: "clear", temperature: 20), city: calm.world.cities.values[0].id)
        calm.engine.advance(&calm.world, by: 22 * 3600)
        #expect(!calm.world.incidents.log.contains { $0.kind != "fire" })
    }

    /// A power outage fails the electrical plant: the tower loses power (and its lights)
    /// until a technician repairs it; the repair job is opened at once.
    @Test func powerOutagesFailThePlant() throws {
        var f = try SimFixture()
        let r = f.engine.rules
        var events = try #require(r.events)
        for i in events.incidents.indices { events.incidents[i].chancePerDay = events.incidents[i].id == "power-outage" ? 1 : 0 }
        let rules = SimulationRules(schedules: r.schedules, names: r.names, elevators: r.elevators, tenantTypes: r.tenantTypes,
                                    economy: r.economy, facilities: r.facilities, progression: r.progression, weather: r.weather, events: events)
        let engine = SimulationEngine(rules: rules, catalog: f.library.buildCatalog)
        f.world.setWeather(WeatherState(day: 0, yesterday: "heat", today: "heat", tomorrow: "heat", temperature: 34), city: f.world.cities.values[0].id)
        var hours = 0
        while !f.world.incidents.log.contains(where: { $0.kind == "power-outage" }) && hours < 22 {
            engine.advance(&f.world, by: 3600)
            hours += 1
        }
        let outage = try #require(f.world.incidents.log.first { $0.kind == "power-outage" })
        let plant = outage.rooms[0]
        #expect(f.world.rooms[plant]?.definitionID == "electrical-room")
        #expect(f.world.upkeep[plant]?.condition == 0)
        #expect(f.world.facilities.jobs.contains { $0.room == plant && $0.kind == .repair })
        let service = Utilities.allocate(building: f.building, world: f.world, catalog: f.library.buildCatalog, rules: rules)
        #expect(service.broken.contains(plant))
        #expect(Energy.lightingWatts(of: f.building, world: f.world, engine: engine) < 50)
    }
}

