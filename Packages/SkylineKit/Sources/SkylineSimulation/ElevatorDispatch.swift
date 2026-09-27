import Foundation
import SkylineCore

/// Keeps exactly one car per elevator shaft (a room whose spec has `transport: "elevator"`
/// and an `elevators.json` entry).
enum ElevatorSync {
    static func shafts(_ world: GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> [Room] {
        world.rooms.values.filter { room in
            catalog.spec(room.definitionID)?.transport == "elevator" && rules.elevator(for: room.definitionID) != nil
        }
    }

    static func isInSync(_ world: GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> Bool {
        let ids = shafts(world, catalog: catalog, rules: rules).map(\.id)
        return ids.count == world.elevators.count && ids.allSatisfy { world.elevators.contains($0) }
    }

    /// Adds cars for new shafts (parked at the ground floor, or the served floor nearest to
    /// it) and removes cars whose shaft is gone. Riders of a removed car are put in the
    /// queue at the floor the car was nearest to, where re-planning picks them up.
    static func sync(_ world: inout GameWorld, catalog: BuildCatalog, rules: SimulationRules) {
        let shafts = shafts(world, catalog: catalog, rules: rules)
        let valid = Set(shafts.map(\.id))
        let now = world.clock.tick
        for car in world.elevators.values where !valid.contains(car.id) {
            let floor = Int((ElevatorMotion.y(of: car, at: Double(now), grid: world.grid) / world.grid.floorHeight).rounded())
            for id in car.passengers {
                world.people.update(id) { p in
                    guard case let .riding(ride, destination) = p.place else { return }
                    var here = ride
                    here.fromFloor = floor
                    p.place = .waiting(here, destination: destination, since: now)
                }
            }
            world.elevators.remove(car.id)
        }
        for shaft in shafts where !world.elevators.contains(shaft.id) {
            let floor = min(max(0, shaft.floors.lowest), shaft.floors.highest)
            world.elevators.insert(ElevatorCar(id: shaft.id, buildingID: shaft.buildingID, floor: floor))
        }
    }
}

// MARK: - Collective control

extension SimulationEngine {
    /// A call arrived: an idle car starts deciding now.
    func wakeCar(_ id: RoomID, at now: Tick, world: inout GameWorld, events: inout Events) {
        guard let car = world.elevators[id], car.motion == .idle, car.nextEventTick > now else { return }
        world.elevators.update(id) { $0.nextEventTick = now }
        events.push(now, .car(id))
    }

    /// People queuing for a shaft, in queue order (since, id).
    static func queue(at shaft: RoomID, in world: GameWorld) -> [(id: PersonID, ride: Ride)] {
        world.people.values.compactMap { p -> (Tick, PersonID, Ride)? in
            guard case let .waiting(ride, _, since) = p.place, ride.shaft == shaft else { return nil }
            return (since, p.id, ride)
        }
        .sorted { ($0.0, $0.1) < ($1.0, $1.1) }
        .map { (id: $0.1, ride: $0.2) }
    }

    /// A car event: it arrived at a floor, its doors finished closing, or a call woke it.
    ///
    /// Collective control: a car keeps its direction while it has passengers or calls ahead;
    /// at a floor it lets out everyone for that floor and takes waiting people travelling in
    /// its direction (queue order, up to capacity); it stops at passengers' floors, at calls
    /// in its direction and at the farthest call (where it turns). Calls made while a car is
    /// moving are considered at its next stop (Phase 7 refines this).
    func handleCar(_ id: RoomID, at now: Tick, world: inout GameWorld, events: inout Events, report: inout SimulationReport) {
        guard var car = world.elevators[id], let shaft = world.rooms[id], let spec = rules.elevator(for: shaft.definitionID),
              let building = world.buildings[car.buildingID] else { return }
        if case let .moving(_, to, _, _, _, _) = car.motion { car.floor = to }
        car.motion = .idle
        let f = car.floor
        let queue = Self.queue(at: id, in: world)
        func ride(_ p: PersonID) -> Ride? {
            if case let .riding(r, _)? = world.people[p]?.place { r } else { nil }
        }
        let alighting = car.passengers.filter { ride($0)?.toFloor == f }
        let staying = car.passengers.filter { ride($0)?.toFloor != f }
        let destinations = staying.compactMap { ride($0)?.toFloor }
        let here = queue.filter { $0.ride.fromFloor == f }
        func ahead(_ floor: Int, _ d: Int) -> Bool { d > 0 ? floor > f : floor < f }
        func hasWork(_ d: Int) -> Bool {
            destinations.contains { ahead($0, d) } || queue.contains { ahead($0.ride.fromFloor, d) }
        }
        let calls = destinations + queue.map(\.ride.fromFloor)
        var direction = car.direction
        if direction != 0, !hasWork(direction), !here.contains(where: { $0.ride.direction == direction }) { direction = 0 }
        if direction == 0 {
            if let first = here.first {
                direction = first.ride.direction
            } else if let nearest = calls.filter({ $0 != f }).min(by: { (abs($0 - f), $0) < (abs($1 - f), $1) }) {
                direction = nearest > f ? 1 : -1
            }
        }
        let free = max(spec.capacity - staying.count, 0)
        let boarding = direction == 0 ? [] : Array(here.filter { $0.ride.direction == direction }.prefix(free))
        car.direction = direction

        if !alighting.isEmpty || !boarding.isEmpty {
            // Doors open, people get out, people get in, doors close.
            let dwell = 2 * spec.doorSeconds + spec.transferSeconds * Tick(alighting.count + boarding.count)
            car.motion = .stopped(since: now, until: now + dwell)
            car.nextEventTick = now + dwell
            for (i, pid) in alighting.enumerated() {
                guard var p = world.people[pid], case let .riding(r, destination) = p.place else { continue }
                let out = now + spec.doorSeconds + spec.transferSeconds * Tick(i + 1)
                if !startTrip(&p, from: Spot(floor: f, x: r.x), to: destination, building: building, world: world, now: out) {
                    strand(&p, at: out)
                    report.unreachable += 1
                }
                world.people.update(pid) { $0 = p }
                events.push(p.nextEventTick, .person(pid))
            }
            for entry in boarding {
                world.people.update(entry.id) { p in
                    if case let .waiting(r, destination, _) = p.place { p.place = .riding(r, destination: destination) }
                }
            }
            car.passengers = staying + boarding.map(\.id)
        } else if let next = nextStop(from: f, direction: direction, destinations: destinations, queue: queue) ?? calls
            .filter({ $0 != f }).min(by: { (abs($0 - f), $0) < (abs($1 - f), $1) }) {
            let ticks = ElevatorMotion.ticks(floors: next - f, grid: world.grid, speed: spec.speed, acceleration: spec.acceleration)
            car.direction = next > f ? 1 : -1
            car.motion = .moving(fromFloor: f, toFloor: next, start: now, end: now + ticks, speed: spec.speed,
                                 acceleration: spec.acceleration)
            car.nextEventTick = now + ticks
        } else {
            car.direction = 0
            car.nextEventTick = .max
        }
        world.elevators.update(id) { $0 = car }
        events.push(car.nextEventTick, .car(id))
    }

    /// Nearest floor ahead in `direction` that is a passenger's floor, a call in that
    /// direction, or the farthest call ahead (the turning point).
    private func nextStop(from f: Int, direction d: Int, destinations: [Int], queue: [(id: PersonID, ride: Ride)]) -> Int? {
        guard d != 0 else { return nil }
        func ahead(_ floor: Int) -> Bool { d > 0 ? floor > f : floor < f }
        var stops = destinations.filter(ahead)
        let callsAhead = queue.filter { ahead($0.ride.fromFloor) }
        stops += callsAhead.filter { $0.ride.direction == d }.map(\.ride.fromFloor)
        if let farthest = callsAhead.map(\.ride.fromFloor).max(by: { d > 0 ? $0 < $1 : $0 > $1 }) { stops.append(farthest) }
        return stops.min { (abs($0 - f), $0) < (abs($1 - f), $1) }
    }
}
