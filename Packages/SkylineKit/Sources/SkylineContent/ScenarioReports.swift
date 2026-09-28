import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// What the scenario browser, the objectives panel and the result screen show (Phase 16).
/// Pure data.
public struct ScenarioSummary: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        /// "Units let ≥ 12"
        public var label: String
        /// "9" / "$4,250" / "—" (not measured yet)
        public var current: String
        public var met: Bool
        /// 0…1 towards the target (1 when met).
        public var fraction: Double
    }

    public var id = ""
    public var name = ""
    public var rows: [Row] = []
    /// Closings left including today's deadline (0 once decided).
    public var daysLeft = 0
    public var holdDays = 1
    public var streak = 0
    public var result: ScenarioResult?

    public init() {}

    /// The live state of a world's scenario (nil in free play). Values are measured now, so
    /// the panel moves during the day; the result is decided only at the closings.
    public static func make(world: GameWorld, engine: SimulationEngine, library: ContentLibrary) -> ScenarioSummary? {
        guard let s = world.scenario else { return nil }
        var summary = ScenarioSummary()
        summary.id = s.id
        summary.name = s.name
        summary.holdDays = s.holdDays
        summary.streak = s.streak
        summary.result = s.result
        let live = s.result == nil ? Scenarios.measured(world: world, engine: engine) : s.measured
        summary.rows = zip(s.objectives, live).map { objective, value in
            let met = objective.isMet(by: value)
            let fraction: Double
            if met { fraction = 1 } else if let value, objective.target > 0 {
                fraction = objective.metric.isUpperLimit ? min(objective.target / max(value, 1), 1) : min(max(value / objective.target, 0), 1)
            } else { fraction = 0 }
            return Row(label: label(objective, library: library), current: value.map { format($0, objective.metric, library: library) } ?? "—",
                       met: met, fraction: fraction)
        }
        summary.daysLeft = s.result == nil ? max(Int(s.deadlineDay - SimClock.day(world.clock.tick)), 0) : 0
        return summary
    }

    /// "Units let ≥ 12", "Average elevator wait ≤ 45 s", "Building class ≥ Class A".
    public static func label(_ o: ScenarioObjective, library: ContentLibrary) -> String {
        let op = o.metric.isUpperLimit ? "≤" : "≥"
        return "\(name(of: o.metric)) \(op) \(format(o.target, o.metric, library: library))"
    }

    public static func name(of metric: ScenarioMetric) -> String {
        switch metric {
        case .population: "Population"
        case .occupiedUnits: "Units let"
        case .cash: "Cash"
        case .dailyProfit: "Daily profit"
        case .buildingClass: "Building class"
        case .reputation: "Reputation"
        case .averageWait: "Average elevator wait"
        case .properties: "Properties"
        }
    }

    static func format(_ value: Double, _ metric: ScenarioMetric, library: ContentLibrary) -> String {
        switch metric {
        case .cash, .dailyProfit: Money.format(Int(value.rounded()))
        case .buildingClass:
            library.buildingClasses.indices.contains(Int(value)) ? library.buildingClasses[Int(value)].name : "\(Int(value))"
        case .averageWait: "\(Int(value.rounded())) s"
        case .population, .occupiedUnits, .reputation, .properties: "\(Int(value.rounded()))"
        }
    }
}

/// Browser entries: the scenario definitions with readable objectives.
public struct ScenarioBrief: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var summary: String
    public var briefing: String
    public var difficulty: String
    /// "Harbour Row, Saltmere · $1,500,000 · 30 days"
    public var setting: String
    public var objectives: [String]
    public var holdDays: Int

    public static func all(library: ContentLibrary) -> [ScenarioBrief] {
        library.orderedScenarios.compactMap { s in
            guard let start = library.start(s.startID), let city = library.city(start.cityID) else { return nil }
            let cash = s.startingCash ?? start.startingCash ?? 0
            return ScenarioBrief(id: s.id, name: s.name, summary: s.summary, briefing: s.briefing, difficulty: s.difficulty.rawValue.capitalized,
                                 setting: "\(start.propertyName), \(city.name) · \(Money.format(cash)) · \(s.days) days",
                                 objectives: s.objectives.map { ScenarioSummary.label($0, library: library) }, holdDays: s.holdDays ?? 1)
        }
    }
}
