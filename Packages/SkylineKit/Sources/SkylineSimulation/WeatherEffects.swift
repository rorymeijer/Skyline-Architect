import Foundation
import SkylineCore

/// How today's weather acts on the simulation (Phase 13). All effects are content
/// multipliers of the current `WeatherState`; without weather rules everything is 1.
extension SimulationEngine {
    func weatherKind(_ world: GameWorld) -> WeatherKind? {
        guard let rules = rules.weather, let state = world.weather else { return nil }
        return rules.kind(state.today)
    }

    /// Starts the weather in a world that has none yet, on its current day.
    func startWeatherIfNeeded(_ world: inout GameWorld) {
        guard let rules = rules.weather, world.weather == nil else { return }
        let day = Int(SimClock.day(world.clock.tick))
        world.weather = Weather.initial(day: day, seed: weatherSeed(world), rules: rules)
    }

    /// The 06:00 step, after the closing: tomorrow becomes today.
    func advanceWeather(_ world: inout GameWorld) {
        guard let rules = rules.weather, let state = world.weather else { return }
        world.weather = Weather.next(state, seed: weatherSeed(world), rules: rules)
    }

    func weatherSeed(_ world: GameWorld) -> UInt64 { Weather.seed(of: world) }

    /// Utilities multiplier for heating or cooling at today's temperature.
    func energyFactor(_ world: GameWorld) -> Double {
        guard let rules = rules.weather, let state = world.weather else { return 1 }
        return 1 + rules.energyPerDegree * abs(state.temperature - rules.comfortTemperature)
    }
}
