import Foundation

/// One elevator ride within a trip: board at `fromFloor`, alight at `toFloor`. People wait
/// at the landing in front of the shaft at `x`.
public struct Ride: Codable, Hashable, Sendable {
    public var shaft: RoomID
    public var fromFloor: Int
    public var toFloor: Int
    public var x: Double
    /// Set once the bank's dispatcher has chosen the car (`shaft`) for this ride (Phase 7).
    public var assigned: Bool?

    public init(shaft: RoomID, fromFloor: Int, toFloor: Int, x: Double, assigned: Bool? = nil) {
        self.shaft = shaft
        self.fromFloor = fromFloor
        self.toFloor = toFloor
        self.x = x
        self.assigned = assigned
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

/// How a bank of elevators assigns hall calls to its cars (Phase 7). Chosen per bank by the
/// player; stored on every car of the bank.
public enum DispatchStrategy: String, Codable, CaseIterable, Hashable, Sendable {
    /// Each call goes to the car that can reach it soonest; cars sweep collecting calls.
    case collective
    /// Upper floors are split into one zone per car; a car takes trips to its zone.
    case zoning
    /// Passengers going to the same floor are grouped into the same car.
    case destination
}

/// Running statistics of one car (saved, deterministic).
public struct CarStats: Codable, Hashable, Sendable {
    public var boardings = 0
    /// Sum and maximum of waiting times of everyone who boarded (seconds).
    public var totalWait: Tick = 0
    public var maxWait: Tick = 0
    /// People who gave up waiting for this car and took the stairs.
    public var abandoned = 0
    /// Times the car stopped and opened its doors.
    public var stops = 0
    /// Boardings per hour of day on `day`.
    public var day: Tick = 0
    public var hourly: [Int] = Array(repeating: 0, count: 24)

    public init() {}

    public var averageWait: Double { boardings == 0 ? 0 : Double(totalWait) / Double(boardings) }

    public mutating func recordBoarding(waited: Tick, at tick: Tick) {
        boardings += 1
        totalWait += waited
        maxWait = max(maxWait, waited)
        let today = SimClock.day(tick)
        if today != day {
            day = today
            hourly = Array(repeating: 0, count: 24)
        }
        hourly[Int(SimClock.secondOfDay(tick) / 3600)] += 1
    }

    /// Boardings during the last completed hour of the current day (0 in the first hour).
    public func passengersLastHour(at tick: Tick) -> Int {
        guard SimClock.day(tick) == day else { return 0 }
        let hour = Int(SimClock.secondOfDay(tick) / 3600)
        return hour > 0 ? hourly[hour - 1] : 0
    }
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
    /// Dispatch strategy of the car's bank (Phase 7).
    public var strategy: DispatchStrategy
    public var stats: CarStats
    /// Broken down (Phase E, save format 17; nil = running): the car stands until a
    /// technician repairs its shaft.
    public var outOfService: Bool?

    public var isOutOfService: Bool { outOfService == true }

    public init(id: RoomID, buildingID: BuildingID, floor: Int, strategy: DispatchStrategy = .collective) {
        self.id = id
        self.buildingID = buildingID
        self.floor = floor
        direction = 0
        motion = .idle
        passengers = []
        nextEventTick = .max
        self.strategy = strategy
        stats = CarStats()
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
