import Foundation
import SkylineCore

/// Scenario objectives (Phase 16): measured over the whole estate at every daily closing.
/// See SCENARIOS.md.
public enum Scenarios {
    /// Ledger categories that make up the daily operating result.
    static let operating: [LedgerCategory] = [.rent, .turnover, .hotel, .maintenance, .utilities, .wages, .interest, .taxes, .waste]

    /// The current value of a metric (nil when there is nothing to measure yet).
    public static func measure(_ metric: ScenarioMetric, world: GameWorld, engine: SimulationEngine) -> Double? {
        switch metric {
        case .population:
            return Double(world.people.values.reduce(0) { $0 + ($1.tenantID != nil ? 1 : 0) })
        case .occupiedUnits:
            return Double(Set(world.tenants.values.map(\.room)).count)
        case .cash:
            return Double(world.ledger.cash)
        case .dailyProfit:
            // The closing posts at the start of a day, so "today" holds the last closing (a day
            // without any transaction had a result of 0).
            let today = SimClock.day(world.clock.tick)
            let day = world.ledger.days.last(where: { $0.day == today }) ?? DayTotals(day: today)
            return Double(operating.reduce(0) { $0 + day.amount($1) })
        case .buildingClass:
            return world.buildings.values.map { Double($0.standing.classLevel) }.max()
        case .reputation:
            return world.buildings.values.map(\.standing.reputation).max()
        case .averageWait:
            var boardings = 0, waited = 0.0
            for building in world.buildings.values {
                for bank in engine.banks(of: building.id, in: world) {
                    let s = ElevatorBanks.stats(of: bank, in: world)
                    guard s.boardings >= 10 else { continue }
                    boardings += s.boardings
                    waited += s.averageWait * Double(s.boardings)
                }
            }
            return boardings > 0 ? waited / Double(boardings) : nil
        case .properties:
            return Double(world.properties.count)
        }
    }

    /// Measures every objective of the world's scenario (no result is decided).
    public static func measured(world: GameWorld, engine: SimulationEngine) -> [Double?] {
        world.scenario?.objectives.map { measure($0.metric, world: world, engine: engine) } ?? []
    }
}

extension SimulationEngine {
    /// Morning step after the closing and the standing update: measure the objectives; win
    /// when all have held for `holdDays` closings in a row; lose on bankruptcy or when the
    /// deadline day's closing passes without a win. Decided once, then left alone.
    func scenarioDaily(at now: Tick, world: inout GameWorld) {
        guard var s = world.scenario, s.result == nil else { return }
        s.measured = Scenarios.measured(world: world, engine: self)
        s.streak = s.allMet ? s.streak + 1 : 0
        if s.streak >= s.holdDays {
            s.result = ScenarioResult(won: true, tick: now, reason: "Every objective met")
        } else if world.ledger.bankrupt {
            s.result = ScenarioResult(won: false, tick: now, reason: "Bankrupt")
        } else if SimClock.day(now) >= s.deadlineDay {
            s.result = ScenarioResult(won: false, tick: now, reason: "Time ran out")
        }
        if let result = s.result {                         // Phase C: stars and points
            let scored = score(s, won: result.won, at: now, world: world)
            s.result?.stars = scored.stars
            s.result?.score = scored.score
        }
        world.scenario = s
    }
}
