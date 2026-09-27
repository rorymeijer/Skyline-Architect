import Testing
import SkylineCore
@testable import SkylinePresentation

@Suite struct ElevatorViewTests {
    /// One building, floors 0…3, an elevator shaft at columns 10…12, a car moving 0 → 3 with
    /// one rider, and two people queuing on floor 2.
    func world() throws -> (GameWorld, PropertyID, RoomID, [PersonID]) {
        var w = GameWorld()
        let city = w.addCity(definitionID: "c", name: "C", seed: 1)
        let prop = try w.addProperty(cityID: city, name: "P", plot: Plot(frontage: ColumnSpan(start: 0, count: 40), maxBasementFloors: 1, siteMargin: 0,
                                                                          strata: [SoilStratum(material: .clay, thickness: 5), SoilStratum(material: .bedrock, thickness: 1)]))
        let b = try w.addBuilding(propertyID: prop, name: "B", footprint: ColumnSpan(start: 0, count: 40), foundation: Foundation(basementFloors: 0, pileDepth: 10, pileSpacing: 4))
        let catalog = BuildCatalog(rules: BuildRules(slabCostPerModule: 1, basementSlabCostPerModule: 1, maxCantileverModules: 0, demolitionRefund: 0),
                                   specs: [RoomSpec(id: "lift", name: "Lift", category: "c", kind: .shaft, appearance: "elevatorShaft", minWidth: 3, maxWidth: 3,
                                                    minFloors: 2, maxFloors: 10, costPerModule: 1)])
        let engine = ConstructionEngine(catalog: catalog)
        for level in 0...3 { try engine.apply(.buildFloor(building: b, level: level, span: ColumnSpan(start: 0, count: 40)), to: &w) }
        let shaft = try engine.apply(.placeRoom(building: b, definition: "lift", columns: ColumnSpan(start: 10, count: 3),
                                                floors: FloorSpan(lowest: 0, highest: 3)), to: &w).createdRoom!
        var car = ElevatorCar(id: shaft, buildingID: b, floor: 0)
        car.motion = .moving(fromFloor: 0, toFloor: 3, start: 0, end: 8, speed: 2.5, acceleration: 1)
        var ids: [PersonID] = []
        func person(_ place: Place, traits: UInt32) -> Person {
            let p = Person(id: w.makePersonID(), name: "P", age: 30, role: .worker, scheduleID: "s", buildingID: b, homeRoom: nil,
                           workRoom: nil, place: place, nextEventTick: .max, nextGoal: nil, traits: traits)
            ids.append(p.id)
            return p
        }
        let ride = Ride(shaft: shaft, fromFloor: 0, toFloor: 3, x: 11.5)
        let rider = person(.riding(ride, destination: .outside), traits: 1)
        car.passengers = [rider.id]
        let down = Ride(shaft: shaft, fromFloor: 2, toFloor: 0, x: 11.5)
        let second = person(.waiting(down, destination: .outside, since: 5), traits: 2)
        let first = person(.waiting(down, destination: .outside, since: 3), traits: 3)
        for p in [rider, second, first] { w.people.insert(p) }
        w.elevators.insert(car)
        try w.validateIntegrity()
        return (w, prop, shaft, ids)
    }

    @Test func carsMoveAndRidersMoveWithThem() throws {
        let (w, prop, _, ids) = try world()
        let view = Rect(minX: 0, minY: -5, maxX: 40, maxY: 20)
        let atStart = ElevatorView.visible(world: w, propertyID: prop, time: 0, visible: view, zoom: 20)
        let later = ElevatorView.visible(world: w, propertyID: prop, time: 4, visible: view, zoom: 20)
        #expect(atStart.count == 1 && atStart[0].rect.minY == 0 && atStart[0].doorStep == 0)
        #expect(atStart[0].rect.minX == 10.45 && abs(atStart[0].rect.maxX - 12.55) < 1e-9)
        #expect(later[0].rect.minY > 0 && later[0].rect.minY < 12)
        let people = PeopleView.visible(world: w, propertyID: prop, time: 4, visible: view, zoom: 20)
        let rider = try #require(people.first { $0.id == ids[0] })
        #expect(abs(rider.position.y - (later[0].rect.minY + 0.08)) < 1e-9)
        // Queue: earlier arrival stands nearest the doors.
        let first = try #require(people.first { $0.id == ids[2] }), second = try #require(people.first { $0.id == ids[1] })
        #expect(first.position.x > second.position.x)
        #expect(first.position.y == 8.08)
        #expect(ElevatorView.visible(world: w, propertyID: prop, time: 4, visible: view, zoom: 2).isEmpty)
    }

    @Test func doorsOpenAndCloseInSteps() throws {
        var (w, prop, shaft, _) = try world()
        w.elevators.update(shaft) { $0.motion = .stopped(since: 10, until: 20); $0.floor = 3 }
        let view = Rect(minX: 0, minY: -5, maxX: 40, maxY: 20)
        let steps = [10.0, 11, 12, 15, 19, 20].map {
            ElevatorView.visible(world: w, propertyID: prop, time: $0, visible: view, zoom: 20)[0].doorStep
        }
        #expect(steps == [0, 2, 4, 4, 2, 0])
        #expect(!ElevatorArt.cab(width: 2.1, opening: 0).items.isEmpty)
        #expect(ElevatorArt.cab(width: 2.1, opening: 1).items.count < ElevatorArt.cab(width: 2.1, opening: 0).items.count)
    }
}
