import Foundation
import Testing
@testable import SkylineCore

/// Shafts in front of rooms (0.30) and resizing shafts, with exact undo.
@Suite struct ShaftTests {
    func fixture() throws -> ConstructionFixture {
        var f = try ConstructionFixture()
        try f.buildFloors(0...3)
        return f
    }

    func office(_ f: inout ConstructionFixture, _ start: Int, _ count: Int, floor: Int = 1) throws -> RoomID {
        try #require(f.run(.placeRoom(building: f.building, definition: "office", columns: ColumnSpan(start: start, count: count),
                                      floors: FloorSpan(lowest: floor, highest: floor))).createdRoom)
    }

    func stairs(_ f: ConstructionFixture, _ start: Int, _ lo: Int, _ hi: Int) -> BuildCommand {
        .placeRoom(building: f.building, definition: "stairs", columns: ColumnSpan(start: start, count: 4), floors: FloorSpan(lowest: lo, highest: hi))
    }

    /// Integrity with the fixture's shafts known (a shaft may stand in front of a room).
    func checkIntegrity(_ f: ConstructionFixture) throws {
        try f.world.validateIntegrity(isShaft: { f.engine.catalog.spec($0)?.kind == .shaft })
    }

    @Test func aShaftStandsInFrontOfARoom() throws {
        var f = try fixture()
        let id = try office(&f, 10, 14)                                     // 10..<24
        let plan = try f.check(stairs(f, 16, 1, 2)).get()
        #expect(plan.cost == 7 * 4 * 2)                                       // only the shaft is paid
        #expect(plan.columns == ColumnSpan(start: 16, count: 4))
        try f.run(stairs(f, 16, 1, 2))
        #expect(f.world.rooms[id]?.columns == ColumnSpan(start: 10, count: 14)) // the office stays whole behind it
        #expect(f.world.rooms.count == 2)
        try checkIntegrity(f)
        // Without knowing which is the shaft, the overlap is an error.
        #expect(throws: WorldIntegrityError.self) { try f.world.validateIntegrity() }
    }

    @Test func aRoomCanBePlacedBehindAShaft() throws {
        var f = try fixture()
        try f.run(stairs(f, 30, 0, 3))
        let id = try office(&f, 26, 8, floor: 2)                            // 26..<34, behind the shaft
        #expect(f.world.rooms[id]?.columns == ColumnSpan(start: 26, count: 8))
        try checkIntegrity(f)
    }

    @Test func likeBlocksLike() throws {
        var f = try fixture()
        try office(&f, 10, 10)
        #expect(throws: ConstructionError.self) { try office(&f, 14, 8) }    // room over room
        try f.run(stairs(f, 30, 0, 3))
        #expect(throws: ConstructionError.self) { try f.run(stairs(f, 32, 1, 2)) }   // shaft over shaft
    }

    /// The cell picks the shaft when asked to prefer what is drawn in front.
    @Test func theShaftIsInFrontAtItsCells() throws {
        var f = try fixture()
        let room = try office(&f, 10, 14)
        let shaft = try #require(f.run(stairs(f, 16, 1, 2)).createdRoom)
        let isShaft = { (r: Room) in f.engine.catalog.spec(r.definitionID)?.kind == .shaft }
        #expect(f.world.room(in: f.building, column: 17, floor: 1, inFront: isShaft)?.id == shaft)
        #expect(f.world.room(in: f.building, column: 11, floor: 1, inFront: isShaft)?.id == room)
    }

    /// Undo and redo are exact; the room behind is never touched.
    @Test func undoAndRedoAreExact() throws {
        var f = try fixture()
        var history = ConstructionHistory()
        try office(&f, 10, 16)
        let before = f.world.rooms.values, cash = f.world.ledger.cash
        try history.perform(stairs(f, 16, 0, 3), engine: f.engine, world: &f.world)
        let after = f.world.rooms.values
        #expect(after.count == 2 && f.world.ledger.cash == cash - 7 * 4 * 4)
        try history.undo(engine: f.engine, world: &f.world)
        #expect(f.world.rooms.values == before && f.world.ledger.cash == cash)
        try history.redo(engine: f.engine, world: &f.world)
        #expect(f.world.rooms.values == after)
        try checkIntegrity(f)
    }

    @Test func shaftsGrowAndShrink() throws {
        var f = try fixture()
        var history = ConstructionHistory()
        let shaft = try #require(f.run(stairs(f, 30, 0, 1)).createdRoom)
        let office = try office(&f, 26, 14, floor: 2)                      // 26..<40, behind the shaft on floor 2
        let cash = f.world.ledger.cash
        let grow = BuildCommand.resizeRoom(shaft, floors: FloorSpan(lowest: 0, highest: 3))
        #expect(try f.check(grow).get().cost == 7 * 4 * 2)
        try history.perform(grow, engine: f.engine, world: &f.world)
        #expect(f.world.rooms[shaft]?.floors == FloorSpan(lowest: 0, highest: 3))
        #expect(f.world.rooms[office]?.columns == ColumnSpan(start: 26, count: 14))  // the office stays whole
        #expect(f.world.ledger.cash == cash - 56)
        // Shrinking refunds the demolition share (50 % here) of the floors removed.
        let shrink = BuildCommand.resizeRoom(shaft, floors: FloorSpan(lowest: 0, highest: 2))
        #expect(try f.check(shrink).get().cost == -14)
        try history.perform(shrink, engine: f.engine, world: &f.world)
        try history.undo(engine: f.engine, world: &f.world)
        try history.undo(engine: f.engine, world: &f.world)
        #expect(f.world.rooms[shaft]?.floors == FloorSpan(lowest: 0, highest: 1))
        #expect(f.world.rooms[office]?.columns == ColumnSpan(start: 26, count: 14) && f.world.ledger.cash == cash)
        try checkIntegrity(f)
    }

    @Test func resizeRules() throws {
        var f = try fixture()
        let shaft = try #require(f.run(stairs(f, 30, 0, 1)).createdRoom)
        let office = try office(&f, 10, 8)
        #expect(f.check(.resizeRoom(office, floors: FloorSpan(lowest: 1, highest: 2))) == .failure(.notResizable))
        #expect(f.check(.resizeRoom(shaft, floors: FloorSpan(lowest: 0, highest: 1))) == .failure(.nothingToBuild))
        #expect(f.check(.resizeRoom(shaft, floors: FloorSpan(lowest: 3, highest: 3))) == .failure(.notContiguous))
        #expect(f.check(.resizeRoom(shaft, floors: FloorSpan(lowest: 1, highest: 1))) == .failure(.heightOutOfRange(min: 2, max: 200)))
        #expect(f.check(.resizeRoom(shaft, floors: FloorSpan(lowest: 0, highest: 4))) == .failure(.noFloor(level: 4)))
        #expect((try? f.check(.resizeRoom(shaft, floors: FloorSpan(lowest: -1, highest: 1))).get()) == nil)   // no basement plate yet
        try f.run(.buildFloor(building: f.building, level: -1, span: ColumnSpan(start: 8, count: 32)))
        #expect((try? f.check(.resizeRoom(shaft, floors: FloorSpan(lowest: -1, highest: 1))).get()) != nil)
    }
}
