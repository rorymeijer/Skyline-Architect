import Foundation

/// One elevator ride within a trip: board at `fromFloor`, alight at `toFloor`. People wait
/// at the landing in front of the shaft at `x`.
public struct Ride: Codable, Hashable, Sendable {
    public var shaft: RoomID
    public var fromFloor: Int
    public var toFloor: Int
    public var x: Double

    public init(shaft: RoomID, fromFloor: Int, toFloor: Int, x: Double) {
        self.shaft = shaft
        self.fromFloor = fromFloor
        self.toFloor = toFloor
        self.x = x
    }

    /// +1 up, −1 down.
    public var direction: Int { toFloor > fromFloor ? 1 : -1 }
}

/// What a car is doing. Motion is analytic (trapezoidal velocity profile), so a car needs
/// events only when it arrives or its doors close.
public enum CarMotion: Codable, Hashable, Sendable {
    /// Doors closed, no calls.
    case idle
    /// Travelling between floors; position is `ElevatorMotion.y(...)` at any time.
    case moving(fromFloor: Int, toFloor: Int, start: Tick, end: Tick, speed: Double, acceleration: Double)
    /// Doors open at `ElevatorCar.floor` from `since` until `until` (closing included).
    case stopped(since: Tick, until: Tick)
}

/// The (single) car of an elevator shaft. The shaft is a room whose spec has
/// `transport: "elevator"`; the car shares its id.
public struct ElevatorCar: Codable, Hashable, Sendable, Identifiable {
    public let id: RoomID
    public var buildingID: BuildingID
    /// Current floor, or the floor last departed while moving.
    public var floor: Int
    /// +1 up, −1 down, 0 no direction (idle).
    public var direction: Int
    public var motion: CarMotion
    /// People inside, in boarding order.
    public var passengers: [PersonID]
    /// Tick of the next car event (arrival, departure, decision); `Tick.max` when idle.
    public var nextEventTick: Tick

    public init(id: RoomID, buildingID: BuildingID, floor: Int) {
        self.id = id
        self.buildingID = buildingID
        self.floor = floor
        direction = 0
        motion = .idle
        passengers = []
        nextEventTick = .max
    }
}

/// Exact car kinematics: accelerate at `a` up to `v`, cruise, decelerate (or a triangular
/// profile for short trips). Durations are rounded up to whole ticks; the car rests at the
/// target for the rounding remainder.
public enum ElevatorMotion {
    /// Seconds to travel `distance` meters.
    public static func duration(distance: Double, speed v: Double, acceleration a: Double) -> Double {
        guard distance > 0, v > 0, a > 0 else { return 0 }
        let rampDistance = v * v / a                     // accelerate + decelerate
        return distance >= rampDistance ? distance / v + v / a : 2 * (distance / a).squareRoot()
    }

    /// Meters covered after `t` seconds of a trip of `distance`.
    public static func distance(after t: Double, of distance: Double, speed v: Double, acceleration a: Double) -> Double {
        let total = duration(distance: distance, speed: v, acceleration: a)
        guard t > 0 else { return 0 }
        guard t < total else { return distance }
        let peak = min(v, (distance * a).squareRoot())  // highest speed reached
        let ramp = peak / a
        if t <= ramp { return 0.5 * a * t * t }
        let rampDistance = 0.5 * a * ramp * ramp
        if t <= total - ramp { return rampDistance + peak * (t - ramp) }
        let left = total - t
        return distance - 0.5 * a * left * left
    }

    public static func ticks(floors: Int, grid: GridSpec, speed: Double, acceleration: Double) -> Tick {
        let d = Double(abs(floors)) * grid.floorHeight
        return max(Tick(duration(distance: d, speed: speed, acceleration: acceleration).rounded(.up)), 1)
    }

    /// Car floor-level height (y of the car floor) at time `t`.
    public static func y(of car: ElevatorCar, at t: Double, grid: GridSpec) -> Double {
        guard case let .moving(from, to, start, _, v, a) = car.motion else { return grid.y(ofFloor: car.floor) }
        let total = Double(abs(to - from)) * grid.floorHeight
        let covered = distance(after: t - Double(start), of: total, speed: v, acceleration: a)
        return grid.y(ofFloor: from) + (to > from ? covered : -covered)
    }

    /// Door opening 0 (closed) … 1 (open) at time `t`.
    public static func doorOpening(of car: ElevatorCar, at t: Double, doorSeconds: Double = 2) -> Double {
        guard case let .stopped(since, until) = car.motion else { return 0 }
        let opening = (t - Double(since)) / doorSeconds
        let closing = (Double(until) - t) / doorSeconds
        return min(max(min(opening, closing), 0), 1)
    }
}
