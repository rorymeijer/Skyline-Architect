import Testing
import SkylineCore
@testable import SkylinePresentation

@Suite struct DrawingIndexTests {
    @Test func indexMatchesBruteForce() {
        var rng = SeededRandom(seed: 3)
        var d = Drawing()
        for _ in 0..<2000 {
            let c = Vec2(rng.double(in: -500..<500), rng.double(in: -100..<400))
            let s = Vec2(rng.double(in: 0.1..<30), rng.double(in: 0.1..<30))
            d.fill(Rect(center: c, size: s), .black, minDetail: rng.chance(0.3) ? 20 : 0)
        }
        d.fill(Rect(minX: -5000, minY: -60, maxX: 5000, maxY: 0), .white)  // "large" item
        let index = DrawingIndex(d, cellSize: 16)
        for _ in 0..<50 {
            let q = Rect(center: Vec2(rng.double(in: -500..<500), rng.double(in: -100..<400)),
                         size: Vec2(rng.double(in: 1..<200), rng.double(in: 1..<200)))
            let detail = rng.chance(0.5) ? 10.0 : 50.0
            let expected = d.items.indices.filter { d.items[$0].bounds.intersects(q) && d.items[$0].minDetail <= detail }
            #expect(index.items(in: q, of: d, detail: detail) == expected)
        }
    }
}

@Suite struct TileTests {
    let pyramid = TilePyramid(tilePixels: 512, basePixelsPerMeter: 2, maxLevel: 7)

    @Test func levelSelectionTracksScreenDensity() {
        #expect(pyramid.level(forScreenPixelsPerMeter: 1) == 0)
        #expect(pyramid.level(forScreenPixelsPerMeter: 2) == 0)
        #expect(pyramid.level(forScreenPixelsPerMeter: 4) == 1)
        #expect(pyramid.level(forScreenPixelsPerMeter: 4.5) == 1)   // slight magnification allowed
        #expect(pyramid.level(forScreenPixelsPerMeter: 7) == 2)
        #expect(pyramid.level(forScreenPixelsPerMeter: 10_000) == 7)
        // The chosen level never magnifies by more than ~20 %.
        for p in stride(from: 2.0, through: 256, by: 0.37) {
            let ppm = pyramid.pixelsPerMeter(level: pyramid.level(forScreenPixelsPerMeter: p))
            #expect(p / ppm <= 1.21)
        }
    }

    @Test func keysCoverRectExactly() {
        let r = Rect(minX: -37, minY: -12, maxX: 91, maxY: 55)
        for level in 0...6 {
            let keys = pyramid.keys(covering: r, level: level)
            let union = keys.map(pyramid.rect(for:)).reduce(Rect.null) { $0.union($1) }
            #expect(union.contains(r))
            // No tile is completely outside the rect.
            #expect(keys.allSatisfy { pyramid.rect(for: $0).intersects(r) })
        }
    }

    @Test func planIsNearestFirstAndLimitedToContent() {
        let planner = TileSetPlanner(pyramid: pyramid)
        let visible = Rect(minX: 0, minY: 0, maxX: 144, maxY: 90)
        let plan = planner.plan(visible: visible, screenPixelsPerMeter: 20, content: Rect(minX: -1000, minY: -60, maxX: 1000, maxY: 50))
        #expect(!plan.wanted.isEmpty)
        #expect(plan.wanted.allSatisfy { pyramid.rect(for: $0).minY < 50 })
        let d = plan.wanted.map { (pyramid.rect(for: $0).center - visible.center).length }
        #expect(d == d.sorted())
    }

    @Test func evictionIsLRUAndProtectsWanted() {
        var planner = TileSetPlanner(pyramid: pyramid, budget: 3)
        let keys = (0..<5).map { TileKey(level: 2, x: $0, y: 0) }
        for k in keys { planner.insert(k) }
        planner.touch([keys[0]])  // key 0 is now most recent
        let ev = planner.evictions(protecting: [keys[1]])
        #expect(ev == [keys[2], keys[3]])
    }
}
