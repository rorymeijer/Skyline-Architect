import Testing
import SkylineCore
import SkylineContent
@testable import SkylinePresentation

@Suite struct DayNightTests {
    @Test func daylightFollowsTheClock() {
        #expect(DayNight.daylight(secondOfDay: 3 * 3600) == 0)
        #expect(DayNight.daylight(secondOfDay: 12 * 3600) == 1)
        #expect(DayNight.daylight(secondOfDay: 23 * 3600) == 0)
        let dawn = DayNight.daylight(secondOfDay: 6.5 * 3600), dusk = DayNight.daylight(secondOfDay: 19.5 * 3600)
        #expect(dawn > 0.3 && dawn < 0.7 && dusk > 0.3 && dusk < 0.7)
        #expect(DayNight.daylight(atTick: 0) < DayNight.daylight(atTick: 3600))        // tick 0 is 06:00
        #expect(DayNight.ambient(daylight: 1) == RGBA(1, 1, 1))
        #expect(DayNight.ambient(daylight: 0).b > DayNight.ambient(daylight: 0).r)      // blue night
    }

    @Test func occupiedRoomsGlowAtNight() throws {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let b = game.world.buildings(on: game.activePropertyID).first!
        let engine = ConstructionEngine(catalog: lib.buildCatalog)
        for c in lib.blueprint("demo-tower")!.commands(for: b) { try engine.apply(c, to: &game.world) }
        let studio = game.world.rooms.values.first { $0.definitionID == "apartment-studio" }!
        game.world.people.insert(Person(id: game.world.makePersonID(), name: "N", age: 40, role: .resident, scheduleID: "s",
                                        buildingID: b.id, homeRoom: studio.id, workRoom: nil, place: .room(studio.id, x: 1),
                                        nextEventTick: .max, nextGoal: nil, traits: 1))
        let view = Rect(minX: -100, minY: -20, maxX: 200, maxY: 100)
        let night = 17.0 * 3600, noon = 6.0 * 3600                 // 23:00 and 12:00
        let lit = DayNight.litRooms(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, time: night, visible: view)
        #expect(lit.contains { $0.rect == game.world.grid.rect(columns: studio.columns, floors: studio.floors) && $0.intensity > 0.9 })
        #expect(lit.contains { $0.intensity > 0.3 && $0.intensity < 0.5 })   // lobbies
        #expect(DayNight.litRooms(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, time: noon, visible: view).isEmpty)
    }

    @Test func previewRefusesWhatCannotBePaid() throws {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        game.world.ledger.post(Transaction(tick: 0, amount: -game.world.ledger.cash + 100, category: .grant, detail: "Spend"))
        let b = game.world.buildings(on: game.activePropertyID).first!
        let preview = try #require(PlacementPlanner.preview(tool: .floor, anchor: GridCell(column: b.footprint.start, floor: 0),
                                                            current: GridCell(column: b.footprint.start + 10, floor: 0),
                                                            world: game.world, propertyID: game.activePropertyID,
                                                            engine: ConstructionEngine(catalog: lib.buildCatalog)))
        #expect(!preview.isValid && preview.label.contains("not enough money"))
    }
}
