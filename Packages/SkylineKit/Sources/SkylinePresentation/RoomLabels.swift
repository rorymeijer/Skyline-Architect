import Foundation
import SkylineCore

public struct RoomLabel: Hashable, Sendable {
    public var text: String
    /// World position of the label's center.
    public var position: Vec2
}

/// Room names shown over rooms once they are large enough on screen to read.
public enum RoomLabels {
    /// Minimum zoom (points per meter) at which labels appear.
    public static let minZoom = 9.0

    public static func build(world: GameWorld, propertyID: PropertyID, catalog: BuildCatalog,
                             visible: Rect, zoom: Double) -> [RoomLabel] {
        guard zoom >= minZoom else { return [] }
        let grid = world.grid
        var labels: [RoomLabel] = []
        for b in world.buildings(on: propertyID) {
            for room in world.rooms(in: b.id) {
                let rect = grid.rect(columns: room.columns, floors: room.floors)
                guard rect.intersects(visible), let spec = catalog.spec(room.definitionID) else { continue }
                // Roughly 6.5 pt per character at the label font size.
                guard rect.width * zoom >= Double(spec.name.count) * 6.5 + 12 else { continue }
                if spec.kind == .shaft {
                    // One label per visible storey keeps shafts identifiable when scrolled.
                    for level in room.floors.lowest...room.floors.highest {
                        let y = grid.y(ofFloor: level) + grid.floorHeight * 0.78
                        if visible.contains(Vec2(rect.center.x, y)) { labels.append(RoomLabel(text: spec.name, position: Vec2(rect.center.x, y))) }
                    }
                } else {
                    let y = grid.y(ofFloor: room.floors.highest) + grid.floorHeight * 0.78
                    labels.append(RoomLabel(text: spec.name, position: Vec2(rect.center.x, y)))
                }
            }
        }
        return labels
    }
}
