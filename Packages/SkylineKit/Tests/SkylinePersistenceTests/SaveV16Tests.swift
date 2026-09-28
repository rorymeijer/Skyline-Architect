import Foundation
import Testing
import SkylineCore
import SkylineContent
import SkylineSimulation
@testable import SkylinePersistence

/// Format 16: amenities — visitors, lunch and leisure goals, takings and the turnover share.
@Suite struct SaveV16Tests {
    /// The demo plaza, all leased, on its second evening: the first closing has paid the
    /// turnover share, and visitors are in the cinema, theatre and sky bar.
    func makeAmenitySave() throws -> SaveGame {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        let construction = ConstructionEngine(catalog: lib.buildCatalog)
        for c in try #require(lib.blueprint("demo-plaza")).commands(for: building) { try construction.apply(c, to: &game.world) }
        let engine = SimulationEngine(rules: lib.simulationRules, catalog: lib.buildCatalog)
        PopulationSync.sync(&game.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        Leasing.fillAll(&game.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        engine.replanAfterConstruction(&game.world)
        engine.advance(&game.world, by: SimClock.secondsPerDay + 14 * 3600 + 15 * 60)        // day 2, 20:15
        return SaveGame(metadata: SaveMetadata(title: "Plaza", savedAt: Date(timeIntervalSince1970: 1_790_000_000), gameVersion: "0.22.0"),
                        contentPacks: [ContentPackReference(id: "base", version: lib.manifest.version)],
                        activePropertyID: game.activePropertyID, world: game.world)
    }

    /// Golden fixture v16. Regenerate only deliberately:
    /// `SKYLINE_WRITE_FIXTURES=1 swift test --filter goldenFixtureV16`.
    @Test func goldenFixtureV16StillLoads() throws {
        if ProcessInfo.processInfo.environment["SKYLINE_WRITE_FIXTURES"] == "1" {
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/save-v16.skylinesave")
            try SaveCodec.encode(makeAmenitySave()).write(to: source)
            return
        }
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v16.skylinesave")), availablePacks: basePacks)
        let visitors = save.world.people.values.filter { $0.role == .visitor }
        #expect(!visitors.isEmpty && visitors.allSatisfy { $0.visit != nil })
        #expect(save.world.tenants.values.contains { ($0.sales?.lastTakings ?? 0) > 0 })
        #expect(save.world.ledger.journal.contains { $0.category == .turnover && $0.amount > 0 })
        #expect(save.world.ledger.days.allSatisfy { $0.amounts.count == LedgerCategory.allCases.count })
    }

    @Test func amenitySaveRoundTrips() throws {
        let save = try makeAmenitySave()
        #expect(try SaveCodec.decode(SaveCodec.encode(save), availablePacks: basePacks) == save)
    }
}
