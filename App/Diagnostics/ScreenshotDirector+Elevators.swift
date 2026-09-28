#if DEBUG
import Foundation
import SkylineCore
import SkylineSimulation

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

    /// Someone walking across `floor` from one elevator to the next (a sky-lobby transfer).
    static func skyLobbyWalker(on floor: Int, in world: GameWorld) -> Vec2? {
        let now = world.clock.tick
        for p in world.people {
            guard p.pendingRide != nil, case let .travelling(legs, _) = p.place,
                  let leg = legs.first(where: { now < $0.end }), case .walk(floor, _, _, let start, let end) = leg,
                  end > start + 3, now > start + 1, now + 1 < end,          // mid-walk, not at a door
                  let s = PersonMotion.sample(legs, at: Double(now), grid: world.grid) else { continue }
            return s.position
        }
        return nil
    }

    /// A staff member at work (job started), and where.
    static func staffAtWork(_ role: PersonRole, in world: GameWorld) -> Vec2? {
        for p in world.people where p.role == role {
            guard case let .room(r, x) = p.place, p.job?.until != nil, let room = world.rooms[r] else { continue }
            return Vec2(x, world.grid.y(ofFloor: room.floors.lowest))
        }
        return nil
    }

    /// "Population 12/35 ✗, …" for the next class's requirements.
    static func requirements(_ p: ProgressionSummary) -> String {
        guard let next = p.nextClassName else { return "highest class" }
        return "next \(next): " + p.requirements.map { "\($0.label) \(Int($0.current))/\(Int($0.needed)) \($0.met ? "✓" : "✗")" }.joined(separator: ", ")
    }

    /// Sets today's weather (developer tool for captures): no transition, clear tomorrow.
    static func force(_ kind: String, _ temperature: Double, model: AppModel) {
        guard let day = model.world?.weather?.day else { return }
        model.world?.weather = WeatherState(day: day, yesterday: kind, today: kind, tomorrow: "clear", temperature: temperature)
    }

    /// The `index`-th office from the bottom.
    static func office(_ model: AppModel, index: Int) -> Room? {
        guard let world = model.world else { return nil }
        let offices = world.rooms.values.filter { $0.definitionID == "office-small" }.sorted { ($0.floors.lowest, $0.id) < ($1.floors.lowest, $1.id) }
        return offices.indices.contains(index) ? offices[index] : offices.last
    }

    static func weatherNote(_ model: AppModel) -> String {
        guard let w = model.weather else { return "no weather" }
        return "\(w.season), \(w.name) \(w.temperature) °C, tomorrow \(w.tomorrowName)" + (w.effects.isEmpty ? "" : " — \(w.effects)")
    }

    /// A grid cell inside a room (for selecting it like a click would).
    static func cell(of room: Room) -> GridCell {
        GridCell(column: room.columns.start + room.columns.count / 2, floor: room.floors.lowest)
    }

    static func carCenter(_ car: ElevatorCar, in world: GameWorld) -> Vec2? {
        guard let shaft = world.rooms[car.id] else { return nil }
        let x = (world.grid.x(ofColumn: shaft.columns.start) + world.grid.x(ofColumn: shaft.columns.end)) / 2
        return Vec2(x, ElevatorMotion.y(of: car, at: Double(world.clock.tick), grid: world.grid) + 1.3)
    }
}
#endif
