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

    /// Places a stairwell in front of the first rooms right of the elevator (0.30: they stay
    /// whole behind it), and says which.
    static func stairsThroughRooms(_ model: AppModel) -> String {
        guard let world = model.world, let engine = model.engine, let property = model.activePropertyID,
              let b = world.buildings(on: property).first else { return "no building" }
        for rel in 19...28 {
            for (lo, hi) in [(0, 1), (-1, 0), (0, 2)] {
                let columns = ColumnSpan(start: b.footprint.start + rel, count: 4), floors = FloorSpan(lowest: lo, highest: hi)
                let behind = world.rooms(in: b.id).filter { engine.catalog.spec($0.definitionID)?.kind == .room && $0.overlaps(columns: columns, floors: floors) }
                guard !behind.isEmpty, (try? engine.validate(.placeRoom(building: b.id, definition: "stairs", columns: columns, floors: floors), in: world).get()) != nil
                else { continue }
                model.perform(.placeRoom(building: b.id, definition: "stairs", columns: columns, floors: floors))
                let names = behind.map { "\(engine.catalog.spec($0.definitionID)?.name ?? $0.definitionID) \(FloorLabel.label(for: $0.floors.lowest))" }
                return "floors \(FloorLabel.label(for: lo))–\(FloorLabel.label(for: hi)), in front of " + names.joined(separator: ", ") + " (whole behind it)."
            }
        }
        return "no place in front of rooms"
    }

    /// Places a second elevator in front of the rooms left of the core, floors 2–6, so the
    /// see-through capture has rooms behind a shaft (0.30.1). Returns its middle column
    /// (relative to the footprint), or nil.
    static func elevatorThroughRooms(_ model: AppModel) -> Int? {
        guard let world = model.world, let engine = model.engine, let property = model.activePropertyID,
              let b = world.buildings(on: property).first else { return nil }
        let floors = FloorSpan(lowest: 2, highest: 6)
        for rel in [4, 3, 5, 2, 6, 24, 25, 26] {
            let columns = ColumnSpan(start: b.footprint.start + rel, count: 3)
            let command = BuildCommand.placeRoom(building: b.id, definition: "elevator-shaft", columns: columns, floors: floors)
            let behind = world.rooms(in: b.id).contains { engine.catalog.spec($0.definitionID)?.kind == .room && $0.overlaps(columns: columns, floors: floors) }
            guard behind, (try? engine.validate(command, in: world).get()) != nil else { continue }
            model.perform(command)
            return rel + 1
        }
        return nil
    }

    /// Points the camera at `center`, also when `newGame()` has just built a scene that is not
    /// presented yet (it then starts from `initialPlacement`, which would undo a jump).
    static func focus(_ model: AppModel, _ center: Vec2, zoom: Double) {
        model.scene?.initialPlacement = (center, zoom)
        model.scene?.withController { $0.jump(center: center, zoom: zoom) }
    }
}
#endif
