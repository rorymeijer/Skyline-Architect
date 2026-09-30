import Foundation
import Testing
import SkylineCore
import SkylineContent
import SkylineSimulation
@testable import SkylinePersistence

/// Format 19 (0.30): floors switched off per elevator; shafts in front of rooms.
@Suite struct SaveV19Tests {
    /// The demo tower with a stairwell in front of the lobby and two floors switched off in
    /// its elevator, run for an hour.
    func makeSave() throws -> (SaveGame, BuildCatalog) {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        let construction = ConstructionEngine(catalog: lib.buildCatalog)
        for c in try #require(lib.blueprint("demo-tower")).commands(for: building) { try construction.apply(c, to: &game.world) }
        let lobby = try #require(game.world.rooms.values.first { $0.definitionID == "lobby" })
        try construction.apply(.placeRoom(building: building.id, definition: "stairs", columns: ColumnSpan(start: lobby.columns.start + 1, count: 4),
                                          floors: FloorSpan(lowest: 0, highest: 1)), to: &game.world)
        let engine = SimulationEngine(rules: lib.simulationRules, catalog: lib.buildCatalog)
        PopulationSync.sync(&game.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        engine.replanAfterConstruction(&game.world)
        let shaft = try #require(game.world.rooms.values.first { $0.definitionID == "elevator-shaft" })
        for floor in [3, 5] { try ElevatorStops.set(floor, served: false, shaft: shaft.id, world: &game.world, rules: lib.simulationRules) }
        Leasing.fillAll(&game.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        engine.advance(&game.world, by: 3600)
        let save = SaveGame(metadata: SaveMetadata(title: "Skipped floors", savedAt: Date(timeIntervalSince1970: 1_790_100_000), gameVersion: "0.30.0"),
                            contentPacks: [ContentPackReference(id: "base", version: lib.manifest.version)],
                            activePropertyID: game.activePropertyID, world: game.world)
        return (save, lib.buildCatalog)
    }

    /// Golden fixture v19. Regenerate only deliberately:
    /// `SKYLINE_WRITE_FIXTURES=1 swift test --filter goldenFixtureV19`.
    @Test func goldenFixtureV19StillLoads() throws {
        let catalog = try ContentLibrary.loadBase().buildCatalog
        let isShaft = { (id: String) in catalog.spec(id)?.kind == .shaft }
        if ProcessInfo.processInfo.environment["SKYLINE_WRITE_FIXTURES"] == "1" {
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/save-v19.skylinesave")
            try SaveCodec.encode(makeSave().0).write(to: source)
            return
        }
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let data = try Data(contentsOf: fixtureDir.appendingPathComponent("save-v19.skylinesave"))
        let save = try SaveCodec.decode(data, availablePacks: basePacks, isShaft: isShaft)
        #expect(save.world.elevators.values.contains { $0.skippedFloors == [3, 5] })
        // The stairwell stands in front of the lobby: without knowing shafts the overlap is refused.
        #expect(throws: SaveError.self) { try SaveCodec.decode(data, availablePacks: basePacks) }
    }

    @Test func saveRoundTrips() throws {
        let (save, catalog) = try makeSave()
        let decoded = try SaveCodec.decode(SaveCodec.encode(save), availablePacks: basePacks, isShaft: { catalog.spec($0)?.kind == .shaft })
        #expect(decoded == save)
    }
}
