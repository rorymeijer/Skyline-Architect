#if DEBUG
import Foundation
import SkylineCore

/// Scenario helpers for the Phase 6 (elevator) captures.
extension ScreenshotDirector {
    static func waiting(in world: GameWorld, floor: Int? = nil) -> Int {
        world.people.values.filter { p in
            guard case let .waiting(ride, _, _) = p.place else { return false }
            return floor.map { ride.fromFloor == $0 } ?? true
        }.count
    }

    /// Cars standing with doors open and people inside (boarding / alighting moments).
    static func boardingCar(in world: GameWorld) -> ElevatorCar? {
        world.elevators.values.first { car in
            if case .stopped = car.motion { return !car.passengers.isEmpty } else { return false }
        }
    }

    /// Riders in a moving car, and where the car is (world meters, cab centre).
    static func movingCar(in world: GameWorld) -> (riders: Int, center: Vec2)? {
        for car in world.elevators {
            guard case .moving = car.motion, !car.passengers.isEmpty, let shaft = world.rooms[car.id] else { continue }
            let x = (world.grid.x(ofColumn: shaft.columns.start) + world.grid.x(ofColumn: shaft.columns.end)) / 2
            let y = ElevatorMotion.y(of: car, at: Double(world.clock.tick), grid: world.grid)
            return (car.passengers.count, Vec2(x, y + 1.3))
        }
        return nil
    }

    static func carCenter(_ car: ElevatorCar, in world: GameWorld) -> Vec2? {
        guard let shaft = world.rooms[car.id] else { return nil }
        let x = (world.grid.x(ofColumn: shaft.columns.start) + world.grid.x(ofColumn: shaft.columns.end)) / 2
        return Vec2(x, ElevatorMotion.y(of: car, at: Double(world.clock.tick), grid: world.grid) + 1.3)
    }
}
#endif
