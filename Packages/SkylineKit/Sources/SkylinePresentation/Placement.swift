import Foundation
import SkylineCore

/// The construction tool the player has selected.
public enum ConstructionTool: Hashable, Sendable {
    /// Build or extend floor plates by dragging horizontally.
    case floor
    /// Place a room or shaft by definition id.
    case room(String)
    /// Remove the room under the cursor, or the floor plate if the cell is empty.
    case demolish
}

/// What the renderer shows while a tool is active: the target region, whether the
/// command is valid, and a label (name, size, cost or the reason it is refused).
public struct PlacementPreview: Equatable, Sendable {
    public var command: BuildCommand?
    public var rect: Rect
    public var isValid: Bool
    public var isDemolition: Bool
    public var label: String
}

/// Turns pointer input (anchor cell where the drag began, current cell) into a
/// `BuildCommand` and validates it. Pure: shared by macOS, iPadOS and tests.
public enum PlacementPlanner {
    public static func preview(tool: ConstructionTool, anchor: GridCell, current: GridCell,
                               world: GameWorld, propertyID: PropertyID, engine: ConstructionEngine) -> PlacementPreview? {
        let grid = world.grid
        guard let building = nearestBuilding(to: anchor.column, world: world, propertyID: propertyID) else { return nil }
        let catalog = engine.catalog

        switch tool {
        case .floor:
            let lo = min(anchor.column, current.column), hi = max(anchor.column, current.column)
            let command = BuildCommand.buildFloor(building: building.id, level: anchor.floor, span: ColumnSpan(start: lo, count: hi - lo + 1))
            let rect = grid.rect(columns: ColumnSpan(start: lo, count: hi - lo + 1), floors: FloorSpan(lowest: anchor.floor, highest: anchor.floor))
            return finish(command, rect: rect, name: "Floor \(FloorLabel.label(for: anchor.floor))", widthModules: hi - lo + 1,
                          demolition: false, world: world, engine: engine)

        case .room(let id):
            guard let spec = catalog.spec(id) else { return nil }
            let columns: ColumnSpan
            let floors: FloorSpan
            switch spec.kind {
            case .room:
                let dragged = abs(current.column - anchor.column) + 1
                let width = min(max(dragged, spec.minWidth), spec.maxWidth)
                let start = current.column >= anchor.column ? anchor.column : anchor.column - width + 1
                columns = ColumnSpan(start: start, count: width)
                floors = FloorSpan(lowest: anchor.floor, highest: anchor.floor + spec.minFloors - 1)
            case .shaft:
                // Grabbing the top or bottom floor of a shaft of this type drags that end:
                // the shaft grows or shrinks (resizeRoom).
                if let shaft = world.room(in: building.id, column: anchor.column, floor: anchor.floor), shaft.definitionID == id,
                   anchor.floor == shaft.floors.highest || anchor.floor == shaft.floors.lowest {
                    let floors = anchor.floor == shaft.floors.highest
                        ? FloorSpan(lowest: shaft.floors.lowest, highest: max(current.floor, shaft.floors.lowest))
                        : FloorSpan(lowest: min(current.floor, shaft.floors.highest), highest: shaft.floors.highest)
                    let shown = FloorSpan(lowest: min(floors.lowest, shaft.floors.lowest), highest: max(floors.highest, shaft.floors.highest))
                    return finish(.resizeRoom(shaft.id, floors: floors), rect: grid.rect(columns: shaft.columns, floors: shown),
                                  name: "\(spec.name) \(FloorLabel.label(for: floors.lowest))–\(FloorLabel.label(for: floors.highest))",
                                  floors: floors.count, note: makesWay(shaft.columns, floors, except: shaft.id, building: building.id, world, catalog),
                                  demolition: floors.count < shaft.floors.count, world: world, engine: engine)
                }
                columns = ColumnSpan(start: anchor.column, count: spec.minWidth)
                var lo = min(anchor.floor, current.floor), hi = max(anchor.floor, current.floor)
                if hi - lo + 1 < spec.minFloors { hi = lo + spec.minFloors - 1 }
                if hi - lo + 1 > spec.maxFloors { lo = hi - spec.maxFloors + 1 }
                floors = FloorSpan(lowest: lo, highest: hi)
            }
            let command = BuildCommand.placeRoom(building: building.id, definition: id, columns: columns, floors: floors)
            return finish(command, rect: grid.rect(columns: columns, floors: floors), name: spec.name,
                          widthModules: columns.count, floors: spec.kind == .shaft ? floors.count : nil,
                          note: spec.kind == .shaft ? makesWay(columns, floors, except: nil, building: building.id, world, catalog) : nil,
                          demolition: false, world: world, engine: engine)

        case .demolish:
            if let room = world.room(in: building.id, column: current.column, floor: current.floor) {
                let name = catalog.spec(room.definitionID)?.name ?? room.definitionID
                return finish(.demolishRoom(room.id), rect: grid.rect(columns: room.columns, floors: room.floors),
                              name: "Demolish \(name)", demolition: true, world: world, engine: engine)
            }
            if let plate = building.plate(at: current.floor), plate.span.contains(current.column) {
                return finish(.demolishFloor(building: building.id, level: current.floor),
                              rect: grid.rect(columns: plate.span, floors: FloorSpan(lowest: plate.level, highest: plate.level)),
                              name: "Demolish Floor \(FloorLabel.label(for: plate.level))", demolition: true, world: world, engine: engine)
            }
            return nil
        }
    }

    /// "2 rooms make way" when a shaft would go over rooms (they get narrower or split).
    static func makesWay(_ columns: ColumnSpan, _ floors: FloorSpan, except: RoomID?, building: BuildingID,
                         _ world: GameWorld, _ catalog: BuildCatalog) -> String? {
        let n = world.rooms(in: building).filter {
            $0.id != except && catalog.spec($0.definitionID)?.kind == .room && $0.overlaps(columns: columns, floors: floors)
        }.count
        return n == 0 ? nil : n == 1 ? "1 room makes way" : "\(n) rooms make way"
    }

    private static func finish(_ command: BuildCommand, rect: Rect, name: String, widthModules: Int? = nil, floors: Int? = nil,
                               note: String? = nil, demolition: Bool, world: GameWorld, engine: ConstructionEngine) -> PlacementPreview {
        switch engine.validate(command, in: world) {
        case .success(let plan):
            var parts = [name]
            if let widthModules { parts.append("\(Int(Double(widthModules) * world.grid.moduleWidth)) m") }
            if let floors { parts.append("\(floors) floors") }
            if let note { parts.append(note) }
            parts.append(plan.cost < 0 ? "refund \(Money.format(-plan.cost))" : Money.format(plan.cost))
            if plan.cost > world.ledger.cash {
                return PlacementPreview(command: nil, rect: rect, isValid: false, isDemolition: demolition,
                                        label: "\(name): not enough money (\(Money.format(plan.cost)), have \(Money.format(world.ledger.cash)))")
            }
            return PlacementPreview(command: command, rect: rect, isValid: true, isDemolition: demolition, label: parts.joined(separator: " · "))
        case .failure(let error):
            return PlacementPreview(command: nil, rect: rect, isValid: false, isDemolition: demolition, label: "\(name): \(error)")
        }
    }

    /// The building on the property whose footprint is closest to `column`.
    static func nearestBuilding(to column: Int, world: GameWorld, propertyID: PropertyID) -> Building? {
        world.buildings(on: propertyID).min { a, b in
            distance(column, a.footprint) < distance(column, b.footprint)
        }
    }

    private static func distance(_ c: Int, _ span: ColumnSpan) -> Int {
        span.contains(c) ? 0 : min(abs(c - span.start), abs(c - (span.end - 1)))
    }
}

/// Currency formatting independent of locale (deterministic in tests and captures).
public enum Money {
    public static func format(_ amount: Int) -> String {
        (amount < 0 ? "−$" : "$") + grouped(abs(amount))
    }

    /// Digits in groups of three ("1,500"; negative with "−").
    public static func grouped(_ number: Int) -> String {
        let digits = String(abs(number))
        var grouped = ""
        for (i, ch) in digits.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { grouped.append(",") }
            grouped.append(ch)
        }
        return (number < 0 ? "−" : "") + String(grouped.reversed())
    }
}
