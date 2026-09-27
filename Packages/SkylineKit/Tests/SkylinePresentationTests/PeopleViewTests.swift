import Testing
import SkylineCore
@testable import SkylinePresentation

@Suite struct PeopleViewTests {
    func world() throws -> (GameWorld, PropertyID, RoomID) {
        var w = GameWorld()
        let city = w.addCity(definitionID: "c", name: "C", seed: 1)
        let prop = try w.addProperty(cityID: city, name: "P", plot: Plot(frontage: ColumnSpan(start: 0, count: 40), maxBasementFloors: 1, siteMargin: 0,
                                                                          strata: [SoilStratum(material: .clay, thickness: 5), SoilStratum(material: .bedrock, thickness: 1)]))
        let b = try w.addBuilding(propertyID: prop, name: "B", footprint: ColumnSpan(start: 0, count: 40), foundation: Foundation(basementFloors: 0, pileDepth: 10, pileSpacing: 4))
        let catalog = BuildCatalog(rules: BuildRules(slabCostPerModule: 1, basementSlabCostPerModule: 1, maxCantileverModules: 0, demolitionRefund: 0),
                                   specs: [RoomSpec(id: "r", name: "R", category: "c", kind: .room, appearance: "office", minWidth: 1, maxWidth: 40, minFloors: 1, maxFloors: 1, costPerModule: 1)])
        let engine = ConstructionEngine(catalog: catalog)
        try engine.apply(.buildFloor(building: b, level: 0, span: ColumnSpan(start: 0, count: 40)), to: &w)
        let room = try engine.apply(.placeRoom(building: b, definition: "r", columns: ColumnSpan(start: 0, count: 10), floors: FloorSpan(lowest: 0, highest: 0)), to: &w).createdRoom!
        let walker = Person(id: w.makePersonID(), name: "W", age: 30, role: .worker, scheduleID: "s", buildingID: b, homeRoom: nil, workRoom: room,
                            place: .travelling(legs: [.walk(floor: 0, fromX: 20, toX: 30, start: 0, end: 10)], destination: .room(room, x: 5)),
                            nextEventTick: 10, nextGoal: nil, traits: 7)
        let sitter = Person(id: w.makePersonID(), name: "S", age: 40, role: .worker, scheduleID: "s", buildingID: b, homeRoom: nil, workRoom: room,
                            place: .room(room, x: 5), nextEventTick: 99, nextGoal: .outside, traits: 8)
        let away = Person(id: w.makePersonID(), name: "A", age: 50, role: .worker, scheduleID: "s", buildingID: b, homeRoom: nil, workRoom: room,
                          place: .outside, nextEventTick: 99, nextGoal: .work, traits: 9)
        for p in [walker, sitter, away] { w.people.insert(p) }
        return (w, prop, room)
    }

    @Test func positionsInterpolateAndOutsideIsHidden() throws {
        let (w, prop, _) = try world()
        let view = Rect(minX: 0, minY: -5, maxX: 40, maxY: 10)
        let s = PeopleView.visible(world: w, propertyID: prop, time: 5.5, visible: view, zoom: 20)
        #expect(s.count == 2)
        let walker = try #require(s.first { $0.pose == .walking })
        #expect(abs(walker.position.x - 25.5) < 1e-9)   // fractional tick → interpolated
        #expect(walker.facing == 1)
    }

    @Test func cullingAndRenderLOD() throws {
        let (w, prop, _) = try world()
        #expect(PeopleView.visible(world: w, propertyID: prop, time: 5, visible: Rect(minX: 0, minY: -5, maxX: 40, maxY: 10), zoom: 2).isEmpty)
        let right = PeopleView.visible(world: w, propertyID: prop, time: 5, visible: Rect(minX: 20, minY: -5, maxX: 40, maxY: 10), zoom: 20)
        #expect(right.count == 1)
    }

    @Test func looksAreDeterministicAndFiguresHaveContent() {
        let a = PersonLook(traits: 1234, role: .worker), b = PersonLook(traits: 1234, role: .worker)
        #expect(a == b)
        for frame in 0..<PersonArt.walkFrames {
            let d = PersonArt.figure(a, pose: .walking, frame: frame)
            #expect(d.items.count > 8)
            #expect(d.bounds.maxY <= PersonArt.height + 0.05 && d.bounds.minY >= -0.01)
        }
    }
}
