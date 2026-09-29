import Foundation
import SkylineCore

/// Scripted scenario events and scoring (Phase C). See SCENARIOS.md.
extension SimulationEngine {
    /// The tick at which an event of a scenario that began on `startDay` is due.
    static func dueTick(_ event: ScenarioEvent, startDay: Tick) -> Tick {
        let absolute = (startDay + Tick(max(event.day, 1) - 1)) * SimClock.secondsPerDay + Tick(event.hour ?? 9) * 3600
        return absolute > SimClock.startSecondOfDay ? absolute - SimClock.startSecondOfDay : 0
    }

    /// Hourly (with the market step): fires every due event once, in content order. Nothing
    /// fires once the scenario is decided.
    func scenarioEvents(at now: Tick, world: inout GameWorld, events: inout Events) {
        guard var s = world.scenario, s.result == nil, let scripted = s.events, !scripted.isEmpty else { return }
        let start = s.startDay ?? 0
        var fired = s.fired ?? []
        var news = s.news ?? []
        var shocks = (s.shocks ?? []).filter { $0.untilDay > SimClock.day(now) }
        for (i, event) in scripted.enumerated() where !fired.contains(i) && Self.dueTick(event, startDay: start) <= now {
            fired.append(i)
            var text = event.message
            switch event.kind {
            case .news:
                break
            case .demand:
                shocks.append(DemandShock(tenantType: event.tenantType, multiplier: event.multiplier ?? 1,
                                          untilDay: SimClock.day(now) + Tick(event.days ?? 1)))
            case .grant, .fine:
                let met = event.when.map { $0.isMet(by: Scenarios.measure($0.metric, world: world, engine: self)) } ?? (event.kind == .grant)
                let applies = event.kind == .grant ? met : !met
                let amount = event.amount ?? 0
                if applies {
                    world.ledger.post(Transaction(tick: now, amount: event.kind == .grant ? amount : -amount, category: .grant,
                                                  detail: (event.kind == .grant ? "Subsidy — " : "Fine — ") + event.message))
                } else {
                    text += event.kind == .grant ? " — not earned this time." : " — passed, no fine."
                }
            case .weather:
                if let kind = event.weather, let city = world.cities.values.first {
                    let today = city.weather
                    let hot = kind == "heat"
                    world.setWeather(WeatherState(day: today?.day ?? Int(SimClock.day(now)), yesterday: today?.yesterday ?? kind, today: kind,
                                                  tomorrow: today?.tomorrow ?? "clear",
                                                  temperature: hot ? max(today?.temperature ?? 30, 34) : today?.temperature ?? 15), city: city.id)
                }
            case .fire:
                if let building = world.buildings.values.first {
                    let rooms = world.rooms(in: building.id).filter { catalog.spec($0.definitionID)?.rentPerModule != nil }
                    if !rooms.isEmpty {
                        var rng = SeededRandom(seed: UInt64(building.id.raw), stream: 0xF1AE &+ UInt64(i))
                        ignite(rooms[rng.int(in: 0..<rooms.count)].id, at: now, world: &world, events: &events)
                    }
                }
            }
            news.append(ScenarioNews(tick: now, text: text))
        }
        s = world.scenario ?? s
        s.fired = fired
        s.news = news
        s.shocks = shocks
        world.scenario = s
    }

    /// Tenant demand from running scripted shocks for a tenant type (1 = none).
    func scenarioDemand(for typeID: String, at now: Tick, world: GameWorld) -> Double {
        guard let shocks = world.scenario?.shocks, world.scenario?.result == nil else { return 1 }
        let day = SimClock.day(now)
        return shocks.reduce(1) { $0 * ($1.untilDay > day && ($1.tenantType == nil || $1.tenantType == typeID) ? $1.multiplier : 1) }
    }

    /// Stars and points of a decided scenario (see `ScenarioScoring`).
    func score(_ s: ScenarioState, won: Bool, at now: Tick, world: GameWorld) -> (stars: Int, score: Int) {
        let rules = s.scoring ?? ScenarioScoring()
        func progress(_ o: ScenarioObjective, _ value: Double?) -> Double {
            guard let value, o.target != 0 else { return o.isMet(by: value) ? 1 : 0 }
            return o.metric.isUpperLimit ? o.target / max(value, 0.001) : value / o.target
        }
        let ratios = zip(s.objectives, s.measured).map { progress($0, $1) }
        guard won else {
            return (0, Int((ratios.reduce(0) { $0 + min(max($1, 0), 1) } * 100).rounded()))
        }
        let days = Double(max(Int(s.deadlineDay) - Int(s.startDay ?? 0), 1))
        let used = Double(Int(SimClock.day(now)) - Int(s.startDay ?? 0))
        let daysLeft = max(Int(s.deadlineDay) - Int(SimClock.day(now)), 0)
        var stars = 1
        if s.startDay != nil, used <= rules.fast * days { stars += 1 }
        if ratios.allSatisfy({ $0 >= 1 + rules.beat }) { stars += 1 }
        let overshoot = ratios.reduce(0.0) { $0 + min(max($1 - 1, 0), 1) * Double(rules.overshoot) }
        let reputation = world.buildings.values.map(\.standing.reputation).max() ?? 0
        let points = Double(rules.win) + Double(rules.perDayLeft * daysLeft) + overshoot + rules.reputation * reputation
        return (stars, Int(points.rounded()))
    }
}
