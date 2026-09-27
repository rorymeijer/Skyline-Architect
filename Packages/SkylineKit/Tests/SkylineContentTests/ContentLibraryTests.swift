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
