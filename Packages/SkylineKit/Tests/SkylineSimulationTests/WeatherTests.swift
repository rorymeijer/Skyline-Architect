import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylineSimulation

@Suite struct WeatherGenerationTests {
    let rules = try! ContentLibrary.loadBase().simulationRules.weather!

    func year(seed: UInt64, days: Int = 56) -> [WeatherState] {
        var s = Weather.initial(seed: seed, rules: rules)
        var out = [s]
        for _ in 1..<days { s = Weather.next(s, seed: seed, rules: rules); out.append(s) }
        return out
    }

    @Test func seasonsCycleFromSummer() {
        #expect(Weather.season(ofDay: 0, rules: rules).id == "summer")
        #expect(Weather.season(ofDay: 7, rules: rules).id == "autumn")
        #expect(Weather.season(ofDay: 14, rules: rules).id == "winter")
        #expect(Weather.season(ofDay: 21, rules: rules).id == "spring")
        #expect(Weather.season(ofDay: 28, rules: rules).id == "summer")
    }

    /// Two years: every kind occurs, only in the seasons that allow it; the forecast comes
    /// true; the same seed repeats exactly.
    @Test func weatherFollowsTheClimateAndTheForecast() {
        let days = year(seed: 7301)
        #expect(days == year(seed: 7301))
        #expect(days.map(\.today) != year(seed: 42).map(\.today))
        for (a, b) in zip(days, days.dropFirst()) {
            #expect(b.day == a.day + 1 && b.today == a.tomorrow && b.yesterday == a.today)
        }
        for s in days {
            let season = Weather.season(ofDay: s.day, rules: rules).id
            #expect((rules.kind(s.today)?.weights[season] ?? 0) > 0, "\(s.today) in \(season)")
        }
        let seen = Set((0..<20).flatMap { year(seed: UInt64($0)) }.map(\.today))
        #expect(seen == Set(rules.kinds.map(\.id)))
        let winter = days.filter { Weather.season(ofDay: $0.day, rules: rules).id == "winter" }.map(\.temperature)
        let summer = days.filter { Weather.season(ofDay: $0.day, rules: rules).id == "summer" }.map(\.temperature)
        #expect(winter.max()! < summer.min()! + 8)
        #expect(winter.reduce(0, +) / Double(winter.count) < summer.reduce(0, +) / Double(summer.count) - 10)
        print("[weather] seed 7301: " + days.prefix(28).map { "\($0.today) \(Int($0.temperature))°" }.joined(separator: ", "))
    }
}

@Suite struct WeatherEffectTests {
    /// The world's weather advances at each closing and matches the game day.
    @Test func weatherAdvancesWithTheDays() throws {
        var f = try SimFixture()
        let start = try #require(f.world.weather)
        #expect(start.day == 0)
        f.run(until: "07:00", day: 3)
        let now = try #require(f.world.weather)
        #expect(now.day == 3 && Int(SimClock.day(f.world.clock.tick)) == 3)
        #expect(now == Weather.next(Weather.next(Weather.next(start, seed: Weather.seed(of: f.world), rules: f.engine.rules.weather!),
                                                 seed: Weather.seed(of: f.world), rules: f.engine.rules.weather!),
                                    seed: Weather.seed(of: f.world), rules: f.engine.rules.weather!))
    }

    /// Older saves have no weather: it starts on their current day.
    @Test func weatherStartsInOlderGames() throws {
        var f = try SimFixture()
        f.run(until: "12:00", day: 5)
        f.world.weather = nil
        f.engine.advance(&f.world, by: 1)
        #expect(f.world.weather?.day == 5)
    }

    func forcing(_ kind: String, temperature: Double = 19, hours: Tick = 23, leased: Bool = false) throws -> SimFixture {
        var f = try SimFixture()
        if !leased { for t in f.world.tenants.values { Leasing.moveOut(t.id, world: &f.world) } }
        f.world.weather = WeatherState(day: 0, yesterday: kind, today: kind, tomorrow: kind, temperature: temperature)
        f.engine.advance(&f.world, by: hours * 3600)
        return f
    }

    @Test func stormsKeepProspectsAway() throws {
        let clear = try forcing("clear"), storm = try forcing("storm")
        print("[weather] prospects in 23 h: clear \(clear.world.market.prospects), storm \(storm.world.market.prospects)")
        #expect(storm.world.market.prospects < clear.world.market.prospects)
    }

    /// Heating and cooling: the utilities line grows by 3 % per degree from 19 °C.
    @Test func extremeTemperaturesRaiseTheUtilitiesBill() throws {
        func utilities(_ t: Double) throws -> Int {
            let f = try forcing("clear", temperature: t, hours: 25, leased: true)
            return -(try #require(f.world.ledger.journal.first { $0.detail.hasPrefix("Utilities") }).amount)
        }
        let mild = try utilities(19), hot = try utilities(35), cold = try utilities(-1)
        #expect(abs(Double(hot) / Double(mild) - 1.48) < 0.02)
        #expect(abs(Double(cold) / Double(mild) - 1.60) < 0.02)
    }

    /// A stormy day wears the building and brings in dirt faster than a clear one.
    @Test func stormsWearAndDirty() throws {
        let clear = try forcing("clear", hours: 25, leased: true), storm = try forcing("storm", hours: 25, leased: true)
        func mean(_ f: SimFixture, _ v: (Upkeep) -> Double) -> Double {
            f.world.upkeep.values.reduce(0) { $0 + v($1) } / Double(f.world.upkeep.count)
        }
        #expect(mean(storm, \.condition) < mean(clear, \.condition))
        #expect(mean(storm, \.cleanliness) < mean(clear, \.cleanliness))
    }
}
