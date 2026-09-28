import Foundation
import Testing
@testable import SkylineCore

/// Extending foundations (0.21): wider, deeper, longer piles; costs, limits and undo.
@Suite struct FoundationTests {
    /// The shared fixture (32-module footprint at 8..<40 on a 48-module plot, 1 basement of
    /// at most 3, 20 m piles every 4 modules) with a pile height limit of 2 storeys per meter.
    func fixture() throws -> ConstructionFixture {
        var f = try ConstructionFixture()
        var rules = ConstructionFixture.catalog.rules
        rules.storeysPerPileMeter = 2
        f.engine = ConstructionEngine(catalog: BuildCatalog(rules: rules, specs: ConstructionFixture.catalog.specs))
        return f
    }

    func extend(_ f: ConstructionFixture, left: Int = 0, right: Int = 0, basements: Int? = nil, piles: Double? = nil) -> BuildCommand {
        let b = f.world.buildings[f.building]!
        var foundation = b.foundation
        foundation.basementFloors = basements ?? foundation.basementFloors
        foundation.pileDepth = piles ?? foundation.pileDepth
        return .extendFoundation(building: b.id, footprint: ColumnSpan(start: b.footprint.start - left, count: b.footprint.count + left + right),
                                 foundation: foundation)
    }

    @Test func wideningDeepeningAndLongerPilesAreChargedByWhatIsAdded() throws {
        let f = try fixture()
        // 4 new modules: 4 × 6000 raft + 4 × 1 basement × 4000; piles 9 → 10 at 20 m × 150.
        #expect(try f.check(extend(f, left: 4)).get().cost == 24_000 + 16_000 + 3_000)
        // One more basement under 32 modules.
        #expect(try f.check(extend(f, basements: 2)).get().cost == 32 * 4000)
        // 9 piles 10 m longer.
        #expect(try f.check(extend(f, piles: 30)).get().cost == 9 * 10 * 150)
    }

    @Test func foundationsGrowWithinThePlotOnly() throws {
        let f = try fixture()
        #expect(f.check(extend(f, left: 9)) == .failure(.outsidePlot))           // the plot starts at column 0
        #expect(f.check(extend(f, basements: 4)) == .failure(.basementTooDeep(allowed: 3)))
        #expect(f.check(extend(f, piles: 10)) == .failure(.foundationCanOnlyGrow))
        #expect(f.check(extend(f)) == .failure(.nothingToBuild))
        // The deepest the plot allows (3 levels): the raft is still well above the 20 m piles.
        var deep = try fixture()
        _ = try deep.run(extend(deep, basements: 3))
        #expect(deep.world.buildings[deep.building]?.foundation.basementFloors == 3)
    }

    @Test func aWiderFootprintTakesWiderFloorsAndDeeperBasements() throws {
        var f = try fixture()
        #expect(f.check(.buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 4, count: 36))) == .failure(.outsideFootprint))
        #expect(f.check(.buildFloor(building: f.building, level: -2, span: ColumnSpan(start: 8, count: 32))) == .failure(.noExcavation(level: -2)))
        _ = try f.run(extend(f, left: 4, basements: 2))
        _ = try f.run(.buildFloor(building: f.building, level: 0, span: ColumnSpan(start: 4, count: 36)))
        _ = try f.run(.buildFloor(building: f.building, level: -2, span: ColumnSpan(start: 4, count: 36)))
        try f.world.validateIntegrity()
    }

    /// 20 m piles carry 40 storeys (levels 0…39); level 40 needs longer piles.
    @Test func pileDepthLimitsTheHeight() throws {
        var f = try fixture()
        try f.buildFloors(0...39)
        #expect(f.check(.buildFloor(building: f.building, level: 40, span: ColumnSpan(start: 8, count: 32))) == .failure(.pilesTooShort(needed: 20.5)))
        _ = try f.run(extend(f, piles: 21))
        _ = try f.run(.buildFloor(building: f.building, level: 40, span: ColumnSpan(start: 8, count: 32)))
    }

    @Test func undoRestoresTheFoundationAndTheMoney() throws {
        var f = try fixture()
        var history = ConstructionHistory()
        let before = f.world.buildings[f.building]!, cash = f.world.ledger.cash
        try history.perform(extend(f, left: 4, right: 4, basements: 2, piles: 30), engine: f.engine, world: &f.world)
        let after = f.world.buildings[f.building]!
        #expect(after.footprint == ColumnSpan(start: 4, count: 40) && after.foundation.basementFloors == 2 && after.foundation.pileDepth == 30)
        #expect(f.world.ledger.cash < cash)
        try history.undo(engine: f.engine, world: &f.world)
        #expect(f.world.buildings[f.building] == before && f.world.ledger.cash == cash)
        try history.redo(engine: f.engine, world: &f.world)
        #expect(f.world.buildings[f.building] == after)
    }

    /// A blueprint can grow the foundation before building on it.
    @Test func blueprintsCanExtendTheFoundation() throws {
        var f = try fixture()
        let bp = Blueprint(id: "t", name: "T", description: "", steps: [
            Blueprint.Step(foundation: Blueprint.FoundationStep(left: 2, pileDepth: 25)),
            Blueprint.Step(floor: Blueprint.FloorStep(level: 0, start: -2, count: 34)),
        ])
        for c in bp.commands(for: f.world.buildings[f.building]!) { _ = try f.run(c) }
        #expect(f.world.buildings[f.building]?.footprint == ColumnSpan(start: 6, count: 34))
        #expect(f.world.buildings[f.building]?.plate(at: 0)?.span == ColumnSpan(start: 6, count: 34))
    }
}
