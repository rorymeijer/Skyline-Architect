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
        #expect(!p.isValid)  // overlaps offices and apartments
        #expect(p.label.contains("Overlaps"))
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
    }
}
