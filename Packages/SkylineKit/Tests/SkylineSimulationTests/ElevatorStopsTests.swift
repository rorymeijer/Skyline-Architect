import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

/// Floors switched off per elevator (0.30): routes, banks and the car respect them.
@Suite struct ElevatorStopsTests {
    func shaft(_ f: SimFixture) throws -> Room {
        try #require(f.world.rooms.values.first { $0.definitionID == "elevator-shaft" })
    }

    func trip(_ f: SimFixture, to floor: Int) throws -> RoutePlanner.Trip {
        let building = f.world.buildings[f.building]!
        let street = try #require(RoutePlanner.street(of: building, rules: f.library.simulationRules))
        return try #require(RoutePlanner.plan(from: street, to: Spot(floor: floor, x: Double(building.footprint.start) + 3), building: building,
                                              world: f.world, navigation: f.engine.navigation, catalog: f.library.buildCatalog,
                                              rules: f.library.simulationRules, now: 0))
    }

    @Test func aSwitchedOffFloorIsPassed() throws {
        var f = try SimFixture()
        let s = try shaft(f), rules = f.library.simulationRules
        let before = try trip(f, to: 8).ride?.toFloor
        #expect(before == 8)
        try ElevatorStops.set(8, served: false, shaft: s.id, world: &f.world, rules: rules)
        #expect(f.world.elevators[s.id]?.skippedFloors == [8])
        f.engine.replanAfterConstruction(&f.world)            // as the next simulation step does
        #expect(!ElevatorStops.served(s, world: f.world, rules: rules).contains(8))
        // The route rides to a neighbouring floor and takes the stairs from there.
        let skippedTrip = try trip(f, to: 8)
        let ride = try #require(skippedTrip.ride)
        #expect(ride.toFloor != 8)
        #expect(ElevatorBanks.banks(in: f.world, rules: rules).first { $0.cars.contains(s.id) }?.served.contains(8) == false)
        try ElevatorStops.set(8, served: true, shaft: s.id, world: &f.world, rules: rules)
        f.engine.replanAfterConstruction(&f.world)
        let back = try trip(f, to: 8).ride?.toFloor
        #expect(f.world.elevators[s.id]?.skippedFloors == nil && back == 8)
    }

    @Test func atLeastTwoFloorsStayOnAndOnlyStopsCanBeSwitched() throws {
        var f = try SimFixture()
        let s = try shaft(f), rules = f.library.simulationRules
        #expect(throws: ElevatorStops.StopError.notAStop) {
            try ElevatorStops.set(s.floors.highest + 1, served: false, shaft: s.id, world: &f.world, rules: rules)
        }
        let floors = Array(s.floors.lowest...s.floors.highest)
        for floor in floors.dropFirst(2) { try ElevatorStops.set(floor, served: false, shaft: s.id, world: &f.world, rules: rules) }
        #expect(ElevatorStops.served(s, world: f.world, rules: rules) == Array(floors.prefix(2)))
        #expect(throws: ElevatorStops.StopError.tooFew) {
            try ElevatorStops.set(floors[0], served: false, shaft: s.id, world: &f.world, rules: rules)
        }
    }

    /// A day with floors switched off: nobody gets out of the car at one of them, and the
    /// world stays consistent.
    @Test func aDayWithSkippedFloorsRunsCleanly() throws {
        var f = try SimFixture()
        let s = try shaft(f), rules = f.library.simulationRules
        for floor in [3, 5] { try ElevatorStops.set(floor, served: false, shaft: s.id, world: &f.world, rules: rules) }
        for _ in 0..<(SimClock.secondsPerDay / 60) {
            f.engine.advance(&f.world, by: 60)
            for p in f.world.people.values {
                if case let .waiting(ride, _, _) = p.place, ride.shaft == s.id { #expect(![3, 5].contains(ride.fromFloor)) }
                if case let .riding(ride, _) = p.place, ride.shaft == s.id { #expect(![3, 5].contains(ride.toFloor)) }
            }
        }
        try f.world.validateIntegrity(isShaft: { f.library.buildCatalog.spec($0)?.kind == .shaft })
    }
}
