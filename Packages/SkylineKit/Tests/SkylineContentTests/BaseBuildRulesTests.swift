import Foundation
import Testing
import SkylineCore
@testable import SkylineContent

/// Structural rules of the base content applied through the construction engine.
@Suite struct BaseBuildRulesTests {
    /// The base game allows no overhang: every floor lies within the floor below, so a
    /// tower can never get wider as it rises, not even one module per floor.
    @Test func baseRulesForbidFloorsWiderThanTheFloorBelow() throws {
        let lib = try ContentLibrary.loadBase()
        #expect(lib.buildRules.maxCantileverModules == 0)
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let b = try #require(game.world.buildings(on: game.activePropertyID).first)
        let engine = ConstructionEngine(catalog: lib.buildCatalog)
        let ground = ColumnSpan(start: b.footprint.start + 2, count: b.footprint.count - 4)
        try engine.apply(.buildFloor(building: b.id, level: 0, span: ground), to: &game.world)
        let wider = ColumnSpan(start: ground.start - 1, count: ground.count + 1)
        #expect(throws: ConstructionError.overhang(max: 0)) { try engine.apply(.buildFloor(building: b.id, level: 1, span: wider), to: &game.world) }
        let narrower = ColumnSpan(start: ground.start + 1, count: ground.count - 2)
        try engine.apply(.buildFloor(building: b.id, level: 1, span: narrower), to: &game.world)
        #expect(throws: ConstructionError.overhang(max: 0)) { try engine.apply(.buildFloor(building: b.id, level: 2, span: ground), to: &game.world) }
        try engine.apply(.buildFloor(building: b.id, level: 2, span: narrower), to: &game.world)   // setbacks and straight walls are fine
    }

    /// The base game has no pile height limit (0.21.1): a 500-storey tower needs no
    /// 250 m piles. Every base blueprint builds on the default start.
    @Test func baseBlueprintsBuildWithoutAPileLimit() throws {
        let lib = try ContentLibrary.loadBase()
        #expect(lib.buildRules.storeysPerPileMeter == nil)
        for bp in lib.orderedBlueprints {
            var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
            let building = try #require(game.world.buildings(on: game.activePropertyID).first)
            let engine = ConstructionEngine(catalog: lib.buildCatalog)
            for c in bp.commands(for: building) { try engine.apply(c, to: &game.world) }
            #expect(game.world.buildings[building.id]?.builtLevels != nil, "\(bp.id)")
        }
    }
}
