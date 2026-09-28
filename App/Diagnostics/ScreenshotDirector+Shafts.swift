#if DEBUG
import Foundation
import SkylineCore
import SkylinePresentation

/// Capture helpers for shafts over rooms, shaft heights and tenant names (0.20.2).
extension ScreenshotDirector {
    /// World point at a column of the first building (relative to its footprint) and a
    /// (fractional) floor.
    static func point(_ model: AppModel, column: Int, floor: Double) -> Vec2 {
        guard let world = model.world, let property = model.activePropertyID, let b = world.buildings(on: property).first else { return Vec2(24, 20) }
        return Vec2(world.grid.x(ofColumn: b.footprint.start + column), floor * world.grid.floorHeight)
    }

    static func shaft(_ model: AppModel) -> Room? {
        model.world?.rooms.values.first { $0.definitionID == "elevator-shaft" }
    }

    /// "15 tenants, 15 different names: …".
    static func nameNote(_ model: AppModel) -> String {
        let names = model.world?.tenants.values.map(\.name) ?? []
        return "\(names.count) tenants, \(Set(names).count) different names: " + names.sorted().joined(separator: ", ") + "."
    }

    static func optionsNote(_ model: AppModel) -> String {
        model.shaftOptions.map { "\($0.title): \($0.detail)" }.joined(separator: "; ")
    }

    /// Builds floor 9 over the roof (same span) and presses Extend Up.
    static func extendShaftUp(_ model: AppModel) {
        guard let world = model.world, let shaft = shaft(model), let b = world.buildings[shaft.buildingID],
              let roof = b.plate(at: shaft.floors.highest) else { return }
        model.perform(.buildFloor(building: b.id, level: roof.level + 1, span: roof.span))
        model.refreshSimulationSummary()
        if let up = model.shaftOptions.first(where: { $0.id == "up" })?.command { model.perform(up) }
    }

    /// Places a stairwell over the first rooms right of the elevator that can make way,
    /// and says what happened to them.
    static func stairsThroughRooms(_ model: AppModel) -> String {
        guard let world = model.world, let engine = model.engine, let property = model.activePropertyID,
              let b = world.buildings(on: property).first else { return "no building" }
        for rel in 19...28 {
            for (lo, hi) in [(0, 1), (-1, 0), (0, 2)] {
                let columns = ColumnSpan(start: b.footprint.start + rel, count: 4), floors = FloorSpan(lowest: lo, highest: hi)
                let inWay = world.rooms(in: b.id).filter { engine.catalog.spec($0.definitionID)?.kind == .room && $0.overlaps(columns: columns, floors: floors) }
                guard !inWay.isEmpty, (try? engine.validate(.placeRoom(building: b.id, definition: "stairs", columns: columns, floors: floors), in: world).get()) != nil
                else { continue }
                model.perform(.placeRoom(building: b.id, definition: "stairs", columns: columns, floors: floors))
                guard let after = model.world else { return "not placed" }
                let changes = inWay.map { room -> String in
                    let name = engine.catalog.spec(room.definitionID)?.name ?? room.definitionID
                    let now = after.rooms[room.id]?.columns.count ?? 0
                    let pieces = after.rooms(in: b.id).filter { $0.definitionID == room.definitionID && $0.id.raw > room.id.raw
                        && $0.floors == room.floors && room.columns.contains($0.columns) }
                    return "\(name) \(FloorLabel.label(for: room.floors.lowest)) \(room.columns.count) → \(now) modules"
                        + (pieces.isEmpty ? "" : " + a split-off \(pieces[0].columns.count)-module \(name)")
                }
                return "floors \(FloorLabel.label(for: lo))–\(FloorLabel.label(for: hi)); " + changes.joined(separator: "; ") + "."
            }
        }
        return "no place where rooms could make way"
    }
}
#endif
