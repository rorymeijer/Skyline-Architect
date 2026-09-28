import Foundation

/// A kind of weather (`weather.json`, Phase 13): how likely it is per season, what it does
/// to the simulation and how it looks. Shared by the simulation and the renderer.
public struct WeatherKind: Codable, Hashable, Sendable {
    /// Simulation effects (multipliers; 1 = none).
    public struct Effects: Codable, Hashable, Sendable {
        /// Prospective tenants who come by.
        public var demand: Double
        /// Wear of rooms and equipment.
        public var wear: Double
        /// Dirt brought in.
        public var dirt: Double
        /// Degrees added to the season's temperature.
        public var temperature: Double
    }

    /// Visual parameters (0…1 unless noted).
    public struct Look: Codable, Hashable, Sendable {
        /// Cloud cover: greys and darkens the day.
        public var cloud: Double
        public var fog: Double
        /// "rain", "snow" or nil.
        public var precipitation: String?
        public var intensity: Double
        public var lightning: Bool
        /// Warm, bright haze.
        public var heat: Bool
    }

    public var id: String
    public var name: String
    /// SF Symbol name for the UI (presentation hint; content stays platform-neutral text).
    public var symbol: String
    /// Relative likelihood per season id.
    public var weights: [String: Double]
    public var effects: Effects
    public var look: Look
    /// Chance this weather lasts another day (nil = the climate's `persistence`).
    public var persistence: Double?
}

/// The climate: seasons, the kinds of weather and how days follow each other.
public struct WeatherRules: Codable, Hashable, Sendable {
    public struct Season: Codable, Hashable, Sendable {
        public var id: String
        public var name: String
        /// Typical daytime temperature, °C.
        public var temperature: Double
    }

    /// Seasons in order; the year is split evenly between them.
    public var seasons: [Season]
    public var daysPerYear: Int
    /// Season the game starts in (day 0 is its first day).
    public var startSeason: String
    public var kinds: [WeatherKind]
    /// Chance that tomorrow keeps today's weather (if the season allows it).
    public var persistence: Double
    /// Random spread of the daily temperature, ± °C.
    public var temperatureSpread: Double
    /// Heating and cooling: the utilities bill grows by this fraction per degree away from
    /// `comfortTemperature`.
    public var energyPerDegree: Double
    public var comfortTemperature: Double

    public func kind(_ id: String) -> WeatherKind? { kinds.first { $0.id == id } }

    /// Validation problems (empty if valid).
    public var problems: [String] {
        var p: [String] = []
        if seasons.isEmpty || daysPerYear < seasons.count { p.append("weather: need seasons and daysPerYear ≥ seasons") }
        if !seasons.contains(where: { $0.id == startSeason }) { p.append("weather: unknown startSeason '\(startSeason)'") }
        if kinds.isEmpty { p.append("weather: no kinds") }
        var ids = Set<String>()
        for k in kinds {
            if !ids.insert(k.id).inserted { p.append("weather '\(k.id)' defined twice") }
            for key in k.weights.keys.sorted() where !seasons.contains(where: { $0.id == key }) { p.append("weather '\(k.id)': unknown season '\(key)'") }
            if k.weights.values.contains(where: { $0 < 0 }) { p.append("weather '\(k.id)': negative weight") }
            let e = k.effects
            if [e.demand, e.wear, e.dirt].contains(where: { $0 < 0 }) { p.append("weather '\(k.id)': effects must be ≥ 0") }
            let l = k.look
            if [l.cloud, l.fog, l.intensity].contains(where: { !(0...1).contains($0) }) { p.append("weather '\(k.id)': look values 0…1") }
            if let pr = l.precipitation, !["rain", "snow"].contains(pr) { p.append("weather '\(k.id)': precipitation rain or snow") }
            if let q = k.persistence, !(0...1).contains(q) { p.append("weather '\(k.id)': persistence 0…1") }
        }
        for s in seasons where !kinds.contains(where: { ($0.weights[s.id] ?? 0) > 0 }) { p.append("weather: season '\(s.id)' has no weather") }
        if !(0...1).contains(persistence) || temperatureSpread < 0 || energyPerDegree < 0 { p.append("weather: persistence 0…1, spread and energy ≥ 0") }
        return p
    }
}

/// Weather of the current game day and the forecast in one city (Phase 13; per city since
/// save format 14). Saved; advanced by the simulation at every 06:00 closing,
/// deterministically from the city seed and the day.
public struct WeatherState: Codable, Hashable, Sendable {
    /// Game day `today` belongs to (day 0 starts at tick 0).
    public var day: Int
    public var yesterday: String
    public var today: String
    public var tomorrow: String
    /// Today's temperature, °C.
    public var temperature: Double

    public init(day: Int, yesterday: String, today: String, tomorrow: String, temperature: Double) {
        self.day = day
        self.yesterday = yesterday
        self.today = today
        self.tomorrow = tomorrow
        self.temperature = temperature
    }
}

/// Deterministic weather generation.
public enum Weather {
    /// The weather seed of a city. Each city draws its own days from it.
    public static func seed(of city: City) -> UInt64 { city.seed ^ 0x57EA_7E4 }

    /// A world-wide random seed (from the first city) for incident draws that are not
    /// about one city's weather.
    public static func seed(of world: GameWorld) -> UInt64 { world.cities.values.first.map(seed(of:)) ?? (1 ^ 0x57EA_7E4) }

    /// Season of a game day.
    public static func season(ofDay day: Int, rules: WeatherRules) -> WeatherRules.Season {
        let n = rules.seasons.count
        let start = rules.seasons.firstIndex { $0.id == rules.startSeason } ?? 0
        let length = max(rules.daysPerYear / n, 1)
        return rules.seasons[(start + day / length) % n]
    }

    /// The weather of `day`, given the day before: keeps it with `persistence` (if the
    /// season allows it), otherwise a weighted draw for the season. Pure function of the
    /// seed, the day and the previous kind.
    public static func draw(day: Int, previous: String?, seed: UInt64, rules: WeatherRules) -> String {
        let season = season(ofDay: day, rules: rules)
        var rng = SeededRandom(seed: seed, stream: 0x3EA7 &+ UInt64(day))
        if let previous, let kind = rules.kind(previous), (kind.weights[season.id] ?? 0) > 0,
           rng.chance(kind.persistence ?? rules.persistence) { return previous }
        let weighted = rules.kinds.map { ($0.id, $0.weights[season.id] ?? 0) }.filter { $0.1 > 0 }
        let total = weighted.reduce(0) { $0 + $1.1 }
        var pick = rng.unit() * total
        for (id, w) in weighted {
            if pick < w { return id }
            pick -= w
        }
        return weighted.last?.0 ?? rules.kinds[0].id
    }

    static func temperature(day: Int, kind: String, seed: UInt64, rules: WeatherRules) -> Double {
        var rng = SeededRandom(seed: seed, stream: 0x7E3B &+ UInt64(day))
        let base = season(ofDay: day, rules: rules).temperature + (rules.kind(kind)?.effects.temperature ?? 0)
        return (base + rng.double(in: -rules.temperatureSpread..<rules.temperatureSpread + 0.0001)).rounded()
    }

    /// The state for a game without weather yet (a new game, or an older save) on `day`.
    public static func initial(day: Int = 0, seed: UInt64, rules: WeatherRules) -> WeatherState {
        let today = draw(day: day, previous: nil, seed: seed, rules: rules)
        let tomorrow = draw(day: day + 1, previous: today, seed: seed, rules: rules)
        return WeatherState(day: day, yesterday: today, today: today, tomorrow: tomorrow,
                            temperature: temperature(day: day, kind: today, seed: seed, rules: rules))
    }

    /// The next day's state: tomorrow becomes today and a new forecast is drawn.
    public static func next(_ s: WeatherState, seed: UInt64, rules: WeatherRules) -> WeatherState {
        let day = s.day + 1
        let tomorrow = draw(day: day + 1, previous: s.tomorrow, seed: seed, rules: rules)
        return WeatherState(day: day, yesterday: s.today, today: s.tomorrow, tomorrow: tomorrow,
                            temperature: temperature(day: day, kind: s.tomorrow, seed: seed, rules: rules))
    }
}
