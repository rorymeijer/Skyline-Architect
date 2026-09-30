import Foundation
import SkylineCore

/// Floors an elevator stops at (0.30): the player may switch floors off per car, as on the
/// classic tower games' elevator panels. A switched-off floor keeps its landing doors but
/// the car passes it; the navigation graph, banks and dispatch all read the same list.
public enum ElevatorStops {
    public enum StopError: Error, Equatable, CustomStringConvertible {
        case notAnElevator
        case notAStop
        case tooFew

        public var description: String {
            switch self {
            case .notAnElevator: "Not an elevator"
            case .notAStop: "The car cannot stop at that floor"
            case .tooFew: "An elevator needs at least two floors to stop at"
            }
        }
    }

    /// Floors where `shaft`'s car stops now.
    public static func served(_ shaft: Room, world: GameWorld, rules: SimulationRules) -> [Int] {
        guard let spec = rules.elevator(for: shaft.definitionID) else { return Array(shaft.floors.lowest...shaft.floors.highest) }
        return spec.servedFloors(of: shaft.floors, skipping: world.elevators[shaft.id]?.skippedFloors)
    }

    /// Switches a floor on or off for `shaft`'s car. Fails on a floor the car cannot stop at
    /// (outside the shaft, or between an express shuttle's ends) or when fewer than two
    /// floors would stay on.
    public static func set(_ floor: Int, served: Bool, shaft id: RoomID, world: inout GameWorld, rules: SimulationRules) throws {
        guard let shaft = world.rooms[id], let spec = rules.elevator(for: shaft.definitionID), let car = world.elevators[id] else {
            throw StopError.notAnElevator
        }
        let possible = spec.stopFloors(of: shaft.floors)
        guard possible.contains(floor) else { throw StopError.notAStop }
        var skipped = Set(car.skippedFloors ?? []).intersection(possible)
        if served { skipped.remove(floor) } else { skipped.insert(floor) }
        guard possible.count - skipped.count >= 2 else { throw StopError.tooFew }
        world.elevators.update(id) { $0.skippedFloors = skipped.isEmpty ? nil : skipped.sorted() }
    }
}
