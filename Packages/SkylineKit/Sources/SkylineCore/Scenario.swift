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

/// How a scenario ended.
public struct ScenarioResult: Codable, Hashable, Sendable {
    public var won: Bool
    public var tick: Tick
    public var reason: String

    public init(won: Bool, tick: Tick, reason: String) {
        self.won = won
        self.tick = tick
        self.reason = reason
    }
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
