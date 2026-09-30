import Foundation
import SkylineCore

/// A group of adjacent elevator shafts of the same type that share hall calls (Phase 7).
/// Derived from the building — never stored; its strategy lives on its cars.
public struct ElevatorBank: Equatable, Sendable {
    /// Lowest shaft id of the bank (stable while the bank's shafts exist).
    public var id: RoomID
    public var buildingID: BuildingID
    /// Shaft / car ids, left to right.
    public var cars: [RoomID]
    /// Room definition of the shafts (all equal).
    public var definitionID: String
    /// Floors where the bank's cars stop, ascending.
    public var served: [Int]
    public var strategy: DispatchStrategy
}

public enum ElevatorBanks {
    /// Banks of all buildings (or one), ordered by building then bank id. Shafts are in the
    /// same bank when they touch side by side, overlap in floors and share a room type.
    public static func banks(in world: GameWorld, rules: SimulationRules, building: BuildingID? = nil) -> [ElevatorBank] {
        let shafts = world.elevators.values
            .filter { building == nil || $0.buildingID == building }
            .compactMap { car -> (car: ElevatorCar, room: Room, spec: ElevatorSpec)? in
                guard let room = world.rooms[car.id], let spec = rules.elevator(for: room.definitionID) else { return nil }
                return (car, room, spec)
            }
            .sorted { $0.room.id < $1.room.id }
        // Union-find over touching shafts (deterministic: ids ascending).
        var parent = Array(shafts.indices)
        func root(_ i: Int) -> Int { parent[i] == i ? i : root(parent[i]) }
        for i in shafts.indices {
            for j in shafts.indices where j > i {
                let a = shafts[i].room, b = shafts[j].room
                guard a.buildingID == b.buildingID, a.definitionID == b.definitionID,
                      a.columns.end == b.columns.start || b.columns.end == a.columns.start,
                      a.floors.lowest <= b.floors.highest, b.floors.lowest <= a.floors.highest else { continue }
                let (ri, rj) = (root(i), root(j))
                if ri != rj { parent[max(ri, rj)] = min(ri, rj) }
            }
        }
        var groups: [Int: [Int]] = [:]
        for i in shafts.indices { groups[root(i), default: []].append(i) }
        return groups.keys.sorted().map { key in
            let members = groups[key]!.sorted { shafts[$0].room.columns.start < shafts[$1].room.columns.start }
            let first = shafts[groups[key]!.min()!]
            let served = Set(members.flatMap { shafts[$0].spec.servedFloors(of: shafts[$0].room.floors, skipping: shafts[$0].car.skippedFloors) }).sorted()
            return ElevatorBank(id: first.room.id, buildingID: first.room.buildingID, cars: members.map { shafts[$0].room.id },
                                definitionID: first.room.definitionID, served: served, strategy: first.car.strategy)
        }
        .sorted { ($0.buildingID, $0.id) < ($1.buildingID, $1.id) }
    }

    /// The bank a car belongs to.
    public static func bank(of car: RoomID, in world: GameWorld, rules: SimulationRules) -> ElevatorBank? {
        guard let b = world.elevators[car]?.buildingID else { return nil }
        return banks(in: world, rules: rules, building: b).first { $0.cars.contains(car) }
    }

    /// Sets the dispatch strategy of every car in a bank (a player setting, not construction).
    public static func setStrategy(_ strategy: DispatchStrategy, bank: RoomID, in world: inout GameWorld, rules: SimulationRules) {
        guard let members = self.bank(of: bank, in: world, rules: rules)?.cars else { return }
        for id in members { world.elevators.update(id) { $0.strategy = strategy } }
    }

    /// Statistics summed over a bank's cars.
    public static func stats(of bank: ElevatorBank, in world: GameWorld) -> CarStats {
        var total = CarStats()
        for car in bank.cars.compactMap({ world.elevators[$0] }) {
            total.boardings += car.stats.boardings
            total.totalWait += car.stats.totalWait
            total.maxWait = max(total.maxWait, car.stats.maxWait)
            total.abandoned += car.stats.abandoned
            total.stops += car.stats.stops
            if car.stats.day > total.day { total.day = car.stats.day; total.hourly = car.stats.hourly }
            else if car.stats.day == total.day { total.hourly = zip(total.hourly, car.stats.hourly).map(+) }
        }
        return total
    }
}

// MARK: - Call assignment

extension SimulationEngine {
    /// Banks of a building from the structure cache (Phase 19; same as `ElevatorBanks.banks`).
    func banks(of building: BuildingID, in world: GameWorld) -> [ElevatorBank] {
        guard let b = world.buildings[building] else { return [] }
        return navigation.banks(of: b, world: world, catalog: catalog, rules: rules)
    }

    /// The bank a car belongs to, from the structure cache.
    func bank(of car: RoomID, in world: GameWorld) -> ElevatorBank? {
        guard let b = world.elevators[car]?.buildingID else { return nil }
        return banks(of: b, in: world).first { $0.cars.contains(car) }
    }

    /// Chooses the car of the bank that serves a new hall call, according to the bank's
    /// strategy. Only cars stopping at both floors are eligible; ties go to the lower id.
    /// Returns the ride re-targeted to the chosen car's landing, marked as assigned.
    func assign(_ ride: Ride, world: GameWorld, now: Tick) -> Ride {
        var assigned = ride
        assigned.assigned = true
        guard let bank = bank(of: ride.shaft, in: world), bank.cars.count > 1 else { return assigned }
        let candidates = bank.cars.filter { id in
            guard let room = world.rooms[id], let spec = rules.elevator(for: room.definitionID),
                  world.elevators[id]?.isOutOfService != true else { return false }
            let served = spec.servedFloors(of: room.floors, skipping: world.elevators[id]?.skippedFloors)
            return served.contains(ride.fromFloor) && served.contains(ride.toFloor)
        }
        guard candidates.count > 1 else { return assigned }
        let queues = Dictionary(uniqueKeysWithValues: candidates.map { ($0, Self.queue(at: $0, in: world)) })
        func eta(_ id: RoomID) -> Double { estimatedArrival(of: id, at: ride.fromFloor, direction: ride.direction, queue: queues[id]!, world: world, now: now) }
        let best: RoomID
        switch bank.strategy {
        case .collective:
            best = candidates.min { (eta($0), $0) < (eta($1), $1) }!
        case .zoning:
            // Floors above the bank's main (lowest non-basement) floor are split into one
            // contiguous zone per car, left to right; a trip belongs to the zone of its
            // upper end. Trips not touching a zone use the fastest car.
            let main = bank.served.first { $0 >= 0 } ?? bank.served[0]
            let upper = bank.served.filter { $0 > main }
            let key = max(ride.fromFloor, ride.toFloor)
            if let index = upper.firstIndex(of: key), !upper.isEmpty {
                let zone = min(index * bank.cars.count / upper.count, bank.cars.count - 1)
                let owner = bank.cars[zone]
                best = candidates.contains(owner) ? owner : candidates.min { (eta($0), $0) < (eta($1), $1) }!
            } else {
                best = candidates.min { (eta($0), $0) < (eta($1), $1) }!
            }
        case .destination:
            // Join a car already taking people from this floor to the same floor (with room);
            // otherwise the fastest car, penalized per extra stop it would have to make.
            func companions(_ id: RoomID) -> Int {
                queues[id]!.filter { $0.ride.fromFloor == ride.fromFloor && $0.ride.toFloor == ride.toFloor }.count
            }
            func load(_ id: RoomID) -> Int { queues[id]!.filter { $0.ride.fromFloor == ride.fromFloor }.count }
            let capacity = world.rooms[ride.shaft].flatMap { rules.elevator(for: $0.definitionID)?.capacity } ?? 1
            let groups = candidates.filter { companions($0) > 0 && load($0) < capacity }
            if let group = groups.min(by: { (-companions($0), $0) < (-companions($1), $1) }) {
                best = group
            } else {
                func stops(_ id: RoomID) -> Int {
                    let riding = world.elevators[id]!.passengers.compactMap { p -> Int? in
                        if case let .riding(r, _)? = world.people[p]?.place { r.toFloor } else { nil }
                    }
                    return Set(riding + queues[id]!.map(\.ride.toFloor)).count
                }
                best = candidates.min { (eta($0) + 8 * Double(stops($0)), $0) < (eta($1) + 8 * Double(stops($1)), $1) }!
            }
        }
        guard best != ride.shaft, let room = world.rooms[best] else { return assigned }
        assigned.shaft = best
        assigned.x = NavigationGraph.elevatorLandingX(room, grid: world.grid)
        return assigned
    }

    /// Rough seconds until car `id` could pick up a call at `floor` going `direction`: travel
    /// along its current sweep plus a dwell per stop on the way, plus a penalty when full.
    func estimatedArrival(of id: RoomID, at floor: Int, direction: Int, queue: [(id: PersonID, ride: Ride)],
                          world: GameWorld, now: Tick) -> Double {
        guard let car = world.elevators[id], let room = world.rooms[id], let spec = rules.elevator(for: room.definitionID) else {
            return .infinity
        }
        let perFloor = world.grid.floorHeight / spec.speed
        let dwell = Double(2 * spec.doorSeconds + 2 * spec.transferSeconds)
        var position = car.floor
        var t = 0.0
        switch car.motion {
        case let .moving(_, to, _, end, _, _):
            position = to
            t += Double(end > now ? end - now : 0)
        case let .stopped(_, until):
            t += Double(until > now ? until - now : 0)
        case .idle:
            break
        }
        let stops = car.passengers.compactMap { p -> Int? in
            if case let .riding(r, _)? = world.people[p]?.place { r.toFloor } else { nil }
        } + queue.map(\.ride.fromFloor)
        let d = car.direction
        func ahead(_ f: Int) -> Bool { d > 0 ? f > position : f < position }
        if d == 0 || (d == direction && (floor == position || ahead(floor))) {
            let between = stops.filter { d != 0 && ahead($0) && (d > 0 ? $0 < floor : $0 > floor) }.count
            t += Double(abs(floor - position)) * perFloor + dwell * Double(between)
        } else {
            let extreme = stops.filter(ahead).max { d > 0 ? $0 < $1 : $0 > $1 } ?? position
            t += Double(abs(extreme - position) + abs(extreme - floor)) * perFloor + dwell * Double(stops.count)
        }
        if car.passengers.count + queue.count >= spec.capacity { t += 60 }
        return t
    }
}
