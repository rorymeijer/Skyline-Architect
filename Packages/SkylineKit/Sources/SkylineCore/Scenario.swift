import Foundation

/// What a scenario objective measures (Phase 16). Measured over the whole estate at every
/// daily closing; see SCENARIOS.md for the exact definitions.
public enum ScenarioMetric: String, Codable, CaseIterable, Hashable, Sendable {
    /// Tenant members (residents and workers; staff excluded).
    case population
    /// Rentable units with a tenant.
    case occupiedUnits
    /// Cash on hand after the closing.
    case cash
    /// The day's operating result: rent, maintenance, utilities, wages and interest of the
    /// last full day (construction, land and loans excluded).
    case dailyProfit
    /// The best building class reached (0 = the first class).
    case buildingClass
    /// The best building reputation (0…100).
    case reputation
    /// Average elevator wait in seconds over every bank with enough boardings. An upper limit.
    case averageWait
    /// Properties owned.
    case properties

    /// Objectives on this metric are met at or *below* the target.
    public var isUpperLimit: Bool { self == .averageWait }
}

/// One goal: a metric and the value it must reach (or stay under).
public struct ScenarioObjective: Codable, Hashable, Sendable {
    public var metric: ScenarioMetric
    public var target: Double

    public init(metric: ScenarioMetric, target: Double) {
        self.metric = metric
        self.target = target
    }

    /// Whether a measured value meets the objective (no measurement never does).
    public func isMet(by value: Double?) -> Bool {
        guard let value else { return false }
        return metric.isUpperLimit ? value <= target : value >= target
    }
}

/// What a scenario forbids (Phase C). Copied into the save with the objectives.
public struct ScenarioRestrictions: Codable, Hashable, Sendable {
    /// Room definition ids that may not be placed.
    public var forbiddenRooms: [String]?
    /// Highest floor level that may be built.
    public var maxFloor: Int?
    /// Highest loan total.
    public var maxLoans: Int?
    /// Rent levels (building and unit) stay at 100 %.
    public var fixedRent: Bool?
    /// No janitors or technicians can be hired.
    public var noStaff: Bool?

    public init(forbiddenRooms: [String]? = nil, maxFloor: Int? = nil, maxLoans: Int? = nil, fixedRent: Bool? = nil, noStaff: Bool? = nil) {
        self.forbiddenRooms = forbiddenRooms
        self.maxFloor = maxFloor
        self.maxLoans = maxLoans
        self.fixedRent = fixedRent
        self.noStaff = noStaff
    }

    public func forbids(_ roomDefinition: String) -> Bool { forbiddenRooms?.contains(roomDefinition) ?? false }
    public var rentIsFixed: Bool { fixedRent == true }
    public var staffForbidden: Bool { noStaff == true }
}

/// How a scenario ended.
public struct ScenarioResult: Codable, Hashable, Sendable {
    public var won: Bool
    public var tick: Tick
    public var reason: String
    /// Phase C: 0–3 stars (0 = lost) and points.
    public var stars: Int?
    public var score: Int?

    public init(won: Bool, tick: Tick, reason: String, stars: Int? = nil, score: Int? = nil) {
        self.won = won
        self.tick = tick
        self.reason = reason
        self.stars = stars
        self.score = score
    }
}

/// A scripted scenario event (Phase C): at a scenario day and hour something happens, with a
/// message for the news. Copied into the save like the objectives.
public struct ScenarioEvent: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        /// A message only.
        case news
        /// Tenant demand × `multiplier` for `days` (all types, or `tenantType` only).
        case demand
        /// `amount` paid to the player — only if `when` is met (a subsidy for a milestone).
        case grant
        /// `amount` charged — only if `when` is not met (a failed inspection).
        case fine
        /// Today's weather in the scenario's city becomes `weather`.
        case weather
        /// A fire breaks out in the scenario's building.
        case fire
    }

    /// Scenario day, 1 = the first day.
    public var day: Int
    /// Hour of that day (default 9).
    public var hour: Int?
    public var kind: Kind
    public var message: String
    public var amount: Int?
    public var multiplier: Double?
    public var days: Int?
    public var tenantType: String?
    public var weather: String?
    public var when: ScenarioObjective?

    public init(day: Int, hour: Int? = nil, kind: Kind, message: String, amount: Int? = nil, multiplier: Double? = nil,
                days: Int? = nil, tenantType: String? = nil, weather: String? = nil, when: ScenarioObjective? = nil) {
        self.day = day
        self.hour = hour
        self.kind = kind
        self.message = message
        self.amount = amount
        self.multiplier = multiplier
        self.days = days
        self.tenantType = tenantType
        self.weather = weather
        self.when = when
    }
}

/// A news line of the scenario (what an event said, and when).
public struct ScenarioNews: Codable, Hashable, Sendable {
    public var tick: Tick
    public var text: String

    public init(tick: Tick, text: String) {
        self.tick = tick
        self.text = text
    }
}

/// A running change of tenant demand from a scripted event.
public struct DemandShock: Codable, Hashable, Sendable {
    /// nil = every tenant type.
    public var tenantType: String?
    public var multiplier: Double
    /// Game day on which it ends (exclusive).
    public var untilDay: Tick

    public init(tenantType: String?, multiplier: Double, untilDay: Tick) {
        self.tenantType = tenantType
        self.multiplier = multiplier
        self.untilDay = untilDay
    }
}

/// How a won scenario is scored (Phase C; defaults below). Stars: one for winning, one for
/// winning within `fastShare` of the days, one when every objective beats its target by
/// `margin`. Points: `winPoints` + `pointsPerDayLeft` per day left + up to `overshootPoints`
/// per objective for beating it (full at twice the target) + `reputationPoints` × the best
/// reputation. A lost scenario scores 100 points per fully met objective, in proportion.
public struct ScenarioScoring: Codable, Hashable, Sendable {
    public var fastShare: Double?
    public var margin: Double?
    public var winPoints: Int?
    public var pointsPerDayLeft: Int?
    public var overshootPoints: Int?
    public var reputationPoints: Double?

    public init() {}

    public var fast: Double { fastShare ?? 0.6 }
    public var beat: Double { margin ?? 0.25 }
    public var win: Int { winPoints ?? 1000 }
    public var perDayLeft: Int { pointsPerDayLeft ?? 50 }
    public var overshoot: Int { overshootPoints ?? 250 }
    public var reputation: Double { reputationPoints ?? 2 }
}

/// The scenario a game is playing (saved). The objectives are copied from content when the
/// game starts, so a save keeps its rules even if the content changes later.
public struct ScenarioState: Codable, Hashable, Sendable {
    /// Content definition id.
    public var id: String
    public var name: String
    public var objectives: [ScenarioObjective]
    /// The game day whose closing is the last chance to win.
    public var deadlineDay: Tick
    /// Consecutive closings every objective must hold.
    public var holdDays: Int
    /// Closings in a row with every objective met, so far.
    public var streak = 0
    /// The values measured at the last closing, one per objective (nil = no data yet).
    public var measured: [Double?]
    /// Set once the scenario is won or lost; evaluation stops, the game may go on.
    public var result: ScenarioResult?
    /// What the scenario forbids (Phase C, save format 18; nil = nothing).
    public var restrictions: ScenarioRestrictions?
    /// Phase C: the game day the scenario began, its scripted events (and which have
    /// fired, by index), the news so far, running demand shocks, and its scoring.
    public var startDay: Tick?
    public var events: [ScenarioEvent]?
    public var fired: [Int]?
    public var news: [ScenarioNews]?
    public var shocks: [DemandShock]?
    public var scoring: ScenarioScoring?

    public init(id: String, name: String, objectives: [ScenarioObjective], deadlineDay: Tick, holdDays: Int) {
        self.id = id
        self.name = name
        self.objectives = objectives
        self.deadlineDay = deadlineDay
        self.holdDays = max(holdDays, 1)
        self.measured = Array(repeating: nil, count: objectives.count)
    }

    public var allMet: Bool {
        zip(objectives, measured).allSatisfy { $0.isMet(by: $1) }
    }
}
