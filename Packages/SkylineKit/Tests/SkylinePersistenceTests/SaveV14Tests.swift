import Foundation
import Testing
import SkylineCore
import SkylineContent
import SkylineSimulation
@testable import SkylinePersistence

/// Format 14: weather per city and a content hash per pack.
@Suite struct SaveV14Tests {
    /// Two cities with their own weather, and a pack reference with a content hash.
    func makeTwoCitySave() throws -> SaveGame {
        let lib = try ContentLibrary.loadBase()
        var save = try makeElevatorSave()
        save.world.ledger.post(Transaction(tick: save.world.clock.tick, amount: 1_000_000, category: .grant, detail: "Fixture grant"))
        try Estate.buy("saltmere-harbour-row", world: &save.world, library: lib)
        save.world.setWeather(WeatherState(day: 0, yesterday: "rain", today: "storm", tomorrow: "overcast", temperature: 14),
                              city: save.world.cities.values[1].id)
        save.contentPacks = lib.packs.map { ContentPackReference(id: $0.id, version: $0.version, hash: $0.contentHash) }
        return save
    }

    /// Golden fixture v14. Frozen since format 15: daily totals gain the sales column,
    /// every unit is rented.
    @Test func goldenFixtureV14StillLoads() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v14.skylinesave")), availablePacks: basePacks)
        #expect(save.world.cities.values.map(\.definitionID) == ["port-calder", "saltmere"])
        #expect(save.world.cities.values[0].weather?.today == "clear")
        #expect(save.world.cities.values[1].weather?.today == "storm")
        #expect(save.contentPacks.first?.hash?.isEmpty == false)
        #expect(save.world.ledger.days.allSatisfy { $0.amounts.count == LedgerCategory.allCases.count })
        #expect(save.world.rooms.values.allSatisfy { $0.tenure == nil } && save.world.tenants.values.allSatisfy { !$0.isOwner })
    }

    @Test func twoCitySaveRoundTrips() throws {
        let save = try makeTwoCitySave()
        #expect(try SaveCodec.decode(SaveCodec.encode(save), availablePacks: basePacks) == save)
    }

    /// The pack hash is stable, and a changed file or a new version is reported on load
    /// (the save still loads).
    @Test func changedPacksAreReported() throws {
        let lib = try ContentLibrary.loadBase()
        let again = try ContentLibrary.loadBase()
        let hash = try #require(lib.packs.first?.contentHash)
        #expect(hash.count > 8 && again.packs.first?.contentHash == hash)
        let save = try makeTwoCitySave()
        let same = [ContentPackReference(id: "base", version: lib.manifest.version, hash: hash)]
        #expect(SaveCodec.changedPacks(in: save, availablePacks: same).isEmpty)
        let edited = [ContentPackReference(id: "base", version: lib.manifest.version, hash: "0")]
        #expect(SaveCodec.changedPacks(in: save, availablePacks: edited) == ["'base' \(lib.manifest.version) has changed since the save was made"])
        let newer = [ContentPackReference(id: "base", version: "9.0.0", hash: hash)]
        #expect(SaveCodec.changedPacks(in: save, availablePacks: newer).first?.contains("version 9.0.0") == true)
        // Saves without a hash (format ≤ 13) compare versions only.
        var old = save
        old.contentPacks = [ContentPackReference(id: "base", version: lib.manifest.version)]
        #expect(SaveCodec.changedPacks(in: old, availablePacks: edited).isEmpty)
        #expect(try SaveCodec.decode(SaveCodec.encode(save), availablePacks: edited).contentPacks == save.contentPacks)
    }
}
