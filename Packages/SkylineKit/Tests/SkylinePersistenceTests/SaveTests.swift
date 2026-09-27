import Foundation
import Testing
import SkylineCore
import SkylineContent
@testable import SkylinePersistence

/// A realistic save: the default start with the demo tower built through the engine.
func makeDemoSave(savedAt: Date = Date(timeIntervalSince1970: 1_790_000_000)) throws -> SaveGame {
    let lib = try ContentLibrary.loadBase()
    var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
    let building = try #require(game.world.buildings(on: game.activePropertyID).first)
    let engine = ConstructionEngine(catalog: lib.buildCatalog)
    for c in try #require(lib.blueprint("demo-tower")).commands(for: building) { try engine.apply(c, to: &game.world) }
    return SaveGame(metadata: SaveMetadata(title: "Demo", savedAt: savedAt, gameVersion: "0.2.0"),
                    contentPacks: [ContentPackReference(id: "base", version: lib.manifest.version)],
                    activePropertyID: game.activePropertyID, world: game.world)
}

let basePacks = [ContentPackReference(id: "base", version: "0.1.0")]

@Suite struct SaveCodecTests {
    @Test func roundTripPreservesWorldExactly() throws {
        let save = try makeDemoSave()
        let data = try SaveCodec.encode(save)
        let loaded = try SaveCodec.decode(data, availablePacks: basePacks)
        #expect(loaded == save)
        // Deterministic bytes: encoding the loaded save reproduces the file.
        #expect(try SaveCodec.encode(loaded) == data)
    }

    @Test func loadedWorldKeepsAllocatingFreshIDs() throws {
        let save = try makeDemoSave()
        var loaded = try SaveCodec.decode(SaveCodec.encode(save), availablePacks: basePacks)
        let before = Set(loaded.world.rooms.map(\.id.raw))
        let city = loaded.world.addCity(definitionID: "x", name: "X", seed: 1)
        #expect(!before.contains(city.raw))
    }

    @Test func refusesNewerFormats() throws {
        let data = try SaveCodec.encode(makeDemoSave())
        var tree = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        tree["formatVersion"] = SaveCodec.currentVersion + 1
        let newer = try JSONSerialization.data(withJSONObject: tree)
        #expect(throws: SaveError.newerFormat(found: SaveCodec.currentVersion + 1, supported: SaveCodec.currentVersion)) {
            try SaveCodec.decode(newer, availablePacks: basePacks)
        }
    }

    @Test func refusesNonSaves() {
        #expect(throws: SaveError.notASave) { try SaveCodec.decode(Data("hello".utf8), availablePacks: basePacks) }
        #expect(throws: SaveError.notASave) {
            try SaveCodec.decode(Data(#"{"format":"other","formatVersion":1,"game":{}}"#.utf8), availablePacks: basePacks)
        }
    }

    @Test func refusesMissingContentPacks() throws {
        let data = try SaveCodec.encode(makeDemoSave())
        #expect(throws: SaveError.missingContentPack("base")) { try SaveCodec.decode(data, availablePacks: []) }
    }

    /// A save whose world is inconsistent (rooms on a floor that no longer exists) must be
    /// rejected. The corruption is made in the JSON, exactly as a damaged file would be.
    @Test func refusesInconsistentWorlds() throws {
        let data = try SaveCodec.encode(makeDemoSave())
        var root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var game = try #require(root["game"] as? [String: Any])
        var world = try #require(game["world"] as? [String: Any])
        var buildings = try #require(world["buildings"] as? [[String: Any]])
        let floors = try #require(buildings[0]["floors"] as? [[String: Any]])
        buildings[0]["floors"] = floors.filter { ($0["level"] as? Int) != 3 }
        world["buildings"] = buildings
        game["world"] = world
        root["game"] = game
        let corrupted = try JSONSerialization.data(withJSONObject: root)
        var rejected = false
        do { _ = try SaveCodec.decode(corrupted, availablePacks: basePacks) } catch SaveError.invalidWorld {
            rejected = true
        }
        #expect(rejected)
    }

    @Test func truncatedFilesAreReportedAsDamaged() throws {
        let data = try SaveCodec.encode(makeDemoSave())
        let truncated = data.prefix(data.count - 40) + Data("}}".utf8)
        #expect(throws: SaveError.self) { try SaveCodec.decode(truncated, availablePacks: basePacks) }
    }

    /// Migration harness: pretend the current format is one newer and register a step that
    /// renames the save title. Real migrations follow exactly this pattern.
    @Test func migrationsRunStepByStep() throws {
        let data = try SaveCodec.encode(makeDemoSave())
        let current = SaveCodec.currentVersion
        let migrations: [Int: SaveCodec.Migration] = [
            current: { game in
                var meta = game["metadata"] as? [String: Any] ?? [:]
                meta["title"] = "Migrated"
                game["metadata"] = meta
            },
        ]
        let upgraded = try SaveCodec.decode(data, availablePacks: basePacks, migrations: migrations, currentVersion: current + 1)
        #expect(upgraded.metadata.title == "Migrated")
        #expect(throws: SaveError.noMigration(from: current)) {
            try SaveCodec.decode(data, availablePacks: basePacks, migrations: [:], currentVersion: current + 1)
        }
    }

    /// The real v1 → v2 step adds an empty population and a clock at tick 0.
    @Test func v1SavesUpgradeToV2() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v1.skylinesave")), availablePacks: basePacks)
        #expect(save.world.people.isEmpty)
        #expect(save.world.clock.tick == 0)
    }

    /// Golden fixture: a format-1 save committed to the repository must load forever.
    /// Regenerate only deliberately: `SKYLINE_WRITE_FIXTURES=1 swift test --filter goldenFixture`.
    @Test func goldenFixtureV1StillLoads() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let url = fixtureDir.appendingPathComponent("save-v1.skylinesave")
        if ProcessInfo.processInfo.environment["SKYLINE_WRITE_FIXTURES"] == "1" {
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/save-v1.skylinesave")
            try SaveCodec.encode(makeDemoSave()).write(to: source)
            return
        }
        let save = try SaveCodec.decode(Data(contentsOf: url), availablePacks: basePacks)
        #expect(save.metadata.title == "Demo")
        #expect(save.world.rooms.count > 30)
        #expect(save.world.buildings.values.first?.builtLevels == FloorSpan(lowest: -1, highest: 8))
    }
}

@Suite struct SaveStoreTests {
    func tempStore() -> SaveStore {
        SaveStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("skyline-saves-\(UUID().uuidString)"))
    }

    @Test func writeListLoadAndDelete() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        try store.write(makeDemoSave(savedAt: Date(timeIntervalSince1970: 100)), slot: "older")
        try store.write(makeDemoSave(savedAt: Date(timeIntervalSince1970: 200)), slot: "newer")
        #expect(store.list().map(\.slot) == ["newer", "older"])
        let loaded = try store.load(slot: "older", availablePacks: basePacks)
        #expect(loaded.metadata.savedAt == Date(timeIntervalSince1970: 100))
        try store.delete(slot: "older")
        #expect(store.list().map(\.slot) == ["newer"])
        #expect(throws: SaveStoreError.notFound("older")) { try store.load(slot: "older", availablePacks: basePacks) }
    }

    @Test func autosavesRotate() throws {
        let store = tempStore()
        defer { try? FileManager.default.removeItem(at: store.directory) }
        for t in 1...5 { try store.writeAutosave(makeDemoSave(savedAt: Date(timeIntervalSince1970: Double(t))), keep: 3) }
        let slots = store.list()
        #expect(slots.map(\.slot) == ["autosave-1", "autosave-2", "autosave-3"])
        #expect(slots.map { $0.metadata?.savedAt.timeIntervalSince1970 } == [5, 4, 3])
        #expect(slots.allSatisfy { $0.isAutosave })
    }

    @Test func rejectsPathLikeSlotNames() {
        let store = tempStore()
        #expect(throws: SaveStoreError.invalidSlotName("../evil")) { try store.url(for: "../evil") }
        #expect(throws: SaveStoreError.invalidSlotName("")) { try store.url(for: "") }
    }
}
