import Foundation
import Testing
import SkylineCore
@testable import SkylineContent

/// The community mods in the repository's top-level `Mods/` folder: each one loads on its own
/// over the base pack, adds content without replacing base entries, and is playable.
@Suite struct CommunityModsTests {
    static let modsURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Mods")

    /// Mods whose purpose is a rule change: they replace one whole rules file.
    static let ruleMods: [String: String] = [
        "hard-economy": "economy", "relaxed-builder": "build rules",
        "extreme-weather": "weather", "disaster-mode": "events",
    ]

    var folders: [URL] { ModLoader.discover(in: Self.modsURL) }

    func load(_ ids: [String]) throws -> ModLoader.Result {
        try ModLoader.load(mods: folders, enabled: ids)
    }

    @Test func thereAreTwentyFourMods() {
        #expect(folders.count == 24)
    }

    @Test func everyModLoadsOnItsOwn() throws {
        for folder in folders {
            let id = folder.lastPathComponent
            let result = try load([id])
            let status = try #require(result.packs.first { $0.id == id }, "\(id) has a pack.json with another id")
            #expect(status.state == .active, "\(id): \(status.state)")
            #expect(!status.changes.added.isEmpty || Self.ruleMods[id] != nil, "\(id) adds nothing")
            // Base entries are never replaced; a rule mod replaces exactly its one rules file.
            #expect(status.changes.replaced == Self.ruleMods[id].map { [$0] } ?? [], "\(id) replaces \(status.changes.replaced)")
        }
    }

    @Test func allModsLoadTogether() throws {
        let ids = folders.map(\.lastPathComponent)
        let result = try load(ids)
        let failed = result.packs.filter { $0.state != .active }
        #expect(failed.isEmpty, "\(failed.map { "\($0.id): \($0.state)" })")
        #expect(result.library.packs.count == 25)
    }

    /// Every rentable room a mod adds has a tenant type renting it and an interior.
    @Test func newRoomsAreLeasableAndFurnished() throws {
        let base = try ContentLibrary.loadBase()
        let lib = try load(folders.map(\.lastPathComponent)).library
        let baseRooms = Set(base.buildCatalog.specs.map(\.id))
        for spec in lib.buildCatalog.specs where !baseRooms.contains(spec.id) {
            if spec.kind == .room {
                #expect(lib.artCatalog.layouts[spec.id] != nil, "\(spec.id) has no interior")
            }
            if spec.rentPerModule != nil {
                #expect(lib.simulationRules.tenantTypes.contains { $0.rooms.contains(spec.id) }, "nobody rents \(spec.id)")
            }
        }
    }

    /// Every room a mod adds can be placed at its minimum width on a floor it allows.
    @Test func newRoomsCanBePlaced() throws {
        let base = try ContentLibrary.loadBase()
        let lib = try load(folders.map(\.lastPathComponent)).library
        let baseRooms = Set(base.buildCatalog.specs.map(\.id))
        let engine = ConstructionEngine(catalog: lib.buildCatalog)
        for spec in lib.buildCatalog.specs where !baseRooms.contains(spec.id) {
            var game = try NewGameFactory.make(startID: "sandbox-quay", library: lib)
            let b = try #require(game.world.buildings(on: game.activePropertyID).first)
            for level in -1...24 {
                try engine.apply(.buildFloor(building: b.id, level: level, span: ColumnSpan(start: b.footprint.start, count: 24)), to: &game.world)
            }
            let level = min(max(spec.lowestLevel ?? 1, 1), spec.highestLevel ?? 24)
            let floors = spec.kind == .shaft ? FloorSpan(lowest: -1, highest: 4) : FloorSpan(lowest: level, highest: level)
            #expect(throws: Never.self, "\(spec.id)") {
                try engine.apply(.placeRoom(building: b.id, definition: spec.id,
                                            columns: ColumnSpan(start: b.footprint.start, count: spec.minWidth),
                                            floors: floors), to: &game.world)
            }
            try game.world.validateIntegrity()
        }
    }

    @Test func modScenariosStart() throws {
        let lib = try load(folders.map(\.lastPathComponent)).library
        let base = try ContentLibrary.loadBase()
        let added = lib.orderedScenarios.filter { s in base.scenario(s.id) == nil }
        #expect(added.count == 9)
        for s in added {
            let game = try NewGameFactory.make(scenarioID: s.id, library: lib)
            #expect(game.world.scenario?.id == s.id)
            try game.world.validateIntegrity()
        }
    }

    @Test func quickStartBlueprintsBuild() throws {
        let lib = try load(["quick-starts"]).library
        let engine = ConstructionEngine(catalog: lib.buildCatalog)
        for id in ["quick-starts-starter-office", "quick-starts-residential-tower", "quick-starts-mixed-tower"] {
            var game = try NewGameFactory.make(startID: "sandbox-quay", library: lib)
            let tower = try #require(game.world.buildings(on: game.activePropertyID).first)
            for c in try #require(lib.blueprint(id)).commands(for: tower) { try engine.apply(c, to: &game.world) }
            #expect(game.world.rooms.values.contains { $0.definitionID == "lobby" }, "\(id)")
            try game.world.validateIntegrity()
        }
    }
}
