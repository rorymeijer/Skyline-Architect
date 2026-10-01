import Testing
import SkylineCore
import SkylineContent
@testable import SkylinePresentation

/// The touch placement bar (0.30.4): either edge of a held room grows or shrinks, and the
/// whole ghost moves, always exactly what the preview then shows.
@Suite struct PlacementEditTests {
    @Test func edgesGrowAndShrinkOnBothSides() throws {
        let s = try PlacementTests().setup(withTower: true)
        let tool = ConstructionTool.room("apartment-studio")                // 6–10 modules
        let spec = try #require(s.engine.catalog.spec("apartment-studio"))
        let tapped = GridCell(column: s.building.footprint.start + 10, floor: 2)
        func columns(_ held: (anchor: GridCell, end: GridCell)) throws -> ColumnSpan {
            let rect = try #require(PlacementPlanner.preview(tool: tool, anchor: held.anchor, current: held.end,
                                                             world: s.world, propertyID: s.property, engine: s.engine)).rect
            let w = s.world.grid.moduleWidth
            let start = Int((rect.minX / w).rounded()) - Int((s.world.grid.x(ofColumn: 0) / w).rounded())
            return ColumnSpan(start: start, count: Int((rect.width / w).rounded()))
        }
        func edit(_ e: HeldEdit, _ held: (anchor: GridCell, end: GridCell)) throws -> (anchor: GridCell, end: GridCell) {
            try #require(PlacementPlanner.edited(e, anchor: held.anchor, end: held.end, tool: tool, catalog: s.engine.catalog))
        }
        var held = (anchor: tapped, end: tapped)                             // a tap: minimum width, rightwards
        #expect(try columns(held) == ColumnSpan(start: tapped.column, count: spec.minWidth))
        held = try edit(.left(1), held)                                      // grows to the left
        #expect(try columns(held) == ColumnSpan(start: tapped.column - 1, count: spec.minWidth + 1))
        held = try edit(.right(1), held)                                     // and to the right
        #expect(try columns(held) == ColumnSpan(start: tapped.column - 1, count: spec.minWidth + 2))
        held = try edit(.left(-1), held)                                     // shrinks from the left
        #expect(try columns(held) == ColumnSpan(start: tapped.column, count: spec.minWidth + 1))
        held = try edit(.move(columns: -3, floors: 1), held)                 // moves, same size
        #expect(try columns(held) == ColumnSpan(start: tapped.column - 3, count: spec.minWidth + 1))
        #expect(held.anchor.floor == 3 && held.end.floor == 3)
        held = try edit(.right(-1), held)
        #expect(PlacementPlanner.edited(.right(-1), anchor: held.anchor, end: held.end, tool: tool, catalog: s.engine.catalog) == nil)
        held.end.column += 4                                                 // the maximum width
        #expect(PlacementPlanner.edited(.left(1), anchor: held.anchor, end: held.end, tool: tool, catalog: s.engine.catalog) == nil)
    }

    @Test func floorsEditSidewaysShaftsDoNot() throws {
        let catalog = try PlacementTests().setup().engine.catalog
        let a = GridCell(column: 10, floor: 4), e = GridCell(column: 6, floor: 4)    // dragged leftwards
        let wider = try #require(PlacementPlanner.edited(.right(2), anchor: a, end: e, tool: .floor, catalog: catalog))
        #expect(wider.anchor == GridCell(column: 6, floor: 4) && wider.end == GridCell(column: 12, floor: 4))
        #expect(PlacementPlanner.edited(.left(-5), anchor: a, end: e, tool: .floor, catalog: catalog) == nil)   // not below one module
        #expect(PlacementPlanner.edited(.left(1), anchor: a, end: a, tool: .room("stairs"), catalog: catalog) == nil)
        #expect(PlacementPlanner.edited(.top(1), anchor: a, end: e, tool: .floor, catalog: catalog) == nil)
        #expect(PlacementPlanner.editAxis(.floor, catalog: catalog) == .sideways)
        #expect(PlacementPlanner.editAxis(.room("office-small"), catalog: catalog) == .sideways)
        #expect(PlacementPlanner.editAxis(.room("stairs"), catalog: catalog) == .vertical)
        #expect(PlacementPlanner.editAxis(.demolish, catalog: catalog) == nil)
    }

    /// Shafts grow at the bottom and the top, and move whole (0.30.4).
    @Test func shaftsEditTopBottomAndMove() throws {
        let catalog = try PlacementTests().setup().engine.catalog
        let spec = try #require(catalog.spec("elevator-shaft"))
        let tapped = GridCell(column: 12, floor: 3)                          // a tap: the minimum height, upwards
        func floors(_ held: (anchor: GridCell, end: GridCell)) -> FloorSpan {
            PlacementPlanner.shaftFloors(spec, anchor: held.anchor, current: held.end)
        }
        var held = try #require(PlacementPlanner.edited(.top(2), anchor: tapped, end: tapped, tool: .room("elevator-shaft"), catalog: catalog))
        #expect(floors(held) == FloorSpan(lowest: 3, highest: 3 + spec.minFloors - 1 + 2))
        held = try #require(PlacementPlanner.edited(.bottom(1), anchor: held.anchor, end: held.end, tool: .room("elevator-shaft"), catalog: catalog))
        #expect(floors(held).lowest == 2)
        held = try #require(PlacementPlanner.edited(.move(columns: 2, floors: -1), anchor: held.anchor, end: held.end,
                                                    tool: .room("elevator-shaft"), catalog: catalog))
        #expect(held.anchor.column == 14 && floors(held) == FloorSpan(lowest: 1, highest: 3 + spec.minFloors))
        let shortest = (anchor: tapped, end: tapped)
        #expect(PlacementPlanner.edited(.top(-1), anchor: shortest.anchor, end: shortest.end, tool: .room("elevator-shaft"), catalog: catalog) == nil)
        #expect(PlacementPlanner.edited(.left(1), anchor: tapped, end: tapped, tool: .room("elevator-shaft"), catalog: catalog) == nil)
    }
}
