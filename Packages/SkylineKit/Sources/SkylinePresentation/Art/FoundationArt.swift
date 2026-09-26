import Foundation
import SkylineCore

/// Section drawing of a building foundation: excavation, diaphragm retaining walls,
/// raft slab with rebar, bored piles, grade slab and starter bars at column lines.
/// Dimensions come from `SkylineCore.Foundation` so art and model never disagree.
enum FoundationArt {
    static func draw(into d: inout Drawing, building: Building, grid: GridSpec, palette p: ArtPalette) {
        let f = building.foundation
        let x0 = grid.x(ofColumn: building.footprint.start)
        let x1 = grid.x(ofColumn: building.footprint.end)
        let wall = Foundation.retainingWallThickness
        let slab = grid.slabThickness
        let raftTop = grid.y(ofFloor: -f.basementFloors)
        let raftBottom = f.raftBottomY(grid: grid)
        var rng = SeededRandom(seed: UInt64(building.id.raw), stream: 0xF0)

        // Disturbed soil / backfill halo around the excavation (ambient occlusion).
        let halo = 0.9
        d.horizontalGradient(Rect(minX: x0 - halo, minY: raftBottom - Foundation.wallToeBelowRaft, maxX: x0, maxY: 0),
                             stops: [GradientStop(0, RGBA(0, 0, 0, 0)), GradientStop(1, RGBA(0, 0, 0, 0.28))])
        d.horizontalGradient(Rect(minX: x1, minY: raftBottom - Foundation.wallToeBelowRaft, maxX: x1 + halo, maxY: 0),
                             stops: [GradientStop(0, RGBA(0, 0, 0, 0.28)), GradientStop(1, RGBA(0, 0, 0, 0))])

        // Piles (drawn first: the raft covers their heads).
        var px = x0 + Double(f.pileSpacing) * grid.moduleWidth / 2
        while px < x1 {
            pile(into: &d, centerX: px, top: raftBottom + 0.1, bottom: -f.pileDepth, palette: p, rng: &rng)
            px += Double(f.pileSpacing) * grid.moduleWidth
        }

        if f.basementFloors > 0 {
            // Basement void: back wall seen beyond the section cut.
            let void = Rect(minX: x0 + wall, minY: raftTop, maxX: x1 - wall, maxY: -slab)
            basementBackWall(into: &d, rect: void, palette: p, rng: &rng)
            // Raft slab.
            let raft = Rect(minX: x0, minY: raftBottom, maxX: x1, maxY: raftTop)
            cutConcrete(into: &d, rect: raft, palette: p, rng: &rng)
            rebarRows(into: &d, rect: raft, palette: p)
            // Retaining walls with toes below the raft.
            for wx in [x0, x1 - wall] {
                let w = Rect(minX: wx, minY: raftBottom - Foundation.wallToeBelowRaft, maxX: wx + wall, maxY: 0)
                cutConcrete(into: &d, rect: w, palette: p, rng: &rng)
            }
        }

        // Grade slab (ground-floor slab, top at y = 0).
        let gradeSlab = Rect(minX: x0, minY: -slab, maxX: x1, maxY: 0)
        cutConcrete(into: &d, rect: gradeSlab, palette: p, rng: &rng)
        d.fill(Rect(minX: x0, minY: -0.04, maxX: x1, maxY: 0), p.concreteHighlight)

        // Starter bars and column plinths on bay lines and at the footprint edges.
        var columns = Set<Int>()
        for c in building.footprint.range where grid.isBayLine(column: c) { columns.insert(c) }
        columns.insert(building.footprint.start)
        columns.insert(building.footprint.end)
        for c in columns.sorted() {
            let cx = min(max(grid.x(ofColumn: c), x0 + 0.3), x1 - 0.3)
            starter(into: &d, centerX: cx, palette: p, rng: &rng)
        }
    }

    /// Concrete cut by the section plane: light fill, aggregate stipple, crisp edge.
    static func cutConcrete(into d: inout Drawing, rect: Rect, palette p: ArtPalette, rng: inout SeededRandom) {
        d.verticalGradient(rect, top: p.concreteCut.shaded(1.04), bottom: p.concreteCut.shaded(0.94))
        let n = Int(rect.width * rect.height * 6)
        for _ in 0..<n {
            let c = Vec2(rng.double(in: rect.minX..<rect.maxX), rng.double(in: rect.minY..<rect.maxY))
            let r = rng.double(in: 0.012..<0.035)
            d.ellipse(Rect(center: c, size: Vec2(r * 2, r * 2)),
                      p.concreteCut.shaded(rng.chance(0.5) ? 0.8 : 1.12).withAlpha(0.8), minDetail: 44)
        }
        d.outline(rect, p.concreteEdge, width: 0.03, minDetail: 6)
    }

    private static func rebarRows(into d: inout Drawing, rect: Rect, palette p: ArtPalette) {
        let cover = 0.1, spacing = 0.2, r = 0.016
        for y in [rect.minY + cover, rect.maxY - cover] {
            var x = rect.minX + cover
            while x < rect.maxX - cover {
                d.ellipse(Rect(center: Vec2(x, y), size: Vec2(r * 2, r * 2)), p.rebar, minDetail: 48)
                x += spacing
            }
        }
    }

    private static func basementBackWall(into d: inout Drawing, rect: Rect, palette p: ArtPalette, rng: inout SeededRandom) {
        d.verticalGradient(rect, top: p.concreteSurface.shaded(0.92), bottom: p.concreteSurface.shaded(1.02))
        // Pour lifts (horizontal construction joints).
        var y = rect.minY + 1.2
        while y < rect.maxY - 0.2 {
            d.fill(Rect(minX: rect.minX, minY: y, maxX: rect.maxX, maxY: y + 0.02), p.concreteEdge.withAlpha(0.35), minDetail: 10)
            y += 1.2
        }
        // Formwork panel joints and tie holes.
        var x = rect.minX + 2.4
        while x < rect.maxX - 0.1 {
            d.fill(Rect(minX: x, minY: rect.minY, maxX: x + 0.015, maxY: rect.maxY), p.concreteEdge.withAlpha(0.25), minDetail: 16)
            x += 2.4
        }
        var ty = rect.minY + 0.3
        while ty < rect.maxY - 0.1 {
            var tx = rect.minX + 0.3
            while tx < rect.maxX - 0.1 {
                d.ellipse(Rect(center: Vec2(tx, ty), size: Vec2(0.035, 0.035)), p.concreteEdge.withAlpha(0.55), minDetail: 40)
                tx += 0.6
            }
            ty += 0.6
        }
        // Blotchy curing variation.
        for _ in 0..<Int(rect.width * rect.height * 0.08) {
            let c = Vec2(rng.double(in: rect.minX..<rect.maxX), rng.double(in: rect.minY..<rect.maxY))
            d.ellipse(Rect(center: c, size: Vec2(rng.double(in: 0.6..<2), rng.double(in: 0.3..<1))),
                      p.concreteSurface.shaded(rng.chance(0.5) ? 0.94 : 1.06).withAlpha(0.35), minDetail: 8)
        }
        // Ambient occlusion under the ceiling slab and at the raft.
        d.verticalGradient(Rect(minX: rect.minX, minY: rect.maxY - 1.0, maxX: rect.maxX, maxY: rect.maxY),
                           top: RGBA(0, 0, 0, 0.35), bottom: RGBA(0, 0, 0, 0))
        d.verticalGradient(Rect(minX: rect.minX, minY: rect.minY, maxX: rect.maxX, maxY: rect.minY + 0.5),
                           top: RGBA(0, 0, 0, 0), bottom: RGBA(0, 0, 0, 0.25))
        for (x0, x1, a0, a1) in [(rect.minX, rect.minX + 0.6, 0.3, 0.0), (rect.maxX - 0.6, rect.maxX, 0.0, 0.3)] {
            d.horizontalGradient(Rect(minX: x0, minY: rect.minY, maxX: x1, maxY: rect.maxY),
                                 stops: [GradientStop(0, RGBA(0, 0, 0, a0)), GradientStop(1, RGBA(0, 0, 0, a1))])
        }
    }

    private static func pile(into d: inout Drawing, centerX: Double, top: Double, bottom: Double,
                             palette p: ArtPalette, rng: inout SeededRandom) {
        let r = Foundation.pileDiameter / 2
        let body = Rect(minX: centerX - r, minY: bottom, maxX: centerX + r, maxY: top)
        let c = p.concreteCut
        // Cylindrical shading.
        d.horizontalGradient(body, stops: [
            GradientStop(0, c.shaded(0.72)), GradientStop(0.35, c.shaded(1.08)),
            GradientStop(0.6, c.shaded(0.98)), GradientStop(1, c.shaded(0.66)),
        ])
        // Rounded toe.
        d.ellipse(Rect(minX: body.minX, minY: bottom - r * 0.5, maxX: body.maxX, maxY: bottom + r * 0.5), c.shaded(0.8))
        // Longitudinal bars visible at close range.
        for bx in [centerX - r + 0.12, centerX + r - 0.12] {
            d.fill(Rect(minX: bx - 0.012, minY: bottom + 0.3, maxX: bx + 0.012, maxY: top), p.rebar.withAlpha(0.55), minDetail: 56)
        }
        d.outline(body, p.concreteEdge.withAlpha(0.7), width: 0.03, minDetail: 8)
        _ = rng.next()
    }

    private static func starter(into d: inout Drawing, centerX: Double, palette p: ArtPalette, rng: inout SeededRandom) {
        let plinth = Rect(minX: centerX - 0.3, minY: 0, maxX: centerX + 0.3, maxY: 0.25)
        d.verticalGradient(plinth, top: p.concreteCut.shaded(1.05), bottom: p.concreteCut.shaded(0.9))
        d.outline(plinth, p.concreteEdge, width: 0.02, minDetail: 10)
        for i in 0..<4 {
            let bx = centerX - 0.21 + Double(i) * 0.14
            let lean = rng.double(in: -0.04..<0.04)
            let h = rng.double(in: 1.05..<1.25)
            d.line([Vec2(bx, 0.25), Vec2(bx + lean, 0.25 + h)], p.rebar, width: 0.028, minDetail: 10)
        }
    }
}
