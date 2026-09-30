import Testing
import SkylineCore
import SkylineContent
@testable import SkylinePresentation

@Suite struct PlacementTests {
    struct Setup {
        var world: GameWorld
        let property: PropertyID
        let building: Building
        let engine: ConstructionEngine
        let library: ContentLibrary
    }

    func setup(withTower: Bool = false) throws -> Setup {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let engine = ConstructionEngine(catalog: lib.buildCatalog)
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        if withTower {
            for c in try #require(lib.blueprint("demo-tower")).commands(for: building) { try engine.apply(c, to: &game.world) }
        }
        return Setup(world: game.world, property: game.activePropertyID, building: game.world.buildings[building.id]!, engine: engine, library: lib)
    }

    @Test func floorDragBuildsSpanOnAnchorLevel() throws {
        let s = try setup()
        let p = try #require(PlacementPlanner.preview(tool: .floor, anchor: GridCell(column: 30, floor: 0), current: GridCell(column: 12, floor: 3),
                                                      world: s.world, propertyID: s.property, engine: s.engine))
        #expect(p.command == .buildFloor(building: s.building.id, level: 0, span: ColumnSpan(start: 12, count: 19)))
        #expect(p.isValid)
        #expect(p.label.contains("Floor G") && p.label.contains("19 m") && p.label.contains("$"))
    }

    @Test func invalidPlacementsExplainWhy() throws {
        let s = try setup()
        let p = try #require(PlacementPlanner.preview(tool: .floor, anchor: GridCell(column: 12, floor: 5), current: GridCell(column: 20, floor: 5),
                                                      world: s.world, propertyID: s.property, engine: s.engine))
        #expect(!p.isValid)
        #expect(p.command == nil)
        #expect(p.label.contains("Needs a floor below"))
    }

    @Test func roomWidthIsClampedAndFollowsDragDirection() throws {
        let s = try setup(withTower: false)
        let spec = try #require(s.library.buildCatalog.spec("office-small"))
        // A click (no drag) proposes the minimum width to the right of the anchor.
        let click = try #require(PlacementPlanner.preview(tool: .room("office-small"), anchor: GridCell(column: 20, floor: 1),
                                                          current: GridCell(column: 20, floor: 1), world: s.world, propertyID: s.property, engine: s.engine))
        #expect(click.rect == GridSpec.standard.rect(columns: ColumnSpan(start: 20, count: spec.minWidth), floors: FloorSpan(lowest: 1, highest: 1)))
        #expect(!click.isValid)  // no floor 1 yet
        // Dragging far left clamps to the maximum width, ending at the anchor.
        let drag = try #require(PlacementPlanner.preview(tool: .room("office-small"), anchor: GridCell(column: 30, floor: 1),
                                                         current: GridCell(column: -50, floor: 1), world: s.world, propertyID: s.property, engine: s.engine))
        #expect(drag.rect.maxX == 31 && drag.rect.width == Double(spec.maxWidth))
    }

    @Test func shaftDragSpansFloors() throws {
        let s = try setup(withTower: true)
        let p = try #require(PlacementPlanner.preview(tool: .room("stairs"), anchor: GridCell(column: 9, floor: 5),
                                                      current: GridCell(column: 9, floor: 1), world: s.world, propertyID: s.property, engine: s.engine))
        #expect(p.rect.minY == 4 && p.rect.maxY == 24)
        #expect(p.isValid)  // it stands in front of the offices (0.30)
    }

    /// Dragging the top of an existing shaft with its own tool resizes it; the middle of a
    /// shaft is not a handle.
    @Test func draggingAShaftEndResizesIt() throws {
        var s = try setup(withTower: true)
        let shaft = try #require(s.world.rooms.values.first { $0.definitionID == "elevator-shaft" })
        let x = shaft.columns.start, top = shaft.floors.highest
        let shrink = try #require(PlacementPlanner.preview(tool: .room("elevator-shaft"), anchor: GridCell(column: x, floor: top),
                                                           current: GridCell(column: x, floor: top - 2), world: s.world, propertyID: s.property, engine: s.engine))
        #expect(shrink.command == .resizeRoom(shaft.id, floors: FloorSpan(lowest: shaft.floors.lowest, highest: top - 2)))
        #expect(shrink.isValid && shrink.label.contains("refund"))
        // Grow above the roof after building one more floor over the whole tower.
        let roof = try #require(s.world.buildings[s.building.id]?.plate(at: top))
        try s.engine.apply(.buildFloor(building: s.building.id, level: top + 1, span: roof.span), to: &s.world)
        let grow = try #require(PlacementPlanner.preview(tool: .room("elevator-shaft"), anchor: GridCell(column: x + 1, floor: top),
                                                         current: GridCell(column: x, floor: top + 1), world: s.world, propertyID: s.property, engine: s.engine))
        #expect(grow.command == .resizeRoom(shaft.id, floors: FloorSpan(lowest: shaft.floors.lowest, highest: top + 1)) && grow.isValid)
        let middle = try #require(PlacementPlanner.preview(tool: .room("elevator-shaft"), anchor: GridCell(column: x, floor: top - 1),
                                                           current: GridCell(column: x, floor: top + 1), world: s.world, propertyID: s.property, engine: s.engine))
        #expect(!(middle.command.map { if case .resizeRoom = $0 { true } else { false } } ?? false))
    }

    /// A shaft in front of a room is valid and leaves the room whole (0.30).
    @Test func shaftInFrontOfARoomIsValid() throws {
        var s = try setup()
        let b = s.building.id, f = s.building.footprint
        for level in 0...2 { try s.engine.apply(.buildFloor(building: b, level: level, span: f), to: &s.world) }
        try s.engine.apply(.placeRoom(building: b, definition: "lobby", columns: f, floors: FloorSpan(lowest: 0, highest: 0)), to: &s.world)
        let p = try #require(PlacementPlanner.preview(tool: .room("stairs"), anchor: GridCell(column: f.start + 10, floor: 0),
                                                      current: GridCell(column: f.start + 10, floor: 2), world: s.world, propertyID: s.property, engine: s.engine))
        #expect(p.isValid && !p.label.contains("make"))
        try s.engine.apply(#require(p.command), to: &s.world)
        #expect(s.world.rooms.values.first { $0.definitionID == "lobby" }?.columns == f)
    }

    /// The touch ± buttons (0.30): rooms and floors grow sideways away from the anchor,
    /// shafts vertically; shorter never passes the anchor.
    @Test func nudgingGrowsAwayFromTheAnchor() throws {
        let catalog = try setup().engine.catalog
        let a = GridCell(column: 10, floor: 3)
        func nudge(_ c: GridCell, _ tool: ConstructionTool, _ step: Int) -> GridCell {
            PlacementPlanner.nudged(c, anchor: a, tool: tool, catalog: catalog, by: step)
        }
        #expect(nudge(GridCell(column: 14, floor: 3), .room("office-small"), 1) == GridCell(column: 15, floor: 3))
        #expect(nudge(GridCell(column: 6, floor: 3), .room("office-small"), 1) == GridCell(column: 5, floor: 3))
        #expect(nudge(a, .floor, 1) == GridCell(column: 11, floor: 3))
        #expect(nudge(a, .floor, -1) == a)                                   // never past the anchor
        #expect(nudge(GridCell(column: 10, floor: 6), .room("stairs"), 1) == GridCell(column: 10, floor: 7))
        #expect(nudge(GridCell(column: 10, floor: 1), .room("stairs"), 1) == GridCell(column: 10, floor: 0))
        #expect(nudge(GridCell(column: 10, floor: 4), .room("stairs"), -1) == a)
    }

    @Test func demolishTargetsRoomThenFloor() throws {
        let s = try setup(withTower: true)
        let room = try #require(PlacementPlanner.preview(tool: .demolish, anchor: GridCell(column: 10, floor: 2), current: GridCell(column: 10, floor: 2),
                                                         world: s.world, propertyID: s.property, engine: s.engine))
        #expect(room.isDemolition && room.isValid)
        #expect(room.label.contains("Demolish Small Office") && room.label.contains("refund"))
        // Outside every plate there is nothing to demolish.
        #expect(PlacementPlanner.preview(tool: .demolish, anchor: GridCell(column: 9, floor: 8), current: GridCell(column: 9, floor: 8),
                                         world: s.world, propertyID: s.property, engine: s.engine) == nil)

        // An empty top floor is offered as a floor demolition with a refund.
        var bare = try setup()
        try bare.engine.apply(.buildFloor(building: bare.building.id, level: 0, span: ColumnSpan(start: 8, count: 32)), to: &bare.world)
        let floor = try #require(PlacementPlanner.preview(tool: .demolish, anchor: GridCell(column: 20, floor: 0), current: GridCell(column: 20, floor: 0),
                                                          world: bare.world, propertyID: bare.property, engine: bare.engine))
        #expect(floor.command == .demolishFloor(building: bare.building.id, level: 0))
        #expect(floor.isValid && floor.label.contains("Demolish Floor G"))
    }

    @Test func moneyFormatting() {
        #expect(Money.format(0) == "$0")
        #expect(Money.format(1_234_567) == "$1,234,567")
        #expect(Money.format(-950) == "−$950")
    }
}

@Suite struct BuildingCompositionTests {
    @Test func recomposeOnlyRebuildsBuildingsLayer() throws {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let catalog = lib.buildCatalog
        let c0 = try #require(SiteComposer.compose(world: game.world, propertyID: game.activePropertyID, catalog: catalog))
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        for cmd in try #require(lib.blueprint("demo-tower")).commands(for: building) {
            try ConstructionEngine(catalog: catalog).apply(cmd, to: &game.world)
        }
        let c1 = SiteComposer.recompose(c0, world: game.world, catalog: catalog)
        #expect(c1.site.drawing.items.count == c0.site.drawing.items.count)
        #expect(c1.buildings.drawing.items.count > c0.buildings.drawing.items.count + 1000)
        let top = try #require(c1.superstructureRect)
        #expect(top.maxY == 36)  // nine storeys G…8
        // Recomposition equals composing from scratch.
        let fresh = try #require(SiteComposer.compose(world: game.world, propertyID: game.activePropertyID, catalog: catalog))
        #expect(fresh.buildings.drawing.items == c1.buildings.drawing.items)
    }

    @Test func dirtyRectCoversChangedCellsWithMargin() {
        let grid = GridSpec.standard
        let plan = ConstructionPlan(cost: 0, buildingID: BuildingID(raw: 1), columns: ColumnSpan(start: 10, count: 4), floors: FloorSpan(lowest: 2, highest: 2))
        let r = SiteComposer.dirtyRect(for: plan, grid: grid)
        #expect(r.contains(grid.rect(columns: plan.columns, floors: plan.floors).insetBy(dx: -1, dy: -4)))
    }

    @Test func roomLabelsAppearOnlyWhenReadable() throws {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        for cmd in try #require(lib.blueprint("demo-tower")).commands(for: building) {
            try ConstructionEngine(catalog: lib.buildCatalog).apply(cmd, to: &game.world)
        }
        let view = Rect(minX: 0, minY: -8, maxX: 48, maxY: 40)
        #expect(RoomLabels.build(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, visible: view, zoom: 4).isEmpty)
        let labels = RoomLabels.build(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, visible: view, zoom: 30)
        #expect(labels.contains { $0.text == "Small Office" })
        #expect(labels.contains { $0.text == "Stairwell" })
        // An elevator shows the floor number where its car stops, and nothing where it passes (0.30).
        let shaft = try #require(game.world.rooms.values.first { $0.definitionID == "elevator-shaft" })
        let stops = [shaft.floors.lowest, shaft.floors.lowest + 2]
        let numbered = RoomLabels.build(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, visible: view, zoom: 30,
                                        stops: { $0.id == shaft.id ? stops : nil })
        let x = game.world.grid.rect(columns: shaft.columns, floors: shaft.floors).center.x
        let inShaft = numbered.filter { $0.position.x == x }.map(\.text)
        #expect(inShaft == stops.map { FloorLabel.label(for: $0) })
    }

    /// A room label moves to the widest part a shaft in front leaves free (0.30.1).
    @Test func roomLabelsAvoidShaftsInFront() {
        let shaft = Room(id: RoomID(raw: 9), buildingID: BuildingID(raw: 1), definitionID: "elevator-shaft",
                         columns: ColumnSpan(start: 12, count: 3), floors: FloorSpan(lowest: 2, highest: 6))
        #expect(RoomLabels.widestFree(ColumnSpan(start: 10, count: 14), at: 3, shafts: [shaft]) == ColumnSpan(start: 15, count: 9))
        #expect(RoomLabels.widestFree(ColumnSpan(start: 10, count: 14), at: 7, shafts: [shaft]) == ColumnSpan(start: 10, count: 14))
        #expect(RoomLabels.widestFree(ColumnSpan(start: 12, count: 3), at: 3, shafts: [shaft]).count == 0)
    }
}
