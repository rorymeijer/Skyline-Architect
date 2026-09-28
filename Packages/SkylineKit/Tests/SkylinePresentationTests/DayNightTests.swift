import Testing
import SkylineCore
import SkylineContent
@testable import SkylinePresentation

@Suite struct DayNightTests {
    @Test func daylightFollowsTheClock() {
        #expect(DayNight.daylight(secondOfDay: 3 * 3600) == 0)
        #expect(DayNight.daylight(secondOfDay: 12 * 3600) == 1)
        #expect(DayNight.daylight(secondOfDay: 23 * 3600) == 0)
        let dawn = DayNight.daylight(secondOfDay: 5.5 * 3600), dusk = DayNight.daylight(secondOfDay: 20 * 3600)
        #expect(dawn > 0.3 && dawn < 0.7 && dusk > 0.3 && dusk < 0.7)
        #expect(DayNight.daylight(atTick: 0) > 0.9)                                    // tick 0 is 06:00: light
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
        let evening = 16.0 * 3600, late = 20.0 * 3600, noon = 6.0 * 3600      // 22:00, 02:00 and 12:00
        let studioRect = game.world.grid.rect(columns: studio.columns, floors: studio.floors)
        let lit = DayNight.litRooms(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, time: evening, visible: view)
        let home = try #require(lit.first { $0.rect == studioRect })
        #expect(home.intensity > 0.9 && home.color == ArtCatalog.parseColor("#FFC47E"))       // warm home light from content
        #expect(lit.contains { $0.intensity > 0.3 && $0.intensity < 0.65 })                   // lobbies and corridors, dimmer
        #expect(lit.contains { $0.color != home.color })
        // Asleep at 02:00: the home is dimmed to its quiet level.
        let asleep = DayNight.litRooms(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, time: late, visible: view)
        #expect((asleep.first { $0.rect == studioRect }?.intensity ?? 0) < 0.1)
        // Without power it stays dark.
        let cut = DayNight.litRooms(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, time: evening, visible: view,
                                    power: [studio.id: 0])
        #expect(!cut.contains { $0.rect == studioRect })
        #expect(DayNight.litRooms(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, time: noon, visible: view).isEmpty)
        // Zoomed out, lit rooms become window panes on the façade.
        let far = DayNight.litRooms(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog, time: evening, visible: view,
                                    zoom: 3)
        let panes = far.filter { studioRect.contains($0.rect) }
        #expect(panes.count >= 3 && panes.allSatisfy { $0.rect.width == 1.5 && $0.rect.height < 2.5 })
    }

    @Test func gradeWarmsAtTheEdgesOfTheDay() {
        func at(_ h: Double) -> Grade { DayNight.grade(atTick: (h - 6) * 3600) }
        #expect(at(12).top == RGBA(1, 1, 1) && at(12).bottom == RGBA(1, 1, 1))       // plain daylight
        let sunset = at(19.8), sunrise = at(5.3), night = at(1)
        #expect(sunset.bottom.r > sunset.bottom.b + 0.15)                              // amber horizon
        #expect(sunset.bottom.r - sunset.bottom.b > sunset.top.r - sunset.top.b)       // warmest low
        #expect(sunrise.bottom.b / sunrise.bottom.r > sunset.bottom.b / sunset.bottom.r)   // rose, not amber
        #expect(night.top.b > night.top.r && night.bottom.b > night.bottom.r)          // blue night
        #expect(at(18.5).bottom.b < at(18.5).bottom.r)                                  // golden hour before sunset
    }

    @Test func siteHasNightLights() throws {
        let lib = try ContentLibrary.loadBase()
        let game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let a = try #require(SiteComposer.compose(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog))
        let b = try #require(SiteComposer.compose(world: game.world, propertyID: game.activePropertyID, catalog: lib.buildCatalog))
        #expect(a.emission.drawing.items.count > 500)                                  // city windows, neighbours, lamps
        #expect(a.emission.drawing.items == b.emission.drawing.items)                  // deterministic
        #expect(!a.layers.contains { $0.name == "emission" })                          // drawn separately
        let frontage = a.frontageRect
        let lamps = NightArt.lampPositions(span: -300...300, keepClear: frontage.minX...frontage.maxX)
        #expect(!lamps.isEmpty && lamps.allSatisfy { $0 < frontage.minX || $0 > frontage.maxX })
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
