import Foundation
import Testing
import SkylineCore
@testable import SkylineContent

@Suite struct ContentLibraryTests {
    @Test func basePackLoadsAndValidates() throws {
        let lib = try ContentLibrary.loadBase()
        #expect(lib.city("port-calder")?.geology.last?.material == .bedrock)
        #expect(lib.plot("calder-quay-lot")?.frontageModules == 48)
        #expect(lib.start(NewGameFactory.defaultStartID) != nil)
    }

    @Test func defaultStartCreatesWorldWithFoundation() throws {
        let lib = try ContentLibrary.loadBase()
        let game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let property = try #require(game.world.properties[game.activePropertyID])
        #expect(property.plot.frontage.count == 48)
        let buildings = game.world.buildings(on: property.id)
        #expect(buildings.count == 1)
        #expect(buildings[0].foundation.basementFloors == 1)
        // Starter piles must reach bedrock in the base city.
        #expect(buildings[0].foundation.pileDepth > property.plot.bedrockDepth)
    }

    @Test func newGameIsDeterministic() throws {
        let lib = try ContentLibrary.loadBase()
        let a = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let b = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        #expect(a.world == b.world)
    }

    @Test func danglingReferencesAreRejected() throws {
        var lib = ContentLibrary(manifest: ContentPackManifest(id: "t", name: "t", version: "1", formatVersion: 1, files: [:]))
        let plot = PlotDefinition(id: "p", name: "p", cityID: "nowhere", frontageModules: 10, maxBasementFloors: 1, siteMarginModules: 0)
        #expect(throws: ContentError.self) { try lib.register(cities: [], plots: [plot], starts: []) }
    }

    @Test func duplicateIdsAreRejected() throws {
        var lib = ContentLibrary(manifest: ContentPackManifest(id: "t", name: "t", version: "1", formatVersion: 1, files: [:]))
        let city = CityDefinition(id: "c", name: "c", description: "", seed: 1, geology: [SoilStratum(material: .clay, thickness: 1)])
        #expect(throws: ContentError.self) { try lib.register(cities: [city, city], plots: [], starts: []) }
    }

    @Test func unsupportedFormatVersionIsRejected() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pack-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let manifest = #"{"id":"future","name":"f","version":"9","formatVersion":99,"files":{}}"#
        try manifest.write(to: dir.appendingPathComponent("pack.json"), atomically: true, encoding: .utf8)
        #expect(throws: ContentError.self) { try ContentLibrary.load(packAt: dir) }
    }
}

@Suite struct ConstructionContentTests {
    @Test func baseRoomsAndRulesLoad() throws {
        let lib = try ContentLibrary.loadBase()
        let catalog = lib.buildCatalog
        #expect(catalog.spec("office-small")?.lowestLevel == 1)
        #expect(catalog.spec("stairs")?.kind == .shaft)
        #expect(catalog.rules.slabCostPerModule > 0)
    }

    /// The demo blueprint must build cleanly on the default start with the real rules —
    /// an end-to-end check of content + construction engine.
    @Test func demoBlueprintBuildsOnDefaultStart() throws {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let building = try #require(game.world.buildings(on: game.activePropertyID).first)
        let engine = ConstructionEngine(catalog: lib.buildCatalog)
        let blueprint = try #require(lib.blueprint("demo-tower"))
        var total = 0
        for command in blueprint.commands(for: building) {
            total += try engine.apply(command, to: &game.world).plan.cost
        }
        #expect(game.world.buildings[building.id]?.builtLevels == FloorSpan(lowest: -1, highest: 8))
        #expect(game.world.rooms.count > 30)
        #expect(total > 0)
        try game.world.validateIntegrity()
    }

    @Test func invalidRoomDefinitionsAreRejected() throws {
        var lib = ContentLibrary(manifest: ContentPackManifest(id: "t", name: "t", version: "1", formatVersion: 1, files: [:]))
        let bad = RoomSpec(id: "x", name: "x", category: "c", kind: .shaft, appearance: "a",
                           minWidth: 2, maxWidth: 2, minFloors: 1, maxFloors: 3, costPerModule: 1)
        #expect(throws: ContentError.self) { try lib.register(rooms: [bad], blueprints: []) }
        let bp = Blueprint(id: "b", name: "b", description: "", steps: [
            .init(floor: nil, room: .init(definition: "missing", start: 0, count: 4, lowest: 0, highest: 0))])
        #expect(throws: ContentError.self) { try lib.register(rooms: [], blueprints: [bp]) }
    }

    @Test func invalidProgressionIsRejected() throws {
        let base = try ContentLibrary.loadBase()
        let rules = base.simulationRules.progression!
        let rooms = Set(base.orderedRooms.map(\.id))
        let ok = ProgressionDefinition(reputation: rules, classes: base.buildingClasses)
        #expect(ok.problems(rooms: rooms).isEmpty)
        var bad = ok
        bad.classes[0].population = 10                          // the starting class cannot ask for anything
        bad.classes[1].requiredRooms = ["moon-base"]
        bad.classes[2].maxFloor = 3                             // lower than class B's
        #expect(bad.problems(rooms: rooms).count == 3)
        var lib = ContentLibrary(manifest: base.manifest)
        try lib.register(rooms: base.orderedRooms, blueprints: [])
        #expect(throws: ContentError.self) {
            try lib.register(schedules: base.simulationRules.schedules, names: base.simulationRules.names,
                             elevators: base.simulationRules.elevators, tenants: base.simulationRules.tenantTypes,
                             economy: base.simulationRules.economy, facilities: base.simulationRules.facilities, progression: bad)
        }
    }
}
