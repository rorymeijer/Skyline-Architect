import Foundation
import SkylineCore

/// Today's weather and the forecast for the UI (Phase 13).
public struct WeatherSummary: Equatable, Sendable {
    public var name = ""
    public var symbol = "sun.max"
    public var temperature = 0
    public var season = ""
    public var tomorrowName = ""
    public var tomorrowSymbol = "sun.max"
    /// Simulation effects today, in words ("prospects −55 %, wear ×2.5, …"); empty = none.
    public var effects = ""

    public init() {}

    /// The weather in `city` (the city of the property on screen).
    public static func make(city: City?, rules: SimulationRules) -> WeatherSummary? {
        guard let w = rules.weather, let state = city?.weather, let today = w.kind(state.today) else { return nil }
        var s = WeatherSummary()
        s.name = today.name
        s.symbol = today.symbol
        s.temperature = Int(state.temperature)
        s.season = Weather.season(ofDay: state.day, rules: w).name
        if let tomorrow = w.kind(state.tomorrow) {
            s.tomorrowName = tomorrow.name
            s.tomorrowSymbol = tomorrow.symbol
        }
        let e = today.effects
        var parts: [String] = []
        if e.demand != 1 { parts.append(String(format: "prospects %+.0f %%", (e.demand - 1) * 100)) }
        if e.wear != 1 { parts.append(String(format: "wear ×%.1f", e.wear)) }
        if e.dirt != 1 { parts.append(String(format: "dirt ×%.1f", e.dirt)) }
        let energy = 1 + w.energyPerDegree * abs(state.temperature - w.comfortTemperature)
        if energy > 1.05 { parts.append(String(format: "utilities ×%.2f", energy)) }
        s.effects = parts.joined(separator: ", ")
        return s
    }
}
