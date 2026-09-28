import Testing
import SkylineCore
import SkylineContent
import SkylineSimulation
@testable import SkylinePresentation

@Suite struct FireViewTests {
    @Test func burningRoomsAndEnginesAreShown() throws {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let b = game.world.buildings(on: game.activePropertyID).first!
        for c in lib.blueprint("demo-tower")!.commands(for: b) { try ConstructionEngine(catalog: lib.buildCatalog).apply(c, to: &game.world) }
        let engine = SimulationEngine(rules: lib.simulationRules, catalog: lib.buildCatalog)
        engine.replanAfterConstruction(&game.world)
        let office = try #require(game.world.rooms.values.first { $0.definitionID == "office-small" })
        #expect(FireView.flames(world: game.world, propertyID: game.activePropertyID, time: 0).isEmpty)
        #expect(engine.ignite(office.id, at: 0, world: &game.world))
        let flames = FireView.flames(world: game.world, propertyID: game.activePropertyID, time: 10)
        #expect(flames.count == 1 && flames[0].rect == game.world.grid.rect(columns: office.columns, floors: office.floors))
        #expect(flames[0].flicker >= 0.7 && flames[0].flicker <= 1)
        #expect(FireView.engines(world: game.world, propertyID: game.activePropertyID, time: 60).isEmpty)          // not there yet
        let arrival = Double(game.world.incidents.fires[0].brigadeArrives)
        #expect(FireView.engines(world: game.world, propertyID: game.activePropertyID, time: arrival).count == 1)
        #expect(FireView.flames(world: game.world, propertyID: game.activePropertyID, time: 10, protected: [office.id])[0].sprinklers)
        // Damage shows as soot until repaired.
        #expect(FireView.scorched(world: game.world, propertyID: game.activePropertyID).isEmpty)
        game.world.upkeep.update(office.id) { $0.condition = 0.1 }
        let soot = FireView.scorched(world: game.world, propertyID: game.activePropertyID)
        #expect(soot.count == 1 && soot[0].soot > 0.8)
    }
}
