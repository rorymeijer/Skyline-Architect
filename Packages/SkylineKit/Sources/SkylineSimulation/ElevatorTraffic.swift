import Foundation
import SkylineCore

/// Player-facing elevator traffic view (Phase 7): who is waiting where and for how long,
/// how full each car is, and each bank's statistics. Pure data for the app's overlay and
/// bank panel; nothing here affects the simulation.
public struct ElevatorTraffic: Equatable, Sendable {
    public struct Queue: Equatable, Sendable {
        /// Landing (world meters, floor level) of the car the people wait for.
        public var position: Vec2
        public var count: Int
        public var longestWait: Tick
    }

    public struct Car: Equatable, Sendable {
        /// Top centre of the cab (world meters).
        public var position: Vec2
        public var load: Int
        public var capacity: Int
    }

    public struct Bank: Equatable, Sendable, Identifiable {
        public var id: RoomID
        /// "A", "B", … in bank order within the building.
        public var name: String
        public var kind: String
        public var floors: String
        public var cars: Int
        public var strategy: DispatchStrategy
        public var stats: CarStats
        public var passengersLastHour: Int
        public var waitingNow: Int
        /// Label anchor above the bank (world meters).
        public var position: Vec2
    }

    public var queues: [Queue] = []
    public var cars: [Car] = []
    public var banks: [Bank] = []

    public init() {}

    /// Bank letters: A…Z, then AA, AB, …
    static func name(_ i: Int) -> String {
        let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        return i < 26 ? String(letters[i]) : name(i / 26 - 1) + String(letters[i % 26])
    }

    public static func make(world: GameWorld, rules: SimulationRules, buildings: [BuildingID], now: Tick) -> ElevatorTraffic {
        let grid = world.grid
        var traffic = ElevatorTraffic()
        var waiting: [RoomID: [Int: (count: Int, longest: Tick, x: Double)]] = [:]
        for p in world.people {
            guard case let .waiting(ride, _, since) = p.place else { continue }
            var entry = waiting[ride.shaft]?[ride.fromFloor] ?? (0, 0, ride.x)
            entry.count += 1
            entry.longest = max(entry.longest, now - since)
            waiting[ride.shaft, default: [:]][ride.fromFloor] = entry
        }
        for building in buildings {
            for (i, bank) in ElevatorBanks.banks(in: world, rules: rules, building: building).enumerated() {
                var top = -Double.infinity, minX = Double.infinity, maxX = -Double.infinity
                var waitingNow = 0
                var kind = ""
                for id in bank.cars {
                    guard let car = world.elevators[id], let room = world.rooms[id], let spec = rules.elevator(for: room.definitionID) else { continue }
                    kind = spec.name
                    let x0 = grid.x(ofColumn: room.columns.start), x1 = grid.x(ofColumn: room.columns.end)
                    minX = min(minX, x0)
                    maxX = max(maxX, x1)
                    top = max(top, grid.y(ofFloor: room.floors.highest + 1))
                    let y = ElevatorMotion.y(of: car, at: Double(now), grid: grid)
                    traffic.cars.append(Car(position: Vec2((x0 + x1) / 2, y + 2.6), load: car.passengers.count, capacity: spec.capacity))
                    for floor in (waiting[id]?.keys.sorted() ?? []) {
                        let q = waiting[id]![floor]!
                        waitingNow += q.count
                        traffic.queues.append(Queue(position: Vec2(q.x, grid.y(ofFloor: floor)), count: q.count, longestWait: q.longest))
                    }
                }
                let stats = ElevatorBanks.stats(of: bank, in: world)
                let floors = "\(FloorLabel.label(for: bank.served.first ?? 0))–\(FloorLabel.label(for: bank.served.last ?? 0))"
                traffic.banks.append(Bank(id: bank.id, name: name(i), kind: kind, floors: bank.served.count == 2 && bank.served[1] - bank.served[0] > 1
                                            ? "\(FloorLabel.label(for: bank.served[0])) ↔ \(FloorLabel.label(for: bank.served[1]))" : floors,
                                          cars: bank.cars.count, strategy: bank.strategy, stats: stats,
                                          passengersLastHour: stats.passengersLastHour(at: now), waitingNow: waitingNow,
                                          position: Vec2((minX + maxX) / 2, top + 0.6)))
            }
        }
        return traffic
    }
}
