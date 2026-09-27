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

    public init(first: [String], last: [String]) {
        self.first = first
        self.last = last
    }
}

/// Everything the simulation needs from content, plus movement constants.
public struct SimulationRules: Sendable {
    public let schedules: [Schedule]
    public let names: NamePool
    /// Walking speed in meters per game second.
    public var walkSpeed = 1.3
    /// Game seconds to climb or descend one storey by stairs.
    public var stairsSecondsPerFloor: Tick = 14
    /// Street distance walked outside the entrance when arriving or leaving (meters).
    public var streetDistance = 14.0

    public init(schedules: [Schedule], names: NamePool) {
        self.schedules = schedules
        self.names = names
    }

    public func schedule(_ id: String) -> Schedule? { schedules.first { $0.id == id } }

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
