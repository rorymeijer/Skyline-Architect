import Foundation
import Testing
import SkylineCore
import SkylineContent
import SkylineSimulation
@testable import SkylinePersistence

/// Format 18 (Phase C): scenario restrictions, scripted events, news, demand shocks, scores.
@Suite struct SaveV18Tests {
    /// Opening Day with the demo tower, won with stars after its first events fired; the
    /// restrictions of Lean Tower added so they round-trip too.
    func makeScenarioSave() throws -> SaveGame {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(scenarioID: "opening-day", library: lib)
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        let construction = ConstructionEngine(catalog: lib.buildCatalog)
        for c in try #require(lib.blueprint("demo-tower")).commands(for: building) { try construction.apply(c, to: &game.world) }
        let engine = SimulationEngine(rules: lib.simulationRules, catalog: lib.buildCatalog)
        PopulationSync.sync(&game.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        engine.replanAfterConstruction(&game.world)
        Leasing.fillAll(&game.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        engine.advance(&game.world, by: 4 * SimClock.secondsPerDay)
        game.world.scenario?.restrictions = lib.scenario("lean-tower")?.restrictions
        return SaveGame(metadata: SaveMetadata(title: "Opening Day", savedAt: Date(timeIntervalSince1970: 1_790_000_000), gameVersion: "0.24.0"),
                        contentPacks: [ContentPackReference(id: "base", version: lib.manifest.version)],
                        activePropertyID: game.activePropertyID, world: game.world)
    }

    /// Golden fixture v18. Regenerate only deliberately:
    /// `SKYLINE_WRITE_FIXTURES=1 swift test --filter goldenFixtureV18`.
    @Test func goldenFixtureV18StillLoads() throws {
        if ProcessInfo.processInfo.environment["SKYLINE_WRITE_FIXTURES"] == "1" {
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/save-v18.skylinesave")
            try SaveCodec.encode(makeScenarioSave()).write(to: source)
            return
        }
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v18.skylinesave")), availablePacks: basePacks)
        let s = try #require(save.world.scenario)
        #expect(s.result?.won == true && (s.result?.stars ?? 0) >= 1 && (s.result?.score ?? 0) > 0)
        #expect(s.events?.count == 3 && !(s.news ?? []).isEmpty && !(s.fired ?? []).isEmpty && s.startDay == 0)
        #expect(s.restrictions?.forbids("apartment-studio") == true && s.restrictions?.maxFloor == 12)
    }

    @Test func scenarioSaveRoundTrips() throws {
        let save = try makeScenarioSave()
        #expect(try SaveCodec.decode(SaveCodec.encode(save), availablePacks: basePacks) == save)
    }
}
