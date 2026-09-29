import Foundation
import SkylineCore

/// The layout the balance bot builds (F1): a core in the middle of the footprint — stairs,
/// two passenger elevator slots and a service elevator slot — with a wing of units on each
/// side. The basement holds the plant, the waste room and the staff room; every sixth
/// floor is a plant floor. Pure layout: it produces `BuildCommand`s, the bot applies them
/// through the construction engine like a player.
struct TowerPlan {
    let building: BuildingID
    let span: ColumnSpan
    /// First column of the core (13 modules: stairs 4, elevator 3, elevator 3, service 3).
    let core: Int

    static let coreWidth = 13
    static let plantEvery = 6

    init(building: Building) {
        self.building = building.id
        span = building.footprint
        core = span.start + max((span.count - Self.coreWidth) / 2, 0)
    }

    var stairs: ColumnSpan { ColumnSpan(start: core, count: 4) }
    var elevatorA: ColumnSpan { ColumnSpan(start: core + 4, count: 3) }
    var elevatorB: ColumnSpan { ColumnSpan(start: core + 7, count: 3) }
    var service: ColumnSpan { ColumnSpan(start: core + 10, count: 3) }
    var left: ColumnSpan { ColumnSpan(start: span.start, count: core - span.start) }
    var right: ColumnSpan { ColumnSpan(start: core + Self.coreWidth, count: span.end - core - Self.coreWidth) }

    func isPlantFloor(_ level: Int) -> Bool { level > 0 && level % Self.plantEvery == 0 }

    /// Rooms of one kind filling `wing`: as few as the maximum width allows, evenly wide;
    /// a remainder too narrow for the kind becomes a corridor.
    static func split(_ wing: ColumnSpan, min lo: Int, max hi: Int) -> [ColumnSpan] {
        guard wing.count >= lo else { return [] }
        var n = (wing.count + hi - 1) / hi
        while n > 1 && wing.count / n < lo { n -= 1 }
        var out: [ColumnSpan] = []
        var x = wing.start
        for i in 0..<n {
            let w = wing.count / n + (i < wing.count % n ? 1 : 0)
            out.append(ColumnSpan(start: x, count: min(w, hi)))
            x += w
        }
        return out
    }

    func place(_ def: String, _ columns: ColumnSpan, _ level: Int) -> BuildCommand {
        .placeRoom(building: building, definition: def, columns: columns, floors: FloorSpan(lowest: level, highest: level))
    }

    /// Fills a wing with rooms of `def` (width limits from the catalog), the rest corridor.
    func fill(_ wing: ColumnSpan, with def: String, level: Int, catalog: BuildCatalog) -> [BuildCommand] {
        guard wing.count > 0, let spec = catalog.spec(def) else { return [] }
        let units = Self.split(wing, min: spec.minWidth, max: spec.maxWidth)
        var commands = units.map { place(def, $0, level) }
        let used = units.reduce(0) { $0 + $1.count }
        if wing.count - used >= 2 {
            commands.append(place("corridor", ColumnSpan(start: wing.start + used, count: wing.count - used), level))
        }
        return commands
    }

    /// Basement plant: mechanical and electrical on the left; telecom, waste and (when staff
    /// are allowed) a staff room on the right.
    func basement(staff: Bool) -> [BuildCommand] {
        var c: [BuildCommand] = []
        let mech = ColumnSpan(start: left.start, count: max(left.count / 2, 3))
        c.append(place("mechanical", mech, -1))
        c.append(place("electrical-room", ColumnSpan(start: mech.end, count: left.end - mech.end), -1))
        var x = right.start
        for (def, w) in [("telecom-room", 3), ("waste-room", 3)] {
            c.append(place(def, ColumnSpan(start: x, count: w), -1))
            x += w
        }
        let rest = right.end - x
        if staff && rest >= 4 { c.append(place("staff-room", ColumnSpan(start: x, count: min(rest, 10)), -1)) }
        return c
    }

    /// A plant floor above ground: mechanical on the left, electrical and telecom on the right.
    func plantFloor(_ level: Int) -> [BuildCommand] {
        [place("mechanical", ColumnSpan(start: left.start, count: min(left.count, 12)), level),
         place("electrical-room", ColumnSpan(start: right.start, count: min(right.count - 3, 12)), level),
         place("telecom-room", ColumnSpan(start: right.end - 3, count: 3), level)]
    }
}
