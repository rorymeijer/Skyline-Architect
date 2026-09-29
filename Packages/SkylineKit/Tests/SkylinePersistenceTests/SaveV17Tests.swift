import Foundation
import Testing
import SkylineCore
import SkylineContent
import SkylineSimulation
@testable import SkylinePersistence

/// Format 17 (Phase E): unit rents, city tax and energy levels, energy prices, broken-down
/// cars, and the taxes and waste ledger columns.
@Suite struct SaveV17Tests {
    /// The demo plaza after its first closing, with a unit rent raised and an elevator broken.
    func makeOperatingSave() throws -> SaveGame {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        let construction = ConstructionEngine(catalog: lib.buildCatalog)
        for c in try #require(lib.blueprint("demo-plaza")).commands(for: building) { try construction.apply(c, to: &game.world) }
        let engine = SimulationEngine(rules: lib.simulationRules, catalog: lib.buildCatalog)
        PopulationSync.sync(&game.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        Leasing.fillAll(&game.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        engine.replanAfterConstruction(&game.world)
        engine.advance(&game.world, by: SimClock.secondsPerDay + 3 * 3600)              // day 2, 09:00
        let office = try #require(game.world.rooms.values.first { $0.definitionID == "office-small" })
        Economy.setRentFactor(1.3, room: office.id, in: &game.world, catalog: lib.buildCatalog)
        let car = try #require(game.world.elevators.values.first)
        game.world.upkeep.update(car.id) { $0.condition = 0.02 }
        var steps = 0
        while !game.world.elevators.values.contains(where: \.isOutOfService) && steps < 600 {
            engine.advance(&game.world, by: 30)
            steps += 1
        }
        return SaveGame(metadata: SaveMetadata(title: "Plaza operating", savedAt: Date(timeIntervalSince1970: 1_790_000_000), gameVersion: "0.23.0"),
                        contentPacks: [ContentPackReference(id: "base", version: lib.manifest.version)],
                        activePropertyID: game.activePropertyID, world: game.world)
    }

    /// Golden fixture v17. Regenerate only deliberately:
    /// `SKYLINE_WRITE_FIXTURES=1 swift test --filter goldenFixtureV17`.
    @Test func goldenFixtureV17StillLoads() throws {
        if ProcessInfo.processInfo.environment["SKYLINE_WRITE_FIXTURES"] == "1" {
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/save-v17.skylinesave")
            try SaveCodec.encode(makeOperatingSave()).write(to: source)
            return
        }
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v17.skylinesave")), availablePacks: basePacks)
        #expect(save.world.rooms.values.contains { $0.rentFactor == 1.3 })
        #expect(save.world.elevators.values.contains(where: \.isOutOfService) && save.world.facilities.breakdowns == 1)
        #expect(save.world.cities.values[0].energyPrice != nil)
        #expect(save.world.ledger.journal.contains { $0.category == .taxes } && save.world.ledger.journal.contains { $0.category == .waste })
        #expect(save.world.ledger.days.allSatisfy { $0.amounts.count == LedgerCategory.allCases.count })
    }

    @Test func operatingSaveRoundTrips() throws {
        let save = try makeOperatingSave()
        #expect(try SaveCodec.decode(SaveCodec.encode(save), availablePacks: basePacks) == save)
    }
}
