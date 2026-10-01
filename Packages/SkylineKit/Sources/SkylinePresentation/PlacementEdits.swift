import Foundation
import SkylineCore

/// One step of the touch placement bar (0.30.4): move either edge of a held room or floor,
/// or move the whole ghost.
public enum HeldEdit: Hashable, Sendable {
    /// The left edge moves out (`+1`, longer) or in (`-1`, shorter).
    case left(Int)
    /// The right edge moves out (`+1`, longer) or in (`-1`, shorter).
    case right(Int)
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

    /// Whether the touch bar edits the held placement sideways (rooms and floors) rather than
    /// in height (shafts, which keep Taller / Lower).
    public static func editsSideways(_ tool: ConstructionTool, catalog: BuildCatalog) -> Bool {
        switch tool {
        case .floor: true
        case .room(let id): catalog.spec(id)?.kind == .room
        case .demolish: false
        }
    }

    /// The held placement after one edit, as anchor (left end) and end (right end) so the
    /// ghost covers exactly those columns; nil when the edit would leave the room's width range
    /// (or a floor narrower than one module), or for a tool that does not edit sideways.
    public static func edited(_ edit: HeldEdit, anchor: GridCell, end: GridCell, tool: ConstructionTool,
                              catalog: BuildCatalog) -> (anchor: GridCell, end: GridCell)? {
        let shown: ColumnSpan
        let range: ClosedRange<Int>
        switch tool {
        case .floor:
            let lo = min(anchor.column, end.column), hi = max(anchor.column, end.column)
            shown = ColumnSpan(start: lo, count: hi - lo + 1)
            range = 1...Int.max
        case .room(let id):
            guard let spec = catalog.spec(id), spec.kind == .room else { return nil }
            shown = roomColumns(spec, anchor: anchor, current: end)
            range = spec.minWidth...spec.maxWidth
        case .demolish:
            return nil
        }
        var lo = shown.start, hi = shown.end - 1, floor = anchor.floor
        switch edit {
        case .left(let step): lo -= step
        case .right(let step): hi += step
        case let .move(columns, floors):
            lo += columns
            hi += columns
            floor += floors
        }
        guard range.contains(hi - lo + 1) else { return nil }
        return (GridCell(column: lo, floor: floor), GridCell(column: hi, floor: floor))
    }
}
