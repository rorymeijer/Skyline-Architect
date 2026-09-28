import Foundation
import SkylineCore

/// What the weather looks like at an instant (Phase 13), derived from the saved weather
/// state and the content's look parameters. Pure presentation.
public struct WeatherLook: Equatable, Sendable {
    public enum Precipitation: String, Sendable { case rain, snow }

    public var cloud = 0.0
    public var fog = 0.0
    public var precipitation: Precipitation?
    public var intensity = 0.0
    /// Brightness of a lightning flash at this instant (0 = none).
    public var lightning = 0.0
    public var heat = 0.0
    /// Snow lying on roofs and pavement (0…1).
    public var snowCover = 0.0
    /// Wet paving (0…1).
    public var wet = 0.0

    public init() {}
    public static let clear = WeatherLook()
}

public enum WeatherView {
    /// Game seconds over which the look changes from yesterday's weather to today's after
    /// the 06:00 change.
    static let transition = 2700.0

    public static func look(state: WeatherState?, rules: WeatherRules?, time: Double) -> WeatherLook {
        guard let state, let rules, let today = rules.kind(state.today) else { return .clear }
        let yesterday = rules.kind(state.yesterday) ?? today
        let sinceChange = (time + Double(SimClock.startSecondOfDay)).truncatingRemainder(dividingBy: Double(SimClock.secondsPerDay))
            - Double(SimClock.startSecondOfDay)
        let t = sinceChange >= 0 ? min(sinceChange / transition, 1) : 1       // 06:00 → 06:45
        func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        var l = WeatherLook()
        l.cloud = mix(yesterday.look.cloud, today.look.cloud)
        l.fog = mix(yesterday.look.fog, today.look.fog)
        l.heat = mix(yesterday.look.heat ? 1 : 0, today.look.heat ? 1 : 0)
        if let p = today.look.precipitation.flatMap(WeatherLook.Precipitation.init(rawValue:)) {
            l.precipitation = p
            l.intensity = today.look.intensity * (yesterday.look.precipitation == today.look.precipitation ? 1 : t)
        }
        if today.look.lightning { l.lightning = flash(at: time) }
        let snowing = today.look.precipitation == "snow", snowedYesterday = yesterday.look.precipitation == "snow"
        l.snowCover = snowing ? 0.5 + 0.5 * t : (snowedYesterday && state.temperature <= 3 ? 0.6 : 0)
        let raining = today.look.precipitation == "rain", rainedYesterday = yesterday.look.precipitation == "rain"
        l.wet = raining ? 1 : (rainedYesterday ? 0.4 * (1 - t) + (today.look.cloud > 0.5 ? 0.3 : 0) : 0)
        return l
    }

    /// Lightning: in each 40-game-second window there is a 25 % chance of a strike at a
    /// random moment, fading over 3 s. Deterministic in game time.
    static func flash(at time: Double) -> Double {
        let window = (time / 40).rounded(.down)
        var rng = SeededRandom(seed: UInt64(max(window, 0)), stream: 0xB01)
        guard rng.chance(0.25) else { return 0 }
        let start = window * 40 + rng.double(in: 0..<37)
        let age = time - start
        return age >= 0 && age < 3 ? 1 - age / 3 : 0
    }

    /// The day's grade adjusted for the weather: clouds grey and darken it, fog whitens it,
    /// heat warms it.
    public static func grade(_ g: Grade, look l: WeatherLook) -> Grade {
        func adjust(_ c: RGBA, _ horizon: Bool) -> RGBA {
            let lum = 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
            var out = c.mixed(with: RGBA(lum, lum, lum * 1.04), l.cloud * 0.55)
            out = RGBA(out.r * (1 - 0.3 * l.cloud), out.g * (1 - 0.3 * l.cloud), out.b * (1 - 0.26 * l.cloud))
            out = out.mixed(with: RGBA(0.9 * lum + 0.1, 0.92 * lum + 0.1, 0.95 * lum + 0.1), l.fog * (horizon ? 0.45 : 0.25))
            return out.mixed(with: RGBA(1.0, 0.9, 0.74), l.heat * (horizon ? 0.3 : 0.15))
        }
        return Grade(top: adjust(g.top, false), bottom: adjust(g.bottom, true))
    }

    /// How dark it looks for lights: storms and fog switch lights on in daytime.
    public static func darkness(daylight: Double, look l: WeatherLook) -> Double {
        max(1 - daylight, l.cloud * 0.35 + l.fog * 0.15)
    }

    /// Street level within `visible` outside the buildings' foundations (x ranges), where
    /// snow lies and rain wets the paving.
    public static func pavement(world: GameWorld, propertyID: PropertyID, visible: Rect) -> [ClosedRange<Double>] {
        let grid = world.grid
        let blocked = world.buildings(on: propertyID).map {
            (grid.x(ofColumn: $0.footprint.start) - 0.8)...(grid.x(ofColumn: $0.footprint.end) + 0.8)
        }.sorted { $0.lowerBound < $1.lowerBound }
        var out: [ClosedRange<Double>] = []
        var x = visible.minX - 10
        for b in blocked where b.upperBound > x {
            if b.lowerBound > x { out.append(x...min(b.lowerBound, visible.maxX + 10)) }
            x = max(x, b.upperBound)
        }
        if x < visible.maxX + 10 { out.append(x...(visible.maxX + 10)) }
        return out.filter { $0.upperBound > $0.lowerBound }
    }

    /// Roof segments of the property's buildings (plate parts with no plate right above),
    /// where snow settles.
    public static func roofs(world: GameWorld, propertyID: PropertyID) -> [Rect] {
        let grid = world.grid
        var out: [Rect] = []
        for b in world.buildings(on: propertyID) {
            for plate in b.floors where plate.level >= 0 {
                let above = b.plate(at: plate.level + 1)?.span
                let top = grid.y(ofFloor: plate.level + 1)
                var pieces: [ColumnSpan] = [plate.span]
                if let above {
                    pieces = []
                    if above.start > plate.span.start { pieces.append(ColumnSpan(start: plate.span.start, count: above.start - plate.span.start)) }
                    if above.end < plate.span.end { pieces.append(ColumnSpan(start: above.end, count: plate.span.end - above.end)) }
                }
                for p in pieces where p.count > 0 {
                    // Drawn thicker than real snow so it reads at building zoom.
                    out.append(Rect(minX: grid.x(ofColumn: p.start) - 0.1, minY: top, maxX: grid.x(ofColumn: p.end) + 0.1, maxY: top + 0.6))
                }
            }
        }
        return out
    }
}
