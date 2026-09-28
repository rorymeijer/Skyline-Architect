import Foundation
import Testing
import SkylineCore
import SkylineContent
import SkylineSimulation
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

/// A save with a living population: the demo tower during the morning arrival (people in
/// rooms, outside and mid-trip). Deterministic: first minute after 08:00 with a traveller.
func makeLivingSave() throws -> SaveGame {
    let lib = try ContentLibrary.loadBase()
    var save = try makeDemoSave()
    PopulationSync.sync(&save.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
    Leasing.fillAll(&save.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
    let engine = SimulationEngine(rules: lib.simulationRules, catalog: lib.buildCatalog)
    engine.advance(&save.world, by: 2 * 3600)
    while !save.world.people.values.contains(where: { if case .travelling = $0.place { true } else { false } }) {
        engine.advance(&save.world, by: 60)
    }
    save.metadata.gameVersion = "0.4.0"
    return save
}

/// A save with elevator traffic: first moment after 08:00 when someone waits at a landing
/// and someone rides a car.
func makeElevatorSave() throws -> SaveGame {
    let lib = try ContentLibrary.loadBase()
    var save = try makeDemoSave()
    PopulationSync.sync(&save.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
    Leasing.fillAll(&save.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
    let engine = SimulationEngine(rules: lib.simulationRules, catalog: lib.buildCatalog)
    engine.advance(&save.world, by: 2 * 3600)
    func busy(_ w: GameWorld) -> Bool {
        w.people.values.contains { if case .waiting = $0.place { true } else { false } }
            && w.people.values.contains { if case .riding = $0.place { true } else { false } }
    }
    var guardSteps = 0
    while !busy(save.world) && guardSteps < 4 * 3600 {
        engine.advance(&save.world, by: 1)
        guardSteps += 1
    }
    save.metadata.gameVersion = "0.6.0"
    return save
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

    @Test func livingWorldRoundTrips() throws {
        let save = try makeLivingSave()
        #expect(save.world.people.count == 38)
        #expect(save.world.people.values.contains { if case .travelling = $0.place { return true } else { return false } })
        let loaded = try SaveCodec.decode(SaveCodec.encode(save), availablePacks: basePacks)
        #expect(loaded == save)
    }

    /// Golden fixture v2 (people + clock). Frozen since format 3: it upgrades on load and its
    /// elevator shafts get cars on the first simulation step.
    @Test func goldenFixtureV2StillLoads() throws {
        let lib = try ContentLibrary.loadBase()
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        var save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v2.skylinesave")), availablePacks: basePacks)
        #expect(save.world.people.count == 38)
        #expect(save.world.clock.tick >= 2 * 3600)
        #expect(save.world.elevators.isEmpty)
        SimulationEngine(rules: lib.simulationRules, catalog: lib.buildCatalog).advance(&save.world, by: 60)
        #expect(save.world.elevators.count == 1)
        try save.world.validateIntegrity()
    }

    /// Golden fixture v3 (elevator cars, people waiting and riding). Frozen since format 4:
    /// cars gain the collective strategy and empty statistics.
    @Test func goldenFixtureV3StillLoads() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v3.skylinesave")), availablePacks: basePacks)
        #expect(save.world.elevators.count == 1)
        #expect(save.world.elevators.values.allSatisfy { $0.strategy == .collective && $0.stats == CarStats() })
        #expect(save.world.people.values.contains { if case .waiting = $0.place { true } else { false } })
        #expect(save.world.people.values.contains { if case .riding = $0.place { true } else { false } })
    }

    /// Golden fixture v4 (strategies and statistics). Frozen since format 5: it loads with no
    /// tenants; the population sync then adopts its people into one tenant per room.
    @Test func goldenFixtureV4StillLoads() throws {
        let lib = try ContentLibrary.loadBase()
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        var save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v4.skylinesave")), availablePacks: basePacks)
        #expect(save.world.elevators.count == 1)
        #expect(save.world.elevators.values.allSatisfy { $0.stats.boardings > 0 })
        #expect(save.world.people.values.contains { if case .waiting = $0.place { true } else { false } })
        #expect(save.world.tenants.isEmpty)
        #expect(save.world.market.nextTick > save.world.clock.tick)
        PopulationSync.sync(&save.world, catalog: lib.buildCatalog, rules: lib.simulationRules)
        #expect(save.world.tenants.count == 15)                        // 8 offices + 7 studios
        #expect(save.world.people.values.allSatisfy { $0.tenantID != nil })
        try save.world.validateIntegrity()
    }

    /// Golden fixture v5 (tenants and market). Frozen since format 6: it loads with an empty
    /// ledger and rent level 1.
    @Test func goldenFixtureV5StillLoads() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v5.skylinesave")), availablePacks: basePacks)
        #expect(save.world.tenants.count == 15)
        #expect(save.world.people.values.allSatisfy { $0.tenantID != nil })
        #expect(save.world.market.prospects > 0)
        #expect(save.world.ledger == Ledger())
        #expect(save.world.buildings.values.allSatisfy { $0.rentLevel == 1 })
    }

    /// Golden fixture v6 (ledger, rent level). Frozen since format 7: daily totals and decline
    /// counts gain a column; upkeep is created on the next simulation step.
    @Test func goldenFixtureV6StillLoads() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v6.skylinesave")), availablePacks: basePacks)
        #expect(save.world.ledger.journal.contains { $0.category == .grant })
        #expect(save.world.ledger.cash == save.world.ledger.journal.reduce(0) { $0 + $1.amount })
        #expect(save.world.tenants.count == 15)
        #expect(save.world.ledger.days.allSatisfy { $0.amounts.count == LedgerCategory.allCases.count })
        #expect(save.world.market.declined.count == DeclineReason.allCases.count)
        #expect(save.world.upkeep.isEmpty)
    }

    /// Golden fixture v7 (upkeep, facilities). Frozen since format 8: buildings start in the
    /// first class at reputation 50 and the game keeps everything unlocked.
    @Test func goldenFixtureV7StillLoads() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v7.skylinesave")), availablePacks: basePacks)
        #expect(save.world.upkeep.count == save.world.rooms.count)
        #expect(save.world.tenants.count == 15)
        #expect(save.world.unlocks == .all)
        #expect(save.world.buildings.values.allSatisfy { $0.standing == Standing() })
    }

    /// Golden fixture v8 (standing, unlock mode). Frozen since format 9: buildings gain an
    /// empty lighting meter.
    @Test func goldenFixtureV8StillLoads() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v8.skylinesave")), availablePacks: basePacks)
        #expect(save.world.unlocks == .byClass)
        #expect(save.world.buildings.values[0].standing == Standing(classLevel: 1, reputation: 61.25, promotions: [Tick(3 * 86_400)]))
        #expect(save.world.tenants.count == 15)
        #expect(save.world.buildings.values.allSatisfy { $0.lightingKWh == 0 })
    }

    /// Golden fixture v9 (lighting meter). Frozen since format 10: loads without weather
    /// (the simulation starts it on the next step).
    @Test func goldenFixtureV9StillLoads() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v9.skylinesave")), availablePacks: basePacks)
        #expect(save.world.buildings.values[0].lightingKWh == 12.5)
        #expect(save.world.tenants.count == 15)
        #expect(save.world.weather == nil)
    }

    /// Golden fixture v10 (weather). Regenerate only deliberately:
    /// `SKYLINE_WRITE_FIXTURES=1 swift test --filter goldenFixtureV10`.
    @Test func goldenFixtureV10StillLoads() throws {
        if ProcessInfo.processInfo.environment["SKYLINE_WRITE_FIXTURES"] == "1" {
            var save = try makeElevatorSave()
            save.world.weather = WeatherState(day: 3, yesterday: "rain", today: "storm", tomorrow: "overcast", temperature: 17)
            let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/save-v10.skylinesave")
            try SaveCodec.encode(save).write(to: source)
            return
        }
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let save = try SaveCodec.decode(Data(contentsOf: fixtureDir.appendingPathComponent("save-v10.skylinesave")), availablePacks: basePacks)
        #expect(save.world.weather == WeatherState(day: 3, yesterday: "rain", today: "storm", tomorrow: "overcast", temperature: 17))
        #expect(save.world.tenants.count == 15)
    }

    @Test func elevatorWorldRoundTrips() throws {
        let save = try makeElevatorSave()
        let loaded = try SaveCodec.decode(SaveCodec.encode(save), availablePacks: basePacks)
        #expect(loaded == save)
    }

    /// Golden fixture: a format-1 save committed to the repository must load forever.
    /// It is frozen: format 1 can no longer be written, so it is never regenerated.
    @Test func goldenFixtureV1StillLoads() throws {
        let fixtureDir = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let url = fixtureDir.appendingPathComponent("save-v1.skylinesave")
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
