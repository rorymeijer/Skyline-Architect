import Foundation
import Testing
@testable import SkylineCore

@Suite struct GameWorldTests {
    static let strata = [
        SoilStratum(material: .paving, thickness: 0.3),
        SoilStratum(material: .clay, thickness: 8),
        SoilStratum(material: .bedrock, thickness: 1),
    ]

    func makeWorld() throws -> (GameWorld, PropertyID) {
        var world = GameWorld()
        let city = world.addCity(definitionID: "test-city", name: "Test", seed: 1)
        let plot = Plot(frontage: ColumnSpan(start: 0, count: 48), maxBasementFloors: 3, siteMargin: 20, strata: Self.strata)
        let property = try world.addProperty(cityID: city, name: "Lot", plot: plot)
        return (world, property)
    }

    @Test func placedStrataAreContiguousAndBottomIsUnbounded() {
        let plot = Plot(frontage: ColumnSpan(start: 0, count: 10), maxBasementFloors: 1, siteMargin: 0, strata: Self.strata)
        let placed = plot.placedStrata
        #expect(placed.count == 3)
        #expect(placed[0].topY == 0)
        #expect(placed[1].topY == placed[0].bottomY)
        #expect(placed[2].bottomY == -.infinity)
        #expect(abs(plot.bedrockDepth - 8.3) < 1e-9)
        #expect(plot.siteColumns == ColumnSpan(start: 0, count: 10))
    }

    @Test func addBuildingValidatesFootprintAndFoundation() throws {
        var (world, property) = try makeWorld()
        let ok = Foundation(basementFloors: 1, pileDepth: 18, pileSpacing: 4)
        let id = try world.addBuilding(propertyID: property, name: "Tower", footprint: ColumnSpan(start: 8, count: 32), foundation: ok)
        #expect(world.buildings(on: property).map(\.id) == [id])

        #expect(throws: WorldError.footprintOutsidePlot(ColumnSpan(start: 40, count: 16), plot: ColumnSpan(start: 0, count: 48))) {
            try world.addBuilding(propertyID: property, name: "X", footprint: ColumnSpan(start: 40, count: 16), foundation: ok)
        }
        #expect(throws: WorldError.footprintOverlapsBuilding(id)) {
            try world.addBuilding(propertyID: property, name: "X", footprint: ColumnSpan(start: 0, count: 10), foundation: ok)
        }
        #expect(throws: WorldError.basementTooDeep(requested: 4, allowed: 3)) {
            try world.addBuilding(propertyID: property, name: "X", footprint: ColumnSpan(start: 0, count: 4),
                                  foundation: Foundation(basementFloors: 4, pileDepth: 40, pileSpacing: 4))
        }
        // One basement floor: raft bottom at 4 + 1.2 = 5.2 m; 5 m piles are too short.
        #expect(throws: WorldError.pilesTooShort(pileDepth: 5, requiredBelow: 5.2)) {
            try world.addBuilding(propertyID: property, name: "X", footprint: ColumnSpan(start: 0, count: 4),
                                  foundation: Foundation(basementFloors: 1, pileDepth: 5, pileSpacing: 4))
        }
    }

    @Test func unknownReferencesThrow() throws {
        var world = GameWorld()
        let plot = Plot(frontage: ColumnSpan(start: 0, count: 4), maxBasementFloors: 0, siteMargin: 0, strata: Self.strata)
        #expect(throws: WorldError.unknownCity(CityID(raw: 99))) {
            try world.addProperty(cityID: CityID(raw: 99), name: "x", plot: plot)
        }
    }

    @Test func worldRoundTripsThroughJSON() throws {
        var (world, property) = try makeWorld()
        try world.addBuilding(propertyID: property, name: "Tower", footprint: ColumnSpan(start: 8, count: 32),
                              foundation: Foundation(basementFloors: 2, pileDepth: 22, pileSpacing: 4))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(world)
        var decoded = try JSONDecoder().decode(GameWorld.self, from: data)
        #expect(decoded == world)
        // Stable output: encoding twice yields identical bytes.
        #expect(try encoder.encode(decoded) == data)
        // The ID allocator survives: new IDs never collide with existing ones.
        let newCity = decoded.addCity(definitionID: "b", name: "B", seed: 2)
        #expect(!world.cities.contains(newCity))
        #expect(world.properties.values.allSatisfy { $0.id.raw != newCity.raw })
    }
}
