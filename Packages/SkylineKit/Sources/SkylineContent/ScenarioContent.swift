import Foundation
import SkylineCore

/// `scenarios.json` (Phase 16): a start, a time limit and objectives. See SCENARIOS.md.
public struct ScenarioDefinition: Codable, Hashable, Sendable, Identifiable {
    public enum Difficulty: String, Codable, Sendable { case easy, medium, hard }

    public var id: String
    public var name: String
    /// One line for the browser list.
    public var summary: String
    /// The briefing shown before starting.
    public var briefing: String
    public var difficulty: Difficulty
    /// The start (`starts.json`) the scenario begins from.
    public var startID: String
    /// Replaces the start's cash when set.
    public var startingCash: Int?
    /// Game days available; the closing of the last day is the last chance to win.
    public var days: Int
    /// Closings in a row every objective must hold (default 1).
    public var holdDays: Int?
    public var objectives: [ScenarioObjective]
    /// What the scenario forbids (Phase C).
    public var restrictions: ScenarioRestrictions?
    /// Scripted events and scoring (Phase C).
    public var events: [ScenarioEvent]?
    public var scoring: ScenarioScoring?
    /// Guided steps (F3): a tutorial scenario shows the first step not yet done.
    public var tutorial: [TutorialStep]?
}

extension ContentLibrary {
    public func scenario(_ id: String) -> ScenarioDefinition? { orderedScenarios.first { $0.id == id } }

    mutating func register(scenarios: [ScenarioDefinition]) throws {
        let file = manifest.files["scenarios"] ?? "scenarios"
        var ids = Set<String>()
        for s in scenarios {
            func fail(_ m: String) -> ContentError { ContentError(pack: manifest.id, file: file, message: "Scenario '\(s.id)': \(m)") }
            guard ids.insert(s.id).inserted else { throw fail("duplicate id") }
            guard start(s.startID) != nil else { throw fail("unknown start '\(s.startID)'") }
            guard s.days >= 1 else { throw fail("days must be ≥ 1") }
            let hold = s.holdDays ?? 1
            guard (1...s.days).contains(hold) else { throw fail("holdDays must be 1…days") }
            guard (s.startingCash ?? 0) >= 0 else { throw fail("startingCash must be ≥ 0") }
            guard !s.objectives.isEmpty else { throw fail("needs at least one objective") }
            for o in s.objectives {
                switch o.metric {
                case .buildingClass:
                    guard o.target >= 1, Int(o.target) < buildingClasses.count, o.target == o.target.rounded() else {
                        throw fail("buildingClass target must be a class index 1…\(buildingClasses.count - 1)")
                    }
                case .reputation:
                    guard (0...100).contains(o.target) else { throw fail("reputation target must be 0…100") }
                case .averageWait, .population, .occupiedUnits, .properties:
                    guard o.target > 0 else { throw fail("\(o.metric.rawValue) target must be positive") }
                case .cash, .dailyProfit:
                    break
                }
            }
            if let r = s.restrictions {
                let roomIDs = Set(orderedRooms.map(\.id))
                if let bad = r.forbiddenRooms?.first(where: { !roomIDs.contains($0) }) { throw fail("forbids unknown room '\(bad)'") }
                guard (r.maxFloor ?? 1) >= 1, (r.maxLoans ?? 0) >= 0 else { throw fail("maxFloor must be ≥ 1 and maxLoans ≥ 0") }
            }
            let tenantIDs = Set(simulationRules.tenantTypes.map(\.id))
            let weatherIDs = Set(simulationRules.weather?.kinds.map(\.id) ?? [])
            for (i, e) in (s.events ?? []).enumerated() {
                func bad(_ m: String) -> ContentError { fail("event \(i + 1): \(m)") }
                guard (1...s.days).contains(e.day), (0...23).contains(e.hour ?? 9) else { throw bad("day must be 1…days and hour 0…23") }
                guard !e.message.isEmpty else { throw bad("needs a message") }
                switch e.kind {
                case .news, .fire: break
                case .demand:
                    guard let m = e.multiplier, (0...10).contains(m), (e.days ?? 0) >= 1 else { throw bad("demand needs multiplier 0…10 and days ≥ 1") }
                    if let t = e.tenantType, !tenantIDs.contains(t) { throw bad("unknown tenant type '\(t)'") }
                case .grant, .fine:
                    guard (e.amount ?? 0) > 0 else { throw bad("\(e.kind.rawValue) needs a positive amount") }
                case .weather:
                    guard let w = e.weather, weatherIDs.contains(w) else { throw bad("unknown weather '\(e.weather ?? "")'") }
                }
            }
            if let problem = tutorialProblems(s.tutorial ?? []).first { throw fail(problem) }
            orderedScenarios.append(s)
        }
    }
}

extension NewGameFactory {
    /// A new game playing a scenario: the scenario's start (with its cash, if set) and the
    /// objectives copied into the world.
    public static func make(scenarioID: String, library: ContentLibrary) throws -> NewGame {
        guard let scenario = library.scenario(scenarioID) else {
            throw ContentError(pack: library.manifest.id, file: "scenarios", message: "Unknown scenario '\(scenarioID)'")
        }
        var game = try make(startID: scenario.startID, library: library, cash: scenario.startingCash)
        let startDay = SimClock.day(game.world.clock.tick)
        game.world.scenario = ScenarioState(id: scenario.id, name: scenario.name, objectives: scenario.objectives,
                                            deadlineDay: startDay + Tick(scenario.days), holdDays: scenario.holdDays ?? 1)
        game.world.scenario?.restrictions = scenario.restrictions
        game.world.scenario?.startDay = startDay
        game.world.scenario?.events = scenario.events
        game.world.scenario?.scoring = scenario.scoring
        game.scenarioID = scenario.id
        return game
    }
}
