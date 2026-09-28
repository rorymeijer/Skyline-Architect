import Foundation
import Testing
@testable import SkylineCore

/// Shafts over rooms (rooms make way) and resizing shafts, with exact undo.
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

    @Test func aRoomInTheWayGetsNarrower() throws {
        var f = try fixture()
        let id = try office(&f, 10, 14)                                     // 10..<24
        let plan = try f.check(stairs(f, 16, 1, 2)).get()
        #expect(plan.cost == 7 * 4 * 2)                                       // only the shaft is paid
        #expect(plan.columns == ColumnSpan(start: 10, count: 14))              // the whole office repaints
        try f.run(stairs(f, 16, 1, 2))
        #expect(f.world.rooms[id]?.columns == ColumnSpan(start: 10, count: 6)) // the right 4 m are too narrow: gone
        #expect(f.world.rooms.count == 2)
        try f.world.validateIntegrity()
    }

    @Test func aRoomSplitsWhenBothSidesAreWideEnough() throws {
        var f = try fixture()
        let id = try office(&f, 10, 16)                                     // 10..<26
        try f.run(stairs(f, 16, 1, 2))
        #expect(f.world.rooms[id]?.columns == ColumnSpan(start: 10, count: 6))
        let piece = try #require(f.world.rooms.values.first { $0.definitionID == "office" && $0.id != id })
        #expect(piece.columns == ColumnSpan(start: 20, count: 6) && piece.floors == FloorSpan(lowest: 1, highest: 1))
        try f.world.validateIntegrity()
    }

    @Test func roomsThatWouldBeTooNarrowAndOtherShaftsBlock() throws {
        var f = try fixture()
        try office(&f, 10, 10)                                              // 10..<20: 2 m and 4 m would be left
        #expect(f.check(stairs(f, 12, 1, 2)) == .failure(.noSpaceLeft(room: "Office")))
        try f.run(stairs(f, 30, 0, 3))
        #expect(throws: ConstructionError.self) { try f.run(stairs(f, 32, 1, 2)) }
        // Rooms still cannot be placed over shafts.
        #expect(throws: ConstructionError.self) { try office(&f, 26, 8, floor: 2) }
    }

    @Test func peopleInTheRoomStepAside() throws {
        var f = try fixture()
        let id = try office(&f, 10, 16)
        let x = f.world.grid.x(ofColumn: 17)                                // where the shaft goes
        f.world.people.insert(Person(id: f.world.makePersonID(), name: "W", age: 30, role: .worker, scheduleID: "s", buildingID: f.building,
                                     homeRoom: nil, workRoom: id, place: .room(id, x: x), nextEventTick: .max, nextGoal: nil, traits: 1))
        try f.run(stairs(f, 16, 1, 2))
        guard case let .room(r, nx)? = f.world.people.values.first?.place else { Issue.record("not in a room"); return }
        #expect(r == id && nx <= f.world.grid.x(ofColumn: 16) && nx >= f.world.grid.x(ofColumn: 10))
    }

    /// Undo and redo restore the exact rooms, including the split-off piece and its id.
    @Test func undoAndRedoAreExact() throws {
        var f = try fixture()
        var history = ConstructionHistory()
        try office(&f, 10, 16)
        let before = f.world.rooms.values, cash = f.world.ledger.cash
        try history.perform(stairs(f, 16, 0, 3), engine: f.engine, world: &f.world)
        let after = f.world.rooms.values
        #expect(after.count == 3 && f.world.ledger.cash == cash - 7 * 4 * 4)
        try history.undo(engine: f.engine, world: &f.world)
        #expect(f.world.rooms.values == before && f.world.ledger.cash == cash)
        try history.redo(engine: f.engine, world: &f.world)
        #expect(f.world.rooms.values == after)
        try f.world.validateIntegrity()
    }

    @Test func shaftsGrowAndShrink() throws {
        var f = try fixture()
        var history = ConstructionHistory()
        let shaft = try #require(f.run(stairs(f, 30, 0, 1)).createdRoom)
        let office = try office(&f, 26, 14, floor: 2)                      // 26..<40, in the way on floor 2
        let cash = f.world.ledger.cash
        let grow = BuildCommand.resizeRoom(shaft, floors: FloorSpan(lowest: 0, highest: 3))
        #expect(try f.check(grow).get().cost == 7 * 4 * 2)
        try history.perform(grow, engine: f.engine, world: &f.world)
        #expect(f.world.rooms[shaft]?.floors == FloorSpan(lowest: 0, highest: 3))
        #expect(f.world.rooms[office]?.columns == ColumnSpan(start: 34, count: 6))   // 4 m left of the shaft is too narrow
        #expect(f.world.ledger.cash == cash - 56)
        // Shrinking refunds the demolition share (50 % here) of the floors removed.
        let shrink = BuildCommand.resizeRoom(shaft, floors: FloorSpan(lowest: 0, highest: 2))
        #expect(try f.check(shrink).get().cost == -14)
        try history.perform(shrink, engine: f.engine, world: &f.world)
        try history.undo(engine: f.engine, world: &f.world)
        try history.undo(engine: f.engine, world: &f.world)
        #expect(f.world.rooms[shaft]?.floors == FloorSpan(lowest: 0, highest: 1))
        #expect(f.world.rooms[office]?.columns == ColumnSpan(start: 26, count: 14) && f.world.ledger.cash == cash)
        try f.world.validateIntegrity()
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
