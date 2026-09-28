import Foundation
import Testing
import SkylineCore
import SkylineContent
import SkylineSimulation
@testable import SkylinePersistence

/// Format 15: flats for sale, sold flats and their owners, the sales ledger column.
@Suite struct SaveV15Tests {
    /// The elevator save with its studios' tenants gone: one sold (owner inside), one for sale.
    func makeSalesSave() throws -> SaveGame {
        let lib = try ContentLibrary.loadBase()
        var save = try makeElevatorSave()
        let rules = lib.simulationRules, catalog = lib.buildCatalog
        let studios = save.world.rooms.values.filter { $0.definitionID == "apartment-studio" }.sorted { $0.id < $1.id }
        for s in studios.prefix(2) {
            if let t = save.world.tenants.values.first(where: { $0.room == s.id }) { Leasing.moveOut(t.id, world: &save.world) }
            try Leasing.setTenure(.forSale, room: s.id, world: &save.world, rules: rules, catalog: catalog)
        }
        let couple = try #require(rules.tenantType("couple"))
        let sold = try #require(save.world.rooms[studios[0].id])
        Leasing.sign(couple, into: sold, at: save.world.clock.tick, world: &save.world, rules: rules, catalog: catalog, satisfaction: 0.7)
        return save
    }

    /// Golden fixture v15. Regenerate only deliberately:
    /// `SKYLINE_WRITE_FIXTURES=1 swift test --filter goldenFixtureV15`.
    @Test func goldenFixtureV15StillLoads() throws {
        if ProcessInfo.processInfo.environment["SKYLINE_WRITE_FIXTURES"] == "1" {
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/save-v15.skylinesave")
            try SaveCodec.encode(makeSalesSave()).write(to: source)
            return
        }
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v15.skylinesave")), availablePacks: basePacks)
        #expect(save.world.rooms.values.filter { $0.tenure == .owned }.count == 1)
        #expect(save.world.rooms.values.filter { $0.tenure == .forSale }.count == 1)
        let owner = try #require(save.world.tenants.values.first { $0.isOwner })
        #expect((owner.purchasePrice ?? 0) > 0 && save.world.rooms[owner.room]?.tenure == .owned)
        #expect(save.world.ledger.journal.contains { $0.category == .sales && $0.amount == owner.purchasePrice })
    }

    @Test func salesSaveRoundTrips() throws {
        let save = try makeSalesSave()
        #expect(try SaveCodec.decode(SaveCodec.encode(save), availablePacks: basePacks) == save)
    }
}
