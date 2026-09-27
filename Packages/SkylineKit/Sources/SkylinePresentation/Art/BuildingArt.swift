import Foundation
import SkylineCore

/// Section drawing of a building's superstructure: storey shells, slabs, roofs with
/// parapets, end façades with glazing, structural columns — then rooms via `RoomArt`.
/// Foundations (raft, grade slab, walls) are drawn by `FoundationArt`.
enum BuildingArt {
    static let facadeThickness = 0.3
    static let columnWidth = 0.45

    static func draw(into d: inout Drawing, building: Building, rooms: [Room], catalog: BuildCatalog?,
                     grid: GridSpec, palette p: ArtPalette) {
        let slab = grid.slabThickness
        func x(_ c: Int) -> Double { grid.x(ofColumn: c) }

        for plate in building.floors {
            let level = plate.level
            let floorY = grid.y(ofFloor: level)
            let ceilingY = grid.y(ofFloor: level + 1) - slab
            let x0 = x(plate.span.start), x1 = x(plate.span.end)
            let isAboveGrade = level >= 0

            // Slab carrying this storey (ground and basement slabs belong to the foundation).
            if level >= 1 {
                var rng = SeededRandom(seed: UInt64(building.id.raw), stream: UInt64(bitPattern: Int64(level)) &+ 0x51AB)
                FoundationArt.cutConcrete(into: &d, rect: Rect(minX: x0, minY: floorY - slab, maxX: x1, maxY: floorY), palette: p, rng: &rng)
            }
            // Shell: bare concrete back wall, ambient occlusion at floor and ceiling.
            let interior = Rect(minX: x0, minY: floorY, maxX: x1, maxY: ceilingY)
            d.verticalGradient(interior, top: p.shellWall.shaded(0.9), bottom: p.shellWall.shaded(1.02))
            d.verticalGradient(Rect(minX: x0, minY: ceilingY - 0.6, maxX: x1, maxY: ceilingY), top: RGBA(0, 0, 0, 0.3), bottom: RGBA(0, 0, 0, 0))

            // Structural columns on interior bay lines.
            for c in plate.span.range.dropFirst() where grid.isBayLine(column: c) {
                let cx = x(c)
                d.horizontalGradient(Rect(minX: cx - columnWidth / 2, minY: floorY, maxX: cx + columnWidth / 2, maxY: ceilingY), stops: [
                    GradientStop(0, p.concreteSurface.shaded(0.85)), GradientStop(0.5, p.concreteSurface.shaded(1.05)),
                    GradientStop(1, p.concreteSurface.shaded(0.8))], minDetail: 3)
            }

            // Roof over any part not covered by the plate above.
            if isAboveGrade {
                let above = building.plate(at: level + 1)?.span
                for segment in uncovered(plate.span, by: above) {
                    roof(into: &d, x0: x(segment.start), x1: x(segment.end), y: ceilingY, slab: slab,
                         leftEdge: segment.start == plate.span.start, rightEdge: segment.end == plate.span.end, palette: p)
                }
            }
        }

        // Rooms after all shells so they paint over them.
        for room in rooms {
            let spec = catalog?.spec(room.definitionID)
            RoomArt.draw(into: &d, room: room, appearance: spec?.appearance ?? "default", building: building, grid: grid, palette: p)
        }

        // Basement storeys are closed by the retaining walls, which rooms must not cover.
        let wall = Foundation.retainingWallThickness
        let fx0 = x(building.footprint.start), fx1 = x(building.footprint.end)
        for plate in building.floors where plate.level < 0 {
            let floorY = grid.y(ofFloor: plate.level), ceilingY = grid.y(ofFloor: plate.level + 1) - slab
            var rng = SeededRandom(seed: UInt64(building.id.raw), stream: UInt64(bitPattern: Int64(plate.level)) &+ 0xB0)
            for wx in [fx0, fx1 - wall] {
                FoundationArt.cutConcrete(into: &d, rect: Rect(minX: wx, minY: floorY, maxX: wx + wall, maxY: ceilingY), palette: p, rng: &rng)
            }
        }

        // End façades last: they cap rooms at the plate edges.
        for plate in building.floors where plate.level >= 0 {
            let floorY = grid.y(ofFloor: plate.level), ceilingY = grid.y(ofFloor: plate.level + 1) - slab
            facade(into: &d, x: x(plate.span.start), inward: 1, floorY: floorY, ceilingY: ceilingY, palette: p)
            facade(into: &d, x: x(plate.span.end), inward: -1, floorY: floorY, ceilingY: ceilingY, palette: p)
        }
    }

    /// Parts of `span` not covered by `cover`.
    static func uncovered(_ span: ColumnSpan, by cover: ColumnSpan?) -> [ColumnSpan] {
        guard let cover, cover.overlaps(span) else { return [span] }
        var parts: [ColumnSpan] = []
        if cover.start > span.start { parts.append(ColumnSpan(start: span.start, count: cover.start - span.start)) }
        if cover.end < span.end { parts.append(ColumnSpan(start: cover.end, count: span.end - cover.end)) }
        return parts
    }

    private static func roof(into d: inout Drawing, x0: Double, x1: Double, y: Double, slab: Double,
                             leftEdge: Bool, rightEdge: Bool, palette p: ArtPalette) {
        var rng = SeededRandom(seed: UInt64(bitPattern: Int64(x0 * 100)), stream: 0x2F00)
        FoundationArt.cutConcrete(into: &d, rect: Rect(minX: x0, minY: y, maxX: x1, maxY: y + slab), palette: p, rng: &rng)
        d.fill(Rect(minX: x0, minY: y + slab, maxX: x1, maxY: y + slab + 0.12), p.roofMembrane)
        let parapet = 1.05
        if leftEdge { d.fill(Rect(minX: x0, minY: y + slab, maxX: x0 + 0.25, maxY: y + slab + parapet), p.facadePanel.shaded(0.9)) }
        if rightEdge { d.fill(Rect(minX: x1 - 0.25, minY: y + slab, maxX: x1, maxY: y + slab + parapet), p.facadePanel.shaded(0.9)) }
        // Coping highlight.
        if leftEdge { d.fill(Rect(minX: x0 - 0.05, minY: y + slab + parapet - 0.06, maxX: x0 + 0.3, maxY: y + slab + parapet), p.steel) }
        if rightEdge { d.fill(Rect(minX: x1 - 0.3, minY: y + slab + parapet - 0.06, maxX: x1 + 0.05, maxY: y + slab + parapet), p.steel) }
    }

    /// End wall cut by the section: insulated panel with a full-height window band.
    private static func facade(into d: inout Drawing, x: Double, inward: Double, floorY: Double, ceilingY: Double, palette p: ArtPalette) {
        let t = facadeThickness
        let outer = inward > 0 ? x : x - t
        d.fill(Rect(minX: outer, minY: floorY, maxX: outer + t, maxY: ceilingY), p.facadePanel)
        let sill = floorY + 0.9, head = ceilingY - 0.35
        if head > sill {
            let glass = Rect(minX: outer + 0.08, minY: sill, maxX: outer + t - 0.08, maxY: head)
            d.fill(glass, p.glazing)
            d.fill(Rect(minX: outer + t / 2 - 0.015, minY: sill, maxX: outer + t / 2 + 0.015, maxY: head), p.mullion, minDetail: 12)
            d.outline(glass, p.mullion, width: 0.02, minDetail: 10)
        }
    }
}
