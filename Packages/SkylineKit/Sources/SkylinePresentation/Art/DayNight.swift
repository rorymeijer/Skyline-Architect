import Foundation
import SkylineCore

/// A light drawn over the world at night (world rectangle, 0…1 intensity, light colour).
public struct LitRoom: Hashable, Sendable {
    public var rect: Rect
    public var intensity: Double
    public var color: RGBA

    public init(rect: Rect, intensity: Double, color: RGBA = DayNight.lamp) {
        self.rect = rect
        self.intensity = intensity
        self.color = color
    }
}

/// Screen colour grading at a time of day: the scene is multiplied with a vertical
/// gradient from `bottom` (horizon) to `top`.
public struct Grade: Hashable, Sendable {
    public var top: RGBA
    public var bottom: RGBA
}

/// Day/night (Phases 9, 12): how much daylight there is at a time of day, the colour grade
/// the scene is multiplied with, and the lights drawn over it. Pure presentation; which
/// rooms are lit comes from the shared lighting model (`Lighting`, Core), which also drives
/// the simulation's energy meter.
public enum DayNight {
    /// 0 (night) … 1 (day): sunrise 04:45–06:15, sunset 19:00–21:00, smoothed (a summer
    /// day, so the game's 06:00 start is light).
    public static func daylight(secondOfDay s: Double) -> Double {
        let h = s / 3600
        if h < 12 { return smooth((h - 4.75) / 1.5) }
        return 1 - smooth((h - 19) / 2)
    }

    public static func daylight(atTick t: Double) -> Double {
        daylight(secondOfDay: secondOfDay(atTick: t))
    }

    static func secondOfDay(atTick t: Double) -> Double {
        (t + Double(SimClock.startSecondOfDay)).truncatingRemainder(dividingBy: Double(SimClock.secondsPerDay))
    }

    static func smooth(_ x: Double) -> Double { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }

    public static let lamp = RGBA(1.0, 0.82, 0.52)
    static let night = RGBA(0.26, 0.30, 0.50)
    static let dusk = RGBA(0.95, 0.72, 0.60)
    static let sunrise = RGBA(0.98, 0.80, 0.78)
    static let sunset = RGBA(0.99, 0.64, 0.42)

    /// Multiply colour for the whole scene: white by day, warm at the edges, blue at night.
    public static func ambient(daylight d: Double) -> RGBA {
        let warm = 1 - abs(d - 0.5) * 2                  // strongest at half light
        let base = night.mixed(with: RGBA(1, 1, 1), d)
        return base.mixed(with: dusk, warm * 0.35)
    }

    /// Colour grade (Phase 12): rose at sunrise, amber through the golden hour and sunset,
    /// warmest at the horizon; blue night above a slightly lighter horizon.
    public static func grade(atTick t: Double) -> Grade {
        let s = secondOfDay(atTick: t), h = s / 3600
        let d = daylight(secondOfDay: s)
        let base = night.mixed(with: RGBA(1, 1, 1), d)
        let twilight = 1 - abs(d - 0.5) * 2
        let golden = h > 12 ? smooth((h - 17.25) / 1.75) * 0.6 : 0     // before sunset
        let warm = max(twilight, golden * d)
        let tone = h < 12 ? sunrise : sunset
        let top = base.mixed(with: tone, warm * 0.18).mixed(with: night, twilight * 0.12)
        let bottom = base.mixed(with: tone, warm * 0.55).mixed(with: RGBA(1, 1, 1), (1 - d) * 0.08)
        return Grade(top: top, bottom: bottom)
    }

    /// Below this zoom (points per metre) lit rooms are drawn as window panes on the façade.
    public static let windowZoom = DetailLevel.thresholds[DetailLevel.floors.rawValue]

    /// Lights over the visible rooms at `time`: each room's level from the lighting model
    /// (occupancy, quiet hours, `power` = served electricity per room) × darkness. Zoomed out
    /// they become window panes (façade emission); close up, the whole room glows.
    public static func litRooms(world: GameWorld, propertyID: PropertyID, catalog: BuildCatalog, time: Double, visible: Rect,
                                zoom: Double = 20, power: [RoomID: Double] = [:]) -> [LitRoom] {
        let darkness = 1 - daylight(atTick: time)
        guard darkness > 0.02 else { return [] }
        let occupied = Lighting.occupiedRooms(world)
        let sod = Tick(secondOfDay(atTick: time))
        let grid = world.grid
        var lit: [LitRoom] = []
        for b in world.buildings(on: propertyID) {
            for room in world.rooms(in: b.id) {
                guard let spec = catalog.spec(room.definitionID), let lighting = spec.lighting else { continue }
                let rect = grid.rect(columns: room.columns, floors: room.floors)
                guard rect.intersects(visible) else { continue }
                let level = Lighting.level(lighting, room: room.id, occupied: occupied.contains(room.id), secondOfDay: sod,
                                           power: power[room.id] ?? 1)
                guard level > 0.01 else { continue }
                let color = ArtCatalog.parseColor(lighting.color) ?? lamp
                if zoom < windowZoom, room.floors.lowest >= 0 {
                    for pane in panes(of: rect, grid: grid) { lit.append(LitRoom(rect: pane, intensity: level * darkness, color: color)) }
                } else {
                    lit.append(LitRoom(rect: rect, intensity: level * darkness, color: color))
                }
            }
        }
        return lit
    }

    /// Window panes of a room seen from outside: one per 2 m, from sill to head, per storey.
    static func panes(of rect: Rect, grid: GridSpec) -> [Rect] {
        var out: [Rect] = []
        var y = rect.minY
        while y + 1 < rect.maxY {
            var x = rect.minX + 0.25
            while x + 1.5 <= rect.maxX - 0.15 {
                out.append(Rect(minX: x, minY: y + 0.9, maxX: x + 1.5, maxY: y + min(3.2, grid.floorHeight - 0.5)))
                x += 2
            }
            y += grid.floorHeight
        }
        return out
    }
}
