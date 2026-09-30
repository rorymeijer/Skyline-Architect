import Foundation
import Testing
import SkylineCore
import SkylineContent
import SkylineSimulation
@testable import SkylinePersistence

/// Format 20 (0.30): hotel guests, stays, rooms awaiting housekeeping, housekeepers (0.30.1,
/// before 0.30 shipped) and the hotel ledger category.
@Suite struct SaveV20Tests {
    /// The demo tower with a top floor of hotel rooms, run from the morning to 22:00 so
    /// guests have booked and arrived.
    func makeSave() throws -> (SaveGame, BuildCatalog) {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let b = try #require(game.world.buildings(on: game.activePropertyID).first)
        let construction = ConstructionEngine(catalog: lib.buildCatalog)
        for c in try #require(lib.blueprint("demo-tower")).commands(for: b) { try construction.apply(c, to: &game.world) }
        let built = try #require(game.world.buildings[b.id])
        let top = try #require(built.floors.map(\.level).max())
        let roof = try #require(built.plate(at: top))
        try construction.apply(.buildFloor(building: b.id, level: top + 1, span: roof.span), to: &game.world)
        let shaft = try #require(game.world.rooms.values.first { $0.definitionID == "elevator-shaft" })
        try construction.apply(.resizeRoom(shaft.id, floors: FloorSpan(lowest: shaft.floors.lowest, highest: top + 1)), to: &game.world)
        for i in 0..<2 {                                       // the top floor is 24 m wide
            try construction.apply(.placeRoom(building: b.id, definition: "hotel-twin", columns: ColumnSpan(start: roof.span.start + i * 9, count: 8),
                                              floors: FloorSpan(lowest: top + 1, highest: top + 1)), to: &game.world)
        }
        let engine = SimulationEngine(rules: lib.simulationRules, catalog: lib.buildCatalog)
        PopulationSync.sync(&game.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        FacilitiesManagement.hire(.housekeeper, building: b.id, world: &game.world, rules: lib.simulationRules)
        engine.replanAfterConstruction(&game.world)
        Leasing.fillAll(&game.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        engine.advance(&game.world, by: SimClock.secondsPerDay + 16 * 3600)          // day 2, 22:00
        let save = SaveGame(metadata: SaveMetadata(title: "Hotel", savedAt: Date(timeIntervalSince1970: 1_790_200_000), gameVersion: "0.30.0"),
                            contentPacks: [ContentPackReference(id: "base", version: lib.manifest.version)],
                            activePropertyID: game.activePropertyID, world: game.world)
        return (save, lib.buildCatalog)
    }

    /// Golden fixture v20. Regenerate only deliberately:
    /// `SKYLINE_WRITE_FIXTURES=1 swift test --filter goldenFixtureV20`.
    @Test func goldenFixtureV20StillLoads() throws {
        let catalog = try ContentLibrary.loadBase().buildCatalog
        if ProcessInfo.processInfo.environment["SKYLINE_WRITE_FIXTURES"] == "1" {
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/save-v20.skylinesave")
            try SaveCodec.encode(makeSave().0).write(to: source)
            return
        }
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v20.skylinesave")), availablePacks: basePacks,
                                        isShaft: { catalog.spec($0)?.kind == .shaft })
        let hotel = try #require(save.world.hotel)
        #expect(!hotel.stays.isEmpty && hotel.nights >= 1)
        #expect(save.world.people.values.contains { $0.role == .guest } && save.world.people.values.contains { $0.role == .housekeeper })
        #expect(save.world.ledger.days.allSatisfy { $0.amounts.count == LedgerCategory.allCases.count })
    }

    /// A v19 save gains the hotel category in its daily totals.
    @Test func v19DailyTotalsArePadded() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let catalog = try ContentLibrary.loadBase().buildCatalog
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v19.skylinesave")), availablePacks: basePacks,
                                        isShaft: { catalog.spec($0)?.kind == .shaft })
        #expect(save.world.ledger.days.allSatisfy { $0.amounts.count == 15 } && save.world.hotel == nil)
    }

    @Test func saveRoundTrips() throws {
        let (save, catalog) = try makeSave()
        let decoded = try SaveCodec.decode(SaveCodec.encode(save), availablePacks: basePacks, isShaft: { catalog.spec($0)?.kind == .shaft })
        #expect(decoded == save)
    }
}
