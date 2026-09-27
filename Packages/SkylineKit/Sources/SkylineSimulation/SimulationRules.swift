import Foundation
import SkylineCore

/// A daily routine (`schedules.json`): at each time (± jitter) the person heads for a goal.
public struct Schedule: Codable, Hashable, Sendable {
    public struct Event: Codable, Hashable, Sendable {
        /// "HH:MM".
        public var at: String
        /// Personal variation, ± minutes (deterministic per person and day).
        public var jitterMinutes: Int
        public var goal: Goal

        public init(at: String, jitterMinutes: Int, goal: Goal) {
            self.at = at
            self.jitterMinutes = jitterMinutes
            self.goal = goal
        }

        /// Seconds since midnight, or nil if `at` is malformed.
        public var secondOfDay: Tick? {
            let parts = at.split(separator: ":")
            guard parts.count == 2, let h = Tick(parts[0]), let m = Tick(parts[1]), h < 24, m < 60 else { return nil }
            return h * 3600 + m * 60
        }
    }

    public var id: String
    public var role: PersonRole
    public var events: [Event]

    public init(id: String, role: PersonRole, events: [Event]) {
        self.id = id
        self.role = role
        self.events = events
    }
}

/// Pools used to generate deterministic, original names (`names.json`).
public struct NamePool: Codable, Hashable, Sendable {
    public var first: [String]
    public var last: [String]
    /// Business names are "<word> <suffix>" (Phase 8; optional for older packs).
    public var businessWords: [String]?
    public var businessSuffixes: [String]?

    public init(first: [String], last: [String], businessWords: [String]? = nil, businessSuffixes: [String]? = nil) {
        self.first = first
        self.last = last
        self.businessWords = businessWords
        self.businessSuffixes = businessSuffixes
    }
}

/// Elevator car parameters for one shaft room type (`elevators.json`).
public struct ElevatorSpec: Codable, Hashable, Sendable {
    /// Room definition id of the shaft these cars run in.
    public var room: String
    public var name: String
    /// Persons per car.
    public var capacity: Int
    /// Rated speed, m/s.
    public var speed: Double
    /// Acceleration and deceleration, m/s².
    public var acceleration: Double
    /// Seconds to open (and again to close) the doors.
    public var doorSeconds: Tick
    /// Seconds per person boarding or alighting.
    public var transferSeconds: Tick
    /// Waiting time assumed by route planning when choosing elevator vs. stairs. A constant
    /// (not the live queue) so routes stay cacheable and deterministic (D-026).
    public var expectedWaitSeconds: Double
    /// "all" (default): stops at every floor of the shaft; "ends": only at its lowest and
    /// highest floor (express / shuttle to a sky lobby).
    public var stops: String?
    /// Typical patience at a landing before taking the stairs (default 150 s; personal
    /// variation ±50 %).
    public var patienceSeconds: Double?

    public init(room: String, name: String, capacity: Int, speed: Double, acceleration: Double,
                doorSeconds: Tick, transferSeconds: Tick, expectedWaitSeconds: Double,
                stops: String? = nil, patienceSeconds: Double? = nil) {
        self.room = room
        self.name = name
        self.capacity = capacity
        self.speed = speed
        self.acceleration = acceleration
        self.doorSeconds = doorSeconds
        self.transferSeconds = transferSeconds
        self.expectedWaitSeconds = expectedWaitSeconds
        self.stops = stops
        self.patienceSeconds = patienceSeconds
    }

    /// Floors of a shaft spanning `floors` where cars stop.
    public func servedFloors(of floors: FloorSpan) -> [Int] {
        stops == "ends" ? [floors.lowest, floors.highest] : Array(floors.lowest...floors.highest)
    }

    /// A person's patience in whole seconds (deterministic per traits).
    public func patience(traits: UInt32) -> Tick {
        let base = patienceSeconds ?? 150
        let factor = 0.5 + Double((traits >> 8) % 1000) / 1000
        return Tick((base * factor).rounded())
    }

    /// Validation problems (empty if valid).
    public var problems: [String] {
        var p: [String] = []
        if capacity < 1 { p.append("elevator '\(room)': capacity must be at least 1") }
        if !(speed > 0 && speed <= 20) { p.append("elevator '\(room)': speed must be in (0, 20] m/s") }
        if !(acceleration > 0 && acceleration <= 3) { p.append("elevator '\(room)': acceleration must be in (0, 3] m/s²") }
        if doorSeconds < 1 || doorSeconds > 20 { p.append("elevator '\(room)': doorSeconds must be 1…20") }
        if transferSeconds > 20 { p.append("elevator '\(room)': transferSeconds must be ≤ 20") }
        if expectedWaitSeconds < 0 { p.append("elevator '\(room)': expectedWaitSeconds must be ≥ 0") }
        if let s = stops, !["all", "ends"].contains(s) { p.append("elevator '\(room)': stops must be 'all' or 'ends'") }
        if let q = patienceSeconds, !(q >= 10 && q <= 3600) { p.append("elevator '\(room)': patienceSeconds must be 10…3600") }
        return p
    }
}

/// Everything the simulation needs from content, plus movement constants.
public struct SimulationRules: Sendable {
    public let schedules: [Schedule]
    public let names: NamePool
    public let elevators: [ElevatorSpec]
    public let tenantTypes: [TenantType]
    /// Walking speed in meters per game second.
    public var walkSpeed = 1.3
    /// Game seconds to climb or descend one storey by stairs.
    public var stairsSecondsPerFloor: Tick = 14
    /// Street distance walked outside the entrance when arriving or leaving (meters).
    public var streetDistance = 14.0
    /// Someone who runs out of patience at a landing takes the stairs only if that trip
    /// takes at most this long (seconds); otherwise they keep waiting.
    public var maxStairsDetourSeconds: Tick = 300

    public init(schedules: [Schedule], names: NamePool, elevators: [ElevatorSpec] = [], tenantTypes: [TenantType] = []) {
        self.schedules = schedules
        self.names = names
        self.elevators = elevators
        self.tenantTypes = tenantTypes
    }

    public func tenantType(_ id: String) -> TenantType? { tenantTypes.first { $0.id == id } }

    /// Tenant types that may rent a room type, in content order.
    public func tenantTypes(for roomDefinition: String) -> [TenantType] {
        tenantTypes.filter { $0.rooms.contains(roomDefinition) }
    }

    public func schedule(_ id: String) -> Schedule? { schedules.first { $0.id == id } }

    /// Car parameters for an elevator shaft room type.
    public func elevator(for roomDefinition: String) -> ElevatorSpec? { elevators.first { $0.room == roomDefinition } }

    /// The first schedule defined for a role (content order).
    public func defaultSchedule(for role: PersonRole) -> Schedule? { schedules.first { $0.role == role } }

    /// Validation problems (empty if valid).
    public static func validate(schedules: [Schedule], names: NamePool) -> [String] {
        var problems: [String] = []
        var ids = Set<String>()
        for s in schedules {
            if !ids.insert(s.id).inserted { problems.append("duplicate schedule '\(s.id)'") }
            if s.events.isEmpty { problems.append("schedule '\(s.id)' has no events") }
            for e in s.events {
                if e.secondOfDay == nil { problems.append("schedule '\(s.id)': invalid time '\(e.at)'") }
                if e.jitterMinutes < 0 || e.jitterMinutes > 180 { problems.append("schedule '\(s.id)': jitter out of range") }
            }
        }
        for role in [PersonRole.worker, .resident] where !schedules.contains(where: { $0.role == role }) {
            problems.append("no schedule for role '\(role.rawValue)'")
        }
        if names.first.isEmpty || names.last.isEmpty { problems.append("name pools must not be empty") }
        return problems
    }

    /// The next scheduled goal strictly after `tick` for a person (deterministic jitter per
    /// person, day and event).
    func nextScheduled(after tick: Tick, schedule: Schedule, traits: UInt32) -> (tick: Tick, goal: Goal)? {
        var best: (Tick, Goal)?
        let today = SimClock.day(tick)
        for day in [today, today + 1] {
            let dayStart = day * SimClock.secondsPerDay
            for (i, event) in schedule.events.enumerated() {
                guard let base = event.secondOfDay else { continue }
                var rng = SeededRandom(seed: UInt64(traits), stream: day &* 64 &+ UInt64(i))
                let jitter = Int64(event.jitterMinutes * 60)
                let offset = jitter > 0 ? Int64(rng.int(in: 0..<Int(2 * jitter + 1))) - jitter : 0
                let second = min(max(Int64(base) + offset, 0), Int64(SimClock.secondsPerDay) - 1)
                let absolute = dayStart + Tick(second)
                guard absolute >= SimClock.startSecondOfDay else { continue }  // before the game began
                let t = absolute - SimClock.startSecondOfDay
                if t > tick, best == nil || t < best!.0 { best = (t, event.goal) }
            }
            if best != nil { break }
        }
        return best.map { (tick: $0.0, goal: $0.1) }
    }
}
