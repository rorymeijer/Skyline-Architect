import Foundation
import SkylineCore

/// A room lit from inside at night (world rectangle, 0…1 intensity).
public struct LitRoom: Hashable, Sendable {
    public var rect: Rect
    public var intensity: Double
}

/// Basic day/night (Phase 9): how much daylight there is at a time of day, the ambient colour
/// the scene is multiplied with, and which rooms glow at night. Pure presentation — the
/// simulation does not depend on it. Full lighting (light sources, grading) is Phase 12.
public enum DayNight {
    /// 0 (night) … 1 (day): sunrise 05:30–07:30, sunset 18:30–20:30, smoothed.
    public static func daylight(secondOfDay s: Double) -> Double {
        func smooth(_ x: Double) -> Double { let t = min(max(x, 0), 1); return t * t * (3 - 2 * t) }
        let h = s / 3600
        if h < 12 { return smooth((h - 5.5) / 2) }
        return 1 - smooth((h - 18.5) / 2)
    }

    public static func daylight(atTick t: Double) -> Double {
        daylight(secondOfDay: (t + Double(SimClock.startSecondOfDay)).truncatingRemainder(dividingBy: Double(SimClock.secondsPerDay)))
    }

    static let night = RGBA(0.26, 0.30, 0.50)
    static let dusk = RGBA(0.95, 0.72, 0.60)

    /// Multiply colour for the whole scene: white by day, warm at the edges, blue at night.
    public static func ambient(daylight d: Double) -> RGBA {
        let warm = 1 - abs(d - 0.5) * 2                  // strongest at half light
        let base = night.mixed(with: RGBA(1, 1, 1), d)
        return base.mixed(with: dusk, warm * 0.35)
    }

    /// Rooms that glow at night: occupied rooms fully, shared circulation rooms (lobbies,
    /// corridors) dimly. Empty when it is day.
    public static func litRooms(world: GameWorld, propertyID: PropertyID, catalog: BuildCatalog, time: Double, visible: Rect) -> [LitRoom] {
        let darkness = 1 - daylight(atTick: time)
        guard darkness > 0.02 else { return [] }
        var occupied = Set<RoomID>()
        for p in world.people { if case let .room(r, _) = p.place { occupied.insert(r) } }
        let grid = world.grid
        var lit: [LitRoom] = []
        for b in world.buildings(on: propertyID) {
            for room in world.rooms(in: b.id) {
                guard let spec = catalog.spec(room.definitionID), spec.kind == .room else { continue }
                let rect = grid.rect(columns: room.columns, floors: room.floors)
                guard rect.intersects(visible) else { continue }
                let level = occupied.contains(room.id) ? 1.0 : (spec.category == "circulation" ? 0.45 : 0)
                if level > 0 { lit.append(LitRoom(rect: rect, intensity: level * darkness)) }
            }
        }
        return lit
    }
}
