import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// The `demo-skytower` blueprint: low bank (3 cars, B1–20), express G→21, upper bank
/// (2 cars, 21–40), stairs over the full height, offices on every floor.
struct SkyFixture {
    var world: GameWorld
    let library: ContentLibrary
    let engine: SimulationEngine
    let building: BuildingID

    init(strategy: DispatchStrategy = .collective, rules override: ((SimulationRules) -> SimulationRules)? = nil) throws {
        library = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: library)
        let b = game.world.buildings(on: game.activePropertyID).first!
        let construction = ConstructionEngine(catalog: library.buildCatalog)
        for c in try #require(library.blueprint("demo-skytower")).commands(for: b) { try construction.apply(c, to: &game.world) }
        world = game.world
        building = b.id
        let rules = override?(library.simulationRules) ?? library.simulationRules
        engine = SimulationEngine(rules: rules, catalog: library.buildCatalog)
        PopulationSync.sync(&world, catalog: library.buildCatalog, rules: rules)
        engine.replanAfterConstruction(&world)
        for bank in ElevatorBanks.banks(in: world, rules: rules) {
            ElevatorBanks.setStrategy(strategy, bank: bank.id, in: &world, rules: rules)
        }
    }

    var banks: [ElevatorBank] { ElevatorBanks.banks(in: world, rules: engine.rules) }

    func count(_ f: (Person) -> Bool) -> Int { world.people.values.filter(f).count }

    func atWork() -> Int {
        count { p in if case let .room(r, _) = p.place { return r == p.workRoom } else { return false } }
    }

    /// Runs the morning 06:00 → `until` in 10 s steps, checking invariants.
    mutating func morning(until hour: Tick = 11) throws -> (maxLoad: Int, carsUsed: Set<RoomID>) {
        var maxLoad = 0
        var used = Set<RoomID>()
        while SimClock.secondOfDay(world.clock.tick) < hour * 3600 {
            engine.advance(&world, by: 10)
            for car in world.elevators {
                maxLoad = max(maxLoad, car.passengers.count)
                if !car.passengers.isEmpty { used.insert(car.id) }
                if case .stopped = car.motion, let room = world.rooms[car.id],
                   let spec = engine.rules.elevator(for: room.definitionID) {
                    #expect(spec.servedFloors(of: room.floors).contains(car.floor))
                }
            }
        }
        try world.validateIntegrity()
        return (maxLoad, used)
    }
}

@Suite struct BankDetectionTests {
    @Test func adjacentShaftsFormBanks() throws {
        let f = try SkyFixture()
        let banks = f.banks
        #expect(banks.map(\.cars.count) == [3, 1, 2])
        #expect(banks[0].served == Array(-1...20))
        #expect(banks[1].definitionID == "elevator-express" && banks[1].served == [0, 21])
        #expect(banks[2].served == Array(21...40))
    }

    @Test func strategyAppliesToTheWholeBankAndNewShaftsAdoptIt() throws {
        var f = try SkyFixture()
        let low = f.banks[0]
        ElevatorBanks.setStrategy(.zoning, bank: low.id, in: &f.world, rules: f.engine.rules)
        #expect(low.cars.allSatisfy { f.world.elevators[$0]!.strategy == .zoning })
        #expect(f.world.elevators[f.banks[2].cars[0]]!.strategy == .collective)
        // Remove the rightmost car of the low bank and put it back: it adopts zoning.
        let c = ConstructionEngine(catalog: f.library.buildCatalog)
        let last = low.cars.last!
        let room = f.world.rooms[last]!
        try c.apply(.demolishRoom(last), to: &f.world)
        f.engine.replanAfterConstruction(&f.world)
        try c.apply(.placeRoom(building: f.building, definition: room.definitionID, columns: room.columns, floors: room.floors), to: &f.world)
        f.engine.replanAfterConstruction(&f.world)
        #expect(f.banks[0].cars.count == 3)
        #expect(f.banks[0].cars.allSatisfy { f.world.elevators[$0]!.strategy == .zoning })
    }
}

@Suite struct DispatchStrategyTests {
    /// Every strategy gets everyone to work, never overloads a car, stops only at served
    /// floors and uses every car of the banks. Average waits are printed for PERFORMANCE.md.
    @Test(arguments: DispatchStrategy.allCases)
    func strategiesServeTheMorning(_ strategy: DispatchStrategy) throws {
        var f = try SkyFixture(strategy: strategy)
        let workers = f.count { $0.role == .worker }
        let (maxLoad, used) = try f.morning()
        #expect(f.atWork() == workers)
        #expect(maxLoad <= 20)
        let low = f.banks[0], high = f.banks[2]
        #expect(Set(low.cars).isSubset(of: used) && Set(high.cars).isSubset(of: used))
        let stats = f.banks.map { ElevatorBanks.stats(of: $0, in: f.world) }
        print("[strategy \(strategy.rawValue)] workers=\(workers) " + zip(f.banks, stats).map { bank, s in
            "bank\(bank.id.raw): \(s.boardings) boardings, avg \(String(format: "%.0f", s.averageWait)) s, max \(s.maxWait) s, abandoned \(s.abandoned)"
        }.joined(separator: " | "))
        #expect(stats.allSatisfy { $0.boardings > 0 && Double($0.maxWait) >= $0.averageWait })
    }

    @Test func upperFloorsTransferAtTheSkyLobby() throws {
        let f = try SkyFixture()
        let building = f.world.buildings[f.building]!
        let street = try #require(RoutePlanner.street(of: building, rules: f.engine.rules))
        let trip = try #require(RoutePlanner.plan(from: street, to: Spot(floor: 30, x: Double(building.footprint.start) + 12),
                                                  building: building, world: f.world, navigation: f.engine.navigation,
                                                  catalog: f.library.buildCatalog, rules: f.engine.rules, now: 0))
        #expect(trip.ride?.shaft == f.banks[1].cars[0])        // express first
        #expect(trip.ride?.toFloor == 21)
    }

    /// Zoning: in the morning up-peak each low-bank car carries people to its own zone only.
    @Test func zoningKeepsCarsInTheirZones() throws {
        var f = try SkyFixture(strategy: .zoning)
        let low = f.banks[0]
        var destinations: [RoomID: Set<Int>] = [:]
        while SimClock.secondOfDay(f.world.clock.tick) < 10 * 3600 {
            f.engine.advance(&f.world, by: 10)
            for id in low.cars {
                for p in f.world.elevators[id]!.passengers {
                    if case let .riding(r, _)? = f.world.people[p]?.place, r.fromFloor == 0, r.toFloor > 0 {
                        destinations[id, default: []].insert(r.toFloor)
                    }
                }
            }
        }
        let ranges = low.cars.map { destinations[$0] ?? [] }
        #expect(ranges.allSatisfy { !$0.isEmpty })
        for (a, b) in zip(ranges, ranges.dropFirst()) { #expect(a.max()! < b.min()!) }
    }

    /// Destination dispatch groups people: in a sharp up-peak (everyone arrives 08:15 ± 5
    /// min) the low bank makes fewer stops per passenger than with collective control.
    @Test func destinationDispatchGroupsPassengersInAPeak() throws {
        func sharpPeak(_ rules: SimulationRules) -> SimulationRules {
            SimulationRules(schedules: rules.schedules.map { schedule in
                var s = schedule
                if s.role == .worker { s.events[0].jitterMinutes = 5 }
                return s
            }, names: rules.names, elevators: rules.elevators)
        }
        func stopsPerBoarding(_ strategy: DispatchStrategy) throws -> (Double, CarStats) {
            var f = try SkyFixture(strategy: strategy, rules: sharpPeak)
            _ = try f.morning(until: 10)
            let s = ElevatorBanks.stats(of: f.banks[0], in: f.world)
            return (Double(s.stops) / Double(max(s.boardings, 1)), s)
        }
        let (collective, c) = try stopsPerBoarding(.collective), (destination, d) = try stopsPerBoarding(.destination)
        print("[grouping] low bank, sharp peak: collective \(c.stops) stops / \(c.boardings) boardings, avg wait \(Int(c.averageWait)) s; " +
              "destination \(d.stops) stops / \(d.boardings) boardings, avg wait \(Int(d.averageWait)) s")
        #expect(destination < collective)
    }
}

@Suite struct PatienceTests {
    /// With very little patience, people waiting for a nearby floor give up and take the
    /// stairs; the abandonment is counted and they still arrive.
    @Test func impatientPeopleTakeTheStairs() throws {
        var f = try SkyFixture { rules in
            SimulationRules(schedules: rules.schedules, names: rules.names, elevators: rules.elevators.map { spec in
                var s = spec
                s.patienceSeconds = 10
                return s
            })
        }
        let workers = f.count { $0.role == .worker }
        _ = try f.morning()
        let abandoned = f.banks.map { ElevatorBanks.stats(of: $0, in: f.world).abandoned }.reduce(0, +)
        #expect(abandoned > 0)
        #expect(f.atWork() == workers)
    }

    @Test func patienceIsPersonalAndBounded() throws {
        let spec = try ContentLibrary.loadBase().simulationRules.elevators[0]
        let values = (0..<200).map { spec.patience(traits: UInt32($0) &* 2_654_435_761) }
        #expect(values.allSatisfy { $0 >= 75 && $0 <= 225 })
        #expect(Set(values).count > 50)
    }
}

@Suite struct CarStatsTests {
    @Test func boardingsAndHourlyCounts() {
        var s = CarStats()
        s.recordBoarding(waited: 10, at: 3 * 3600 + 5)          // 09:00 day 0
        s.recordBoarding(waited: 30, at: 3 * 3600 + 900)
        s.recordBoarding(waited: 20, at: 4 * 3600 + 10)         // 10:00
        #expect(s.boardings == 3 && s.maxWait == 30 && s.averageWait == 20)
        #expect(s.passengersLastHour(at: 4 * 3600 + 20) == 2)
        s.recordBoarding(waited: 5, at: 86_400 + 60)            // next day resets the hours
        #expect(s.hourly.reduce(0, +) == 1)
        #expect(s.boardings == 4)
    }
}

@Suite struct ElevatorTrafficTests {
    @Test func trafficSummarizesQueuesCarsAndBanks() throws {
        var f = try SkyFixture()
        var traffic = ElevatorTraffic()
        while SimClock.secondOfDay(f.world.clock.tick) < 10 * 3600 {
            f.engine.advance(&f.world, by: 5)
            traffic = ElevatorTraffic.make(world: f.world, rules: f.engine.rules, buildings: [f.building], now: f.world.clock.tick)
            if traffic.queues.count >= 2 { break }
        }
        let waiting = f.count { if case .waiting = $0.place { true } else { false } }
        #expect(traffic.queues.map(\.count).reduce(0, +) == waiting)
        #expect(traffic.cars.count == 6)
        #expect(traffic.banks.map(\.name) == ["A", "B", "C"])
        #expect(traffic.banks[1].floors == "G ↔ 21")
        #expect(traffic.banks.map(\.waitingNow).reduce(0, +) == waiting)
        #expect(ElevatorTraffic.name(27) == "AB")
    }
}
