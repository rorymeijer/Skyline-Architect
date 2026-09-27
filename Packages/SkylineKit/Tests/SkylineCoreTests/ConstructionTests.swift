import Foundation
import Testing
@testable import SkylineCore

/// Shared fixture: a 48-module plot with a 32-module foundation (1 basement) at columns 8..<40.
struct ConstructionFixture {
    var world: GameWorld
    let building: BuildingID
    let engine: ConstructionEngine

    static let catalog = BuildCatalog(
        rules: BuildRules(slabCostPerModule: 100, basementSlabCostPerModule: 200, maxCantileverModules: 2, demolitionRefund: 0.5),
        specs: [
            RoomSpec(id: "office", name: "Office", category: "office", kind: .room, appearance: "office",
                     minWidth: 6, maxWidth: 16, minFloors: 1, maxFloors: 1, lowestLevel: 1, costPerModule: 10),
            RoomSpec(id: "lobby", name: "Lobby", category: "circulation", kind: .room, appearance: "lobby",
                     minWidth: 4, maxWidth: 32, minFloors: 1, maxFloors: 2, lowestLevel: 0, highestLevel: 0, costPerModule: 5),
            RoomSpec(id: "stairs", name: "Stairs", category: "circulation", kind: .shaft, appearance: "stairs",
                     minWidth: 4, maxWidth: 4, minFloors: 2, maxFloors: 200, costPerModule: 7),
        ])

    init() throws {
        var w = GameWorld()
        let city = w.addCity(definitionID: "c", name: "C", seed: 1)
        let property = try w.addProperty(cityID: city, name: "P", plot: Plot(
            frontage: ColumnSpan(start: 0, count: 48), maxBasementFloors: 3, siteMargin: 0,
            strata: [SoilStratum(material: .clay, thickness: 10), SoilStratum(material: .bedrock, thickness: 1)]))
        building = try w.addBuilding(propertyID: property, name: "T", footprint: ColumnSpan(start: 8, count: 32),
                                     foundation: Foundation(basementFloors: 1, pileDepth: 20, pileSpacing: 4))
        world = w
        engine = ConstructionEngine(catalog: Self.catalog)
    }

    mutating func run(_ c: BuildCommand) throws -> AppliedConstruction { try engine.apply(c, to: &world) }

    func check(_ c: BuildCommand) -> Result<ConstructionPlan, ConstructionError> { engine.validate(c, in: world) }

    mutating func buildFloors(_ levels: ClosedRange<Int>, span: ColumnSpan = ColumnSpan(start: 8, count: 32)) throws {
        for l in levels { try run(.buildFloor(building: building, level: l, span: span)) }
    }
}

@Suite struct FloorConstructionTests {
    @Test func groundFloorMustLieInFootprint() throws {
        var f = try ConstructionFixture()
        #expect(f.check(.buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 4, count: 10))) == .failure(.outsideFootprint))
        let applied = try f.run(.buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 8, count: 32)))
        #expect(applied.plan.cost == 3200)
        #expect(f.world.buildings[f.building]?.plate(at: 0)?.span == ColumnSpan(start: 8, count: 32))
    }

    @Test func upperFloorsNeedSupportWithLimitedCantilever() throws {
        var f = try ConstructionFixture()
        #expect(f.check(.buildFloor(building: f.building, level: 1, span: ColumnSpan(start: 8, count: 4))) == .failure(.unsupported))
        try f.buildFloors(0...0, span: ColumnSpan(start: 10, count: 20))
        // 2-module cantilever each side is fine, 3 is not.
        #expect((try? f.check(.buildFloor(building: f.building, level: 1, span: ColumnSpan(start: 8, count: 24))).get()) != nil)
        #expect(f.check(.buildFloor(building: f.building, level: 1, span: ColumnSpan(start: 7, count: 25))) == .failure(.unsupported))
    }

    @Test func extendingAPlateMergesAndChargesOnlyNewModules() throws {
        var f = try ConstructionFixture()
        try f.buildFloors(0...0, span: ColumnSpan(start: 8, count: 10))
        #expect(f.check(.buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 20, count: 4))) == .failure(.notContiguous))
        let applied = try f.run(.buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 18, count: 6)))
        #expect(applied.plan.cost == 600)
        #expect(f.world.buildings[f.building]?.plate(at: 0)?.span == ColumnSpan(start: 8, count: 16))
        #expect(f.check(.buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 9, count: 3))) == .failure(.nothingToBuild))
    }

    @Test func basementsRequireExcavation() throws {
        var f = try ConstructionFixture()
        try f.run(.buildFloor(building: f.building, level: -1, span: ColumnSpan(start: 8, count: 32)))
        #expect(f.check(.buildFloor(building: f.building, level: -2, span: ColumnSpan(start: 8, count: 32))) == .failure(.noExcavation(level: -2)))
        #expect(f.world.buildings[f.building]?.plate(at: -1) != nil)
    }

    @Test func demolitionOnlyFromTheTopAndWhenEmpty() throws {
        var f = try ConstructionFixture()
        try f.buildFloors(0...2)
        #expect(f.check(.demolishFloor(building: f.building, level: 1)) == .failure(.carriesFloorAbove))
        try f.run(.placeRoom(building: f.building, definition: "office", columns: ColumnSpan(start: 8, count: 8), floors: FloorSpan(lowest: 2, highest: 2)))
        #expect(f.check(.demolishFloor(building: f.building, level: 2)) == .failure(.floorNotEmpty))
        #expect(f.check(.demolishFloor(building: f.building, level: 7)) == .failure(.noFloor(level: 7)))
    }

    /// No arbitrary floor limit: a 300-storey stack builds and validates.
    @Test func veryTallBuildingsAreAllowed() throws {
        var f = try ConstructionFixture()
        try f.buildFloors(0...299)
        #expect(f.world.buildings[f.building]?.builtLevels == FloorSpan(lowest: 0, highest: 299))
        try f.world.validateIntegrity()
    }
}

@Suite struct RoomConstructionTests {
    @Test func roomRulesComeFromSpecs() throws {
        var f = try ConstructionFixture()
        try f.buildFloors(0...3)
        let b = f.building
        #expect(f.check(.placeRoom(building: b, definition: "office", columns: ColumnSpan(start: 8, count: 4), floors: FloorSpan(lowest: 1, highest: 1)))
                == .failure(.widthOutOfRange(min: 6, max: 16)))
        #expect(f.check(.placeRoom(building: b, definition: "office", columns: ColumnSpan(start: 8, count: 8), floors: FloorSpan(lowest: 0, highest: 0)))
                == .failure(.levelNotAllowed))
        #expect(f.check(.placeRoom(building: b, definition: "nope", columns: ColumnSpan(start: 8, count: 8), floors: FloorSpan(lowest: 1, highest: 1)))
                == .failure(.unknownDefinition("nope")))
        #expect(f.check(.placeRoom(building: b, definition: "office", columns: ColumnSpan(start: 36, count: 8), floors: FloorSpan(lowest: 1, highest: 1)))
                == .failure(.noFloor(level: 1)))
        let applied = try f.run(.placeRoom(building: b, definition: "office", columns: ColumnSpan(start: 8, count: 8), floors: FloorSpan(lowest: 1, highest: 1)))
        #expect(applied.plan.cost == 80)
        let id = try #require(applied.createdRoom)
        #expect(f.check(.placeRoom(building: b, definition: "office", columns: ColumnSpan(start: 12, count: 8), floors: FloorSpan(lowest: 1, highest: 1)))
                == .failure(.overlaps(id)))
        #expect(f.world.room(in: b, column: 10, floor: 1)?.id == id)
    }

    @Test func shaftsSpanFloorRangesAndBlockRooms() throws {
        var f = try ConstructionFixture()
        try f.buildFloors(0...3)
        let b = f.building
        #expect(f.check(.placeRoom(building: b, definition: "stairs", columns: ColumnSpan(start: 20, count: 4), floors: FloorSpan(lowest: 0, highest: 0)))
                == .failure(.heightOutOfRange(min: 2, max: 200)))
        try f.run(.placeRoom(building: b, definition: "stairs", columns: ColumnSpan(start: 20, count: 4), floors: FloorSpan(lowest: 0, highest: 3)))
        #expect(throws: ConstructionError.self) {
            try f.run(.placeRoom(building: b, definition: "office", columns: ColumnSpan(start: 16, count: 8), floors: FloorSpan(lowest: 2, highest: 2)))
        }
        #expect(f.check(.placeRoom(building: b, definition: "stairs", columns: ColumnSpan(start: 30, count: 4), floors: FloorSpan(lowest: 3, highest: 4)))
                == .failure(.noFloor(level: 4)))
    }

    @Test func failedCommandsLeaveWorldUnchanged() throws {
        var f = try ConstructionFixture()
        let before = f.world
        #expect(throws: ConstructionError.self) { try f.run(.buildFloor(building: f.building, level: 3, span: ColumnSpan(start: 8, count: 4))) }
        #expect(f.world == before)
    }
}

@Suite struct HistoryTests {
    @Test func undoRedoRestoresExactWorlds() throws {
        var f = try ConstructionFixture()
        var history = ConstructionHistory()
        var snapshots = [f.world]
        let commands: [BuildCommand] = [
            .buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 8, count: 16)),
            .buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 20, count: 20)),
            .buildFloor(building: f.building, level: 1, span: ColumnSpan(start: 8, count: 32)),
            .placeRoom(building: f.building, definition: "office", columns: ColumnSpan(start: 10, count: 10), floors: FloorSpan(lowest: 1, highest: 1)),
        ]
        for c in commands {
            try history.perform(c, engine: f.engine, world: &f.world)
            snapshots.append(f.world)
        }
        // Demolish the room, then undo everything step by step.
        let room = try #require(f.world.rooms.values.first)
        try history.perform(.demolishRoom(room.id), engine: f.engine, world: &f.world)
        try history.undo(engine: f.engine, world: &f.world)
        #expect(f.world.rooms[room.id] == room)
        for expected in snapshots.dropLast().reversed() {
            try history.undo(engine: f.engine, world: &f.world)
            #expect(f.world.buildings.values == expected.buildings.values)
            #expect(f.world.rooms.values == expected.rooms.values)
        }
        #expect(!history.canUndo)
        // Redo everything back.
        while history.canRedo { try history.redo(engine: f.engine, world: &f.world) }
        #expect(f.world.buildings.values == snapshots.last!.buildings.values)
        #expect(f.world.rooms.isEmpty)  // the final redo re-applies the demolition
        try f.world.validateIntegrity()
    }

    @Test func newActionClearsRedo() throws {
        var f = try ConstructionFixture()
        var h = ConstructionHistory()
        try h.perform(.buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 8, count: 8)), engine: f.engine, world: &f.world)
        try h.undo(engine: f.engine, world: &f.world)
        #expect(h.canRedo)
        try h.perform(.buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 8, count: 4)), engine: f.engine, world: &f.world)
        #expect(!h.canRedo)
    }
}

@Suite struct IntegrityTests {
    @Test func detectsDanglingAndOverlappingRooms() throws {
        var f = try ConstructionFixture()
        try f.buildFloors(0...1)
        try f.world.validateIntegrity()
        // Forge an overlapping room directly (bypassing the engine), as a corrupt save might.
        let forged = Room(id: RoomID(raw: 900), buildingID: f.building, definitionID: "office",
                          columns: ColumnSpan(start: 8, count: 8), floors: FloorSpan(lowest: 1, highest: 1))
        var broken = f.world
        broken.rooms.insert(forged)
        #expect(throws: WorldIntegrityError.idAllocatorBehind(900)) { try broken.validateIntegrity() }
        broken.ids = IDAllocator(next: 1000)
        broken.rooms.insert(Room(id: RoomID(raw: 901), buildingID: f.building, definitionID: "office",
                                 columns: ColumnSpan(start: 10, count: 8), floors: FloorSpan(lowest: 1, highest: 1)))
        #expect(throws: WorldIntegrityError.overlappingRooms(RoomID(raw: 900), RoomID(raw: 901))) { try broken.validateIntegrity() }
        var floating = f.world
        floating.ids = IDAllocator(next: 1000)
        floating.rooms.insert(Room(id: RoomID(raw: 902), buildingID: f.building, definitionID: "office",
                                   columns: ColumnSpan(start: 8, count: 8), floors: FloorSpan(lowest: 5, highest: 5)))
        #expect(throws: WorldIntegrityError.roomWithoutFloor(RoomID(raw: 902))) { try floating.validateIntegrity() }
    }
}
