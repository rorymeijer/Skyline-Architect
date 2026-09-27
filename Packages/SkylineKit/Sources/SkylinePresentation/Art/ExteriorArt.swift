import Foundation
import SkylineCore

/// Exterior curtain-wall façade shown instead of the cutaway at low zoom (massing /
/// skyline LOD): glazing with sky reflection, spandrel bands at every slab, mullions,
/// a taller glazed ground floor and slightly varied glass per storey.
enum ExteriorArt {
    static func draw(into d: inout Drawing, building: Building, grid: GridSpec, palette p: ArtPalette) {
        let slab = grid.slabThickness
        var rng = SeededRandom(seed: UInt64(building.id.raw), stream: 0xFACADE)
        for plate in building.floors where plate.level >= 0 {
            let x0 = grid.x(ofColumn: plate.span.start), x1 = grid.x(ofColumn: plate.span.end)
            let bottom = plate.level == 0 ? 0 : grid.y(ofFloor: plate.level) - slab
            let top = grid.y(ofFloor: plate.level + 1) - slab
            let storey = Rect(minX: x0, minY: bottom, maxX: x1, maxY: top)
            let glass = p.facadeGlass.shaded(rng.double(in: 0.94..<1.06))
            // Sky reflection: lighter toward the top of each storey.
            d.verticalGradient(storey, top: glass.mixed(with: p.skyLow, 0.35), bottom: glass.shaded(0.85))
            // Spandrel panel at the slab zone (hides the slab edge and ceiling void).
            let spandrel = plate.level == 0 ? 0.0 : 0.9
            if spandrel > 0 {
                d.fill(Rect(minX: x0, minY: bottom, maxX: x1, maxY: bottom + spandrel), p.facadePanel.shaded(0.95))
                d.fill(Rect(minX: x0, minY: bottom + spandrel - 0.06, maxX: x1, maxY: bottom + spandrel), p.mullion.withAlpha(0.8), minDetail: 2)
            } else {
                // Ground floor: entrance canopy line.
                d.fill(Rect(minX: x0, minY: top - 0.5, maxX: x1, maxY: top - 0.3), p.mullion, minDetail: 1.5)
            }
            // Vertical mullions every 1.5 m (visible from ~2 px/m).
            var mx = x0 + 1.5
            while mx < x1 - 0.1 {
                d.fill(Rect(minX: mx - 0.05, minY: bottom, maxX: mx + 0.05, maxY: top), p.mullion.withAlpha(0.7), minDetail: 2.5)
                mx += 1.5
            }
            // Façade edges.
            d.fill(Rect(minX: x0, minY: bottom, maxX: x0 + 0.3, maxY: top), p.facadePanel)
            d.fill(Rect(minX: x1 - 0.3, minY: bottom, maxX: x1, maxY: top), p.facadePanel)
        }
    }
}
