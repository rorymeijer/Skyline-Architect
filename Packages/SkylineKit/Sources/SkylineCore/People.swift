import Foundation

public enum PersonTag {}
public typealias PersonID = EntityID<PersonTag>

/// Game time in whole ticks. One tick is one game second (`SimClock.secondsPerTick`).
public typealias Tick = UInt64

/// The world's simulation clock. Only the simulation advances it, in whole ticks, so the
/// state after N ticks is identical whatever the game speed (SIMULATION.md).
public struct SimClock: Codable, Hashable, Sendable {
    public static let secondsPerTick = 1.0
    public static let secondsPerDay: Tick = 86_400
    /// Tick 0 is day 1 at 06:00.
    public static let startSecondOfDay: Tick = 6 * 3600

    public var tick: Tick

    public init(tick: Tick = 0) { self.tick = tick }

    /// Seconds since midnight of the current day.
    public static func secondOfDay(_ tick: Tick) -> Tick { (tick + startSecondOfDay) % secondsPerDay }
    /// Zero-based day index.
    public static func day(_ tick: Tick) -> Tick { (tick + startSecondOfDay) / secondsPerDay }

    /// First tick at or after `from` whose time of day is `second` (seconds since midnight).
    public static func nextTick(atSecondOfDay second: Tick, onOrAfter from: Tick) -> Tick {
        let absolute = from + startSecondOfDay                   // seconds since day-0 midnight
        var target = (absolute / secondsPerDay) * secondsPerDay + second % secondsPerDay
        if target < absolute { target += secondsPerDay }
        return target - startSecondOfDay                         // ≥ 0: target ≥ absolute ≥ start
    }

    /// "HH:MM" for display.
    public static func timeString(_ tick: Tick) -> String {
        let s = secondOfDay(tick)
        let h = s / 3600, m = (s % 3600) / 60
        return (h < 10 ? "0" : "") + "\(h):" + (m < 10 ? "0" : "") + "\(m)"
    }
}

public enum PersonRole: String, Codable, Hashable, Sendable {
    case worker, resident
}

/// One segment of a trip with absolute start/end ticks. Positions along a leg are an exact
/// function of time, so people need no per-tick updates while moving and the renderer can
/// evaluate them at fractional ticks (interpolation for free).
public enum Leg: Codable, Hashable, Sendable {
    /// Walking along a floor's walking surface.
    case walk(floor: Int, fromX: Double, toX: Double, start: Tick, end: Tick)
    /// Climbing (or descending) a stairwell. `leftX`/`rightX` bound the flights.
    case stairs(shaft: RoomID, fromFloor: Int, toFloor: Int, leftX: Double, rightX: Double, start: Tick, end: Tick)

    public var start: Tick {
        switch self { case .walk(_, _, _, let s, _), .stairs(_, _, _, _, _, let s, _): s }
    }

    public var end: Tick {
        switch self { case .walk(_, _, _, _, let e), .stairs(_, _, _, _, _, _, let e): e }
    }
}

/// Where a person is.
public enum Place: Codable, Hashable, Sendable {
    /// Not on the property (not simulated in detail, not drawn).
    case outside
    /// Inside a room, standing/sitting at `x`.
    case room(RoomID, x: Double)
    /// On a trip; `legs` are contiguous in time and `destination` is reached at the last leg's
    /// end — unless the person has a `pendingRide`, which starts there.
    case travelling(legs: [Leg], destination: Destination)
    /// Queuing at an elevator landing since `since` (queue order: since, then id).
    case waiting(Ride, destination: Destination, since: Tick)
    /// Inside an elevator car (listed in the car's passengers).
    case riding(Ride, destination: Destination)
}

/// What a person intends to do at `nextEventTick` when at rest.
public enum Goal: String, Codable, Hashable, Sendable {
    case work, home, outside
}

public enum Destination: Codable, Hashable, Sendable {
    case outside
    case room(RoomID, x: Double)
}

/// A simulated individual. Everything logically relevant is stored here (and saved);
/// rendering derives from it.
public struct Person: Codable, Hashable, Sendable, Identifiable {
    public let id: PersonID
    public var name: String
    public var age: Int
    public var role: PersonRole
    /// Schedule definition id from content (`schedules.json`).
    public var scheduleID: String
    public var buildingID: BuildingID
    public var homeRoom: RoomID?
    public var workRoom: RoomID?
    public var place: Place
    /// Tick of the next thing this person does (arrive, next schedule event).
    public var nextEventTick: Tick
    /// What they do at `nextEventTick` when at rest (nil while travelling).
    public var nextGoal: Goal?
    /// Seed for appearance and personal jitter.
    public var traits: UInt32
    /// Set when the last planned trip had no route (e.g. no stairs to the target floor).
    public var unreachable: Bool
    /// Elevator ride that starts when the current walking legs end (Phase 6).
    public var pendingRide: Ride?
    /// The household or business this person belongs to (Phase 8).
    public var tenantID: TenantID?

    public init(id: PersonID, name: String, age: Int, role: PersonRole, scheduleID: String, buildingID: BuildingID,
                homeRoom: RoomID?, workRoom: RoomID?, place: Place, nextEventTick: Tick, nextGoal: Goal?, traits: UInt32) {
        self.id = id
        self.name = name
        self.age = age
        self.role = role
        self.scheduleID = scheduleID
        self.buildingID = buildingID
        self.homeRoom = homeRoom
        self.workRoom = workRoom
        self.place = place
        self.nextEventTick = nextEventTick
        self.nextGoal = nextGoal
        self.traits = traits
        self.unreachable = false
        self.pendingRide = nil
        self.tenantID = nil
    }

    /// The room this person belongs to by role.
    public var anchorRoom: RoomID? { role == .worker ? workRoom : homeRoom }
}

/// Exact position of a person on a trip at (fractional) time `t`, in world meters, plus the
/// walking direction (+1 right, −1 left) and whether they are on stairs.
public struct MotionSample: Equatable, Sendable {
    public var position: Vec2
    public var direction: Double
    public var onStairs: Bool
}

public enum PersonMotion {
    public static func sample(_ legs: [Leg], at t: Double, grid: GridSpec) -> MotionSample? {
        guard let first = legs.first else { return nil }
        let leg = legs.first { t < Double($0.end) } ?? legs.last!
        let tt = max(Double(first.start), t)
        switch leg {
        case let .walk(floor, fromX, toX, start, end):
            let f = fraction(tt, start, end)
            return MotionSample(position: Vec2(fromX + (toX - fromX) * f, grid.y(ofFloor: floor)),
                                direction: toX >= fromX ? 1 : -1, onStairs: false)
        case let .stairs(_, fromFloor, toFloor, leftX, rightX, start, end):
            // Each storey has two flights: from the floor landing (left) to the half landing
            // (right), then back. Descending walks the same flights in reverse storey order,
            // so both directions start on the left landing with a rightward flight.
            let f = fraction(tt, start, end)
            let floors = Double(abs(toFloor - fromFloor))
            let up = toFloor > fromFloor
            let progress = f * floors
            let storey = min(floor(progress), max(floors - 1, 0))
            let within = progress - storey
            let y = grid.y(ofFloor: fromFloor) + (up ? 1 : -1) * progress * grid.floorHeight
            let rightward = within < 0.5
            let firstFlight = rightward
            let flightF = firstFlight ? within * 2 : (within - 0.5) * 2
            let x = rightward ? leftX + (rightX - leftX) * flightF : rightX - (rightX - leftX) * flightF
            return MotionSample(position: Vec2(x, y), direction: rightward ? 1 : -1, onStairs: true)
        }
    }

    static func fraction(_ t: Double, _ start: Tick, _ end: Tick) -> Double {
        guard end > start else { return 1 }
        return min(max((t - Double(start)) / Double(end - start), 0), 1)
    }
}
