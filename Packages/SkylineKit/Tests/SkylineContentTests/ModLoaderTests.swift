import Foundation
import Testing
import SkylineCore
@testable import SkylineContent

@Suite struct ModLoaderTests {
    /// A temporary mods folder with copies of the example mods.
    func modsFolder() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mods-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for url in ModLoader.discover(in: BaseContent.examplesURL) {
            try FileManager.default.copyItem(at: url, to: dir.appendingPathComponent(url.lastPathComponent))
        }
        return dir
    }

    func write(_ text: String, to folder: URL, _ file: String) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try text.write(to: folder.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    func manifest(_ id: String, files: String = "{}", requires: String = "null") -> String {
        #"{"id":"\#(id)","name":"\#(id)","version":"1","formatVersion":1,"files":\#(files),"requires":\#(requires)}"#
    }

    @Test func exampleModLoadsOverTheBase() throws {
        let dir = try modsFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try ModLoader.load(mods: ModLoader.discover(in: dir), enabled: ["kestrel-bay"])
        let lib = result.library
        #expect(lib.packs.map(\.id) == ["base", "kestrel-bay"])
        #expect(lib.city("kestrel-bay")?.economy?.rent == 1.1)
        #expect(lib.plot("kestrel-pier-lot")?.price == 700_000)
        #expect(lib.buildCatalog.spec("apartment-loft")?.name == "Loft Apartment")
        #expect(lib.artCatalog.layouts["apartment-loft"] != nil)
        #expect(lib.simulationRules.tenantTypes.first { $0.id == "couple" }?.rooms == ["apartment-studio", "apartment-loft"])
        #expect(lib.simulationRules.tenantTypes.contains { $0.id == "creative-household" })
        #expect(lib.scenario("kestrel-lofts") != nil)
        let status = try #require(result.packs.first { $0.id == "kestrel-bay" })
        #expect(status.state == .active && status.name == "Kestrel Bay" && status.folder == "kestrel-bay")
        #expect(status.changes.replaced == ["tenant 'couple'"])
        #expect(status.changes.added.contains("room 'apartment-loft'") && status.changes.added.contains("city 'kestrel-bay'"))
        // Replacing keeps the base order: couple stays where it was.
        let base = try ContentLibrary.loadBase()
        #expect(Array(lib.simulationRules.tenantTypes.map(\.id).prefix(base.simulationRules.tenantTypes.count))
                == base.simulationRules.tenantTypes.map(\.id))
    }

    @Test func modContentIsPlayable() throws {
        let dir = try modsFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let lib = try ModLoader.load(mods: ModLoader.discover(in: dir), enabled: ["kestrel-bay"]).library
        var game = try NewGameFactory.make(scenarioID: "kestrel-lofts", library: lib)
        let b = try #require(game.world.buildings(on: game.activePropertyID).first)
        let engine = ConstructionEngine(catalog: lib.buildCatalog)
        for level in 0...2 {
            try engine.apply(.buildFloor(building: b.id, level: level, span: ColumnSpan(start: b.footprint.start, count: 20)), to: &game.world)
        }
        try engine.apply(.placeRoom(building: b.id, definition: "apartment-loft", columns: ColumnSpan(start: b.footprint.start, count: 10),
                                    floors: FloorSpan(lowest: 2, highest: 2)), to: &game.world)
        #expect(game.world.cities.values.first?.definitionID == "kestrel-bay")
        // The mod's blueprint builds on its own plot.
        var fresh = try NewGameFactory.make(scenarioID: "kestrel-lofts", library: lib)
        let tower = try #require(fresh.world.buildings(on: fresh.activePropertyID).first)
        for c in try #require(lib.blueprint("kestrel-lofts")).commands(for: tower) { try engine.apply(c, to: &fresh.world) }
        #expect(fresh.world.rooms.values.filter { $0.definitionID == "apartment-loft" }.count == 2)
        try game.world.validateIntegrity()
    }

    @Test func disabledModsAreListedButNotLoaded() throws {
        let dir = try modsFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try ModLoader.load(mods: ModLoader.discover(in: dir), enabled: [])
        #expect(result.library.packs.map(\.id) == ["base"] && result.library.city("kestrel-bay") == nil)
        #expect(result.packs.map(\.state) == [.active, .disabled])
    }

    /// A broken mod is skipped and reported; the base and the other mods still load.
    @Test func brokenModsAreReportedAndSkipped() throws {
        let dir = try modsFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try write("{ not json", to: dir.appendingPathComponent("aa-garbled"), "pack.json")
        try write(manifest("bad-ref", files: #"{"tenants":"tenants.json"}"#), to: dir.appendingPathComponent("bad-ref"), "pack.json")
        try write(#"[{"id":"ghost","name":"Ghost","kind":"household","rooms":["no-such-room"],"role":"resident","members":{"fixed":1},"schedules":["resident-commuter"],"budgetPerModule":200,"weights":{"rent":1,"access":1,"noise":1,"view":1},"minScore":0.5,"leaveBelow":0.3,"prospectsPerDay":1}]"#,
                  to: dir.appendingPathComponent("bad-ref"), "tenants.json")
        try write(manifest("odd-kind", files: #"{"spells":"spells.json"}"#), to: dir.appendingPathComponent("odd-kind"), "pack.json")
        try write(manifest("needs-other", requires: #"["not-installed"]"#), to: dir.appendingPathComponent("needs-other"), "pack.json")
        try write(manifest("base"), to: dir.appendingPathComponent("zz-base-again"), "pack.json")
        let result = try ModLoader.load(mods: ModLoader.discover(in: dir),
                                        enabled: ["aa-garbled", "bad-ref", "odd-kind", "needs-other", "base", "kestrel-bay"])
        func state(_ id: String) -> PackStatus.State? { result.packs.first { $0.id == id }?.state }
        func failure(_ id: String) -> String { if case .failed(let why)? = state(id) { why } else { "" } }
        #expect(failure("aa-garbled").contains("Invalid JSON"))
        #expect(failure("bad-ref").hasPrefix("[bad-ref/") && failure("bad-ref").contains("tenant 'ghost': unknown room type 'no-such-room'"))
        #expect(failure("odd-kind").contains("Unknown definition kind 'spells'"))
        #expect(failure("needs-other").contains("Requires 'not-installed'"))
        #expect(result.packs.filter { $0.id == "base" }.map(\.state) == [.active, .failed("Another pack already uses the id 'base'")])
        #expect(state("kestrel-bay") == .active)
        #expect(result.library.packs.map(\.id) == ["base", "kestrel-bay"])
        #expect(!result.library.simulationRules.tenantTypes.contains { $0.id == "ghost" })
    }

    @Test func requirementsFollowLoadOrder() throws {
        let dir = try modsFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try write(manifest("addon", requires: #"["kestrel-bay"]"#), to: dir.appendingPathComponent("addon"), "pack.json")
        let before = try ModLoader.load(mods: ModLoader.discover(in: dir), enabled: ["addon", "kestrel-bay"])
        #expect(before.packs.first { $0.id == "addon" }?.state == .failed("Requires 'kestrel-bay', which is not loaded before it"))
        let after = try ModLoader.load(mods: ModLoader.discover(in: dir), enabled: ["kestrel-bay", "addon"])
        #expect(after.library.packs.map(\.id) == ["base", "kestrel-bay", "addon"])
    }

    @Test func discoveryIgnoresFoldersWithoutAManifest() throws {
        let dir = try modsFolder()
        defer { try? FileManager.default.removeItem(at: dir) }
        try write("notes", to: dir.appendingPathComponent("not-a-mod"), "readme.txt")
        #expect(ModLoader.discover(in: dir).map(\.lastPathComponent) == ["kestrel-bay"])
        #expect(ModLoader.discover(in: dir.appendingPathComponent("missing")).isEmpty)
    }

    @Test func singleFilesReplaceAndMaterialsMerge() throws {
        var base = try ContentPack.read(at: BaseContent.packURL)
        var mod = ContentPack(manifest: ContentPackManifest(id: "m", name: "m", version: "1", formatVersion: 1, files: [:]))
        mod.materials = ["brick": "#AA5533", "new-stone": "#CCCCCC"]
        var economy = try #require(base.economy)
        economy.loanStep = 250_000
        mod.economy = economy
        let hadBrick = base.materials["brick"] != nil
        let changes = base.overlay(mod)
        #expect(changes.replaced.contains("economy") && changes.replaced.contains("material 'brick'") == hadBrick)
        #expect(changes.added.contains("material 'new-stone'"))
        #expect(base.economy?.loanStep == 250_000 && base.materials["new-stone"] == "#CCCCCC")
        #expect(try ContentLibrary.build(base).simulationRules.economy?.loanStep == 250_000)
    }
}
