import Foundation
import SkylineCore

/// One step of the touch placement bar (0.30.4): move either edge of a held room, floor or
/// shaft, or move the whole ghost.
public enum HeldEdit: Hashable, Sendable {
    /// The left edge moves out (`+1`, longer) or in (`-1`, shorter).
    case left(Int)
    /// The right edge moves out (`+1`, longer) or in (`-1`, shorter).
    case right(Int)
    /// A shaft's bottom moves down (`+1`, taller) or up (`-1`, lower).
    case bottom(Int)
    /// A shaft's top moves up (`+1`, taller) or down (`-1`, lower).
    case top(Int)
    /// The whole ghost moves by columns and floors, keeping its size.
    case move(columns: Int, floors: Int)
}

extension PlacementPlanner {
    /// The columns a room covers for a drag from `anchor` to `current`: at least its minimum
    /// width, at most its maximum, growing away from the anchor.
    static func roomColumns(_ spec: RoomSpec, anchor: GridCell, current: GridCell) -> ColumnSpan {
        let dragged = abs(current.column - anchor.column) + 1
        let width = min(max(dragged, spec.minWidth), spec.maxWidth)
        let start = current.column >= anchor.column ? anchor.column : anchor.column - width + 1
        return ColumnSpan(start: start, count: width)
    }

    /// The floors a new shaft covers for a drag from `anchor` to `current`, within its height
    /// range.
    static func shaftFloors(_ spec: RoomSpec, anchor: GridCell, current: GridCell) -> FloorSpan {
        var lo = min(anchor.floor, current.floor), hi = max(anchor.floor, current.floor)
        if hi - lo + 1 < spec.minFloors { hi = lo + spec.minFloors - 1 }
        if hi - lo + 1 > spec.maxFloors { lo = hi - spec.maxFloors + 1 }
        return FloorSpan(lowest: lo, highest: hi)
    }

    /// Which way the touch bar shapes a held placement: sideways (rooms and floors),
    /// vertically (shafts), or not at all (demolish).
    public enum EditAxis: Sendable { case sideways, vertical }

    public static func editAxis(_ tool: ConstructionTool, catalog: BuildCatalog) -> EditAxis? {
        switch tool {
        case .floor: .sideways
        case .room(let id): catalog.spec(id).map { $0.kind == .shaft ? .vertical : .sideways }
        case .demolish: nil
        }
    }

    /// The held placement after one edit, as anchor and end so the ghost covers exactly the
    /// edited span (left to right, or bottom to top for a shaft); nil when the edit would leave
    /// the size range (a room's widths, a shaft's heights, at least one module of floor), does
    /// not apply to the tool (an edge of the other axis), or for demolish.
    public static func edited(_ edit: HeldEdit, anchor: GridCell, end: GridCell, tool: ConstructionTool,
                              catalog: BuildCatalog) -> (anchor: GridCell, end: GridCell)? {
        switch tool {
        case .floor:
            let lo = min(anchor.column, end.column), hi = max(anchor.column, end.column)
            return sideways(edit, lo: lo, hi: hi, floor: anchor.floor, range: 1...Int.max)
        case .room(let id):
            guard let spec = catalog.spec(id) else { return nil }
            if spec.kind == .shaft {
                let floors = shaftFloors(spec, anchor: anchor, current: end)
                return vertical(edit, column: anchor.column, lo: floors.lowest, hi: floors.highest, range: spec.minFloors...spec.maxFloors)
            }
            let shown = roomColumns(spec, anchor: anchor, current: end)
            return sideways(edit, lo: shown.start, hi: shown.end - 1, floor: anchor.floor, range: spec.minWidth...spec.maxWidth)
        case .demolish:
            return nil
        }
    }

    private static func sideways(_ edit: HeldEdit, lo: Int, hi: Int, floor: Int,
                                 range: ClosedRange<Int>) -> (anchor: GridCell, end: GridCell)? {
        var lo = lo, hi = hi, floor = floor
        switch edit {
        case .left(let step): lo -= step
        case .right(let step): hi += step
        case let .move(columns, floors):
            lo += columns
            hi += columns
            floor += floors
        case .top, .bottom: return nil
        }
        guard range.contains(hi - lo + 1) else { return nil }
        return (GridCell(column: lo, floor: floor), GridCell(column: hi, floor: floor))
    }

    private static func vertical(_ edit: HeldEdit, column: Int, lo: Int, hi: Int,
                                 range: ClosedRange<Int>) -> (anchor: GridCell, end: GridCell)? {
        var lo = lo, hi = hi, column = column
        switch edit {
        case .bottom(let step): lo -= step
        case .top(let step): hi += step
        case let .move(columns, floors):
            column += columns
            lo += floors
            hi += floors
        case .left, .right: return nil
        }
        guard range.contains(hi - lo + 1) else { return nil }
        return (GridCell(column: column, floor: lo), GridCell(column: column, floor: hi))
    }
}
