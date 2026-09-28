import Foundation
import SkylineCore

/// How today's weather acts on the simulation (Phase 13). All effects are content
/// multipliers of a city's `WeatherState`; without weather rules everything is 1. Every city
/// has its own weather (save format 14); a building feels the weather of its city.
extension SimulationEngine {
    func weatherKind(_ city: City?) -> WeatherKind? {
        guard let rules = rules.weather, let state = city?.weather else { return nil }
        return rules.kind(state.today)
    }

    /// Starts the weather in every city that has none yet, on the current day.
    func startWeatherIfNeeded(_ world: inout GameWorld) {
        guard let rules = rules.weather else { return }
        let day = Int(SimClock.day(world.clock.tick))
        for city in world.cities.values where city.weather == nil {
            world.setWeather(Weather.initial(day: day, seed: Weather.seed(of: city), rules: rules), city: city.id)
        }
    }

    /// The 06:00 step, after the closing: tomorrow becomes today in every city.
    func advanceWeather(_ world: inout GameWorld) {
        guard let rules = rules.weather else { return }
        for city in world.cities.values {
            guard let state = city.weather else { continue }
            world.setWeather(Weather.next(state, seed: Weather.seed(of: city), rules: rules), city: city.id)
        }
    }

    /// Utilities multiplier for heating or cooling at today's temperature in `city`.
    func energyFactor(_ city: City?) -> Double {
        guard let rules = rules.weather, let state = city?.weather else { return 1 }
        return 1 + rules.energyPerDegree * abs(state.temperature - rules.comfortTemperature)
    }
}
