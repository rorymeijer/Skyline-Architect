import Foundation
import SkylineCore

/// Everything static the renderer needs to draw one property: a single painter-ordered
/// drawing (sections: backdrop, neighbors, terrain, structures, site), its spatial index,
/// the sky, and framing information for the camera.
public struct SiteComposition: Sendable {
    public let propertyID: PropertyID
    public let grid: GridSpec
    public let plot: Plot
    public let drawing: Drawing
    public let index: DrawingIndex
    public let sky: SkyGradient
    /// Region covered by static art; tiles outside it are never requested.
    public let extent: Rect
    /// Site columns (frontage + margins) from the bottom of the ground section to grade.
    public let siteRect: Rect
    /// Buildable frontage from the deepest permitted basement to grade.
    public let frontageRect: Rect
    /// Union of all building foundations (excavation, piles, grade slab).
    public let foundationRect: Rect?
    /// Region the camera center is clamped to (see `CameraLimits.bounds`).
    public let cameraBounds: Rect
}

public enum SiteComposer {
    /// Maximum altitude the camera may reach; there is no floor limit, this only bounds
    /// empty sky. Raise together with the tallest supported building.
    public static let skyCeiling = 3000.0
    /// Art must cover the widest possible view: a 2560 pt window at minimum zoom (0.35 pt/m)
    /// spans ~7.3 km, so terrain extends ±6 km and the skyline ±4.5 km.
    static let terrainHalfWidth = 6000.0
    static let backdropHalfWidth = 4500.0

    public static func compose(world: GameWorld, propertyID: PropertyID, palette p: ArtPalette = .standard) -> SiteComposition? {
        guard let property = world.properties[propertyID], let city = world.cities[property.cityID] else { return nil }
        let grid = world.grid
        let plot = property.plot
        let buildings = world.buildings(on: propertyID)

        let site = plot.siteColumns
        let siteX0 = grid.x(ofColumn: site.start), siteX1 = grid.x(ofColumn: site.end)
        let frontX0 = grid.x(ofColumn: plot.frontage.start), frontX1 = grid.x(ofColumn: plot.frontage.end)
        let deepestPile = buildings.map(\.foundation.pileDepth).max() ?? 0
        let maxBasementDepth = Double(plot.maxBasementFloors) * grid.floorHeight
        let groundBottom = -max(60, deepestPile + 25, maxBasementDepth + 30)
        let midX = (siteX0 + siteX1) / 2
        let extent = Rect(minX: midX - terrainHalfWidth, minY: groundBottom,
                          maxX: midX + terrainHalfWidth, maxY: 200)

        var d = Drawing()
        d.section("backdrop") {
            BackdropArt.draw(into: &$0, span: (midX - backdropHalfWidth)...(midX + backdropHalfWidth), focusX: midX + 180, palette: p, seed: city.seed)
        }
        d.section("neighbors") { d in
            let leftRoom = frontX0 - siteX0, rightRoom = siteX1 - frontX1
            var rng = SeededRandom(seed: city.seed, stream: UInt64(propertyID.raw))
            if leftRoom >= 12 {
                let floors = Double(rng.int(in: 5..<8))
                NeighborArt.draw(into: &d, rect: Rect(minX: siteX0 + 3, minY: 0, maxX: frontX0 - 2.5, maxY: floors * grid.floorHeight + 0.6),
                                 style: .masonry, grid: grid, palette: p, seed: city.seed &+ 1)
            }
            if rightRoom >= 12 {
                let floors = Double(rng.int(in: 9..<14))
                NeighborArt.draw(into: &d, rect: Rect(minX: frontX1 + 2.5, minY: 0, maxX: siteX1 - 3, maxY: floors * grid.floorHeight + 1.2),
                                 style: .glass, grid: grid, palette: p, seed: city.seed &+ 2)
            }
        }
        d.section("terrain") {
            TerrainArt.draw(into: &$0, plot: plot, extent: Rect(minX: extent.minX, minY: groundBottom, maxX: extent.maxX, maxY: 0),
                            detailSpan: siteX0...siteX1, palette: p, seed: city.seed ^ UInt64(propertyID.raw))
        }
        d.section("structures") {
            for b in buildings { FoundationArt.draw(into: &$0, building: b, grid: grid, palette: p) }
        }
        d.section("site") { d in
            // Survey stakes marking the plot corners.
            for x in [frontX0, frontX1] {
                d.fill(Rect(minX: x - 0.04, minY: 0, maxX: x + 0.04, maxY: 1.0), p.surveyStake)
                d.fill(Rect(minX: x - 0.05, minY: 0.85, maxX: x + 0.05, maxY: 1.05), p.surveyCap)
            }
        }

        let foundationRect = buildings.map { b -> Rect in
            Rect(minX: grid.x(ofColumn: b.footprint.start) - 1, minY: -b.foundation.pileDepth - 1,
                 maxX: grid.x(ofColumn: b.footprint.end) + 1, maxY: 1.5)
        }.reduce(nil as Rect?) { acc, r in acc.map { $0.union(r) } ?? r }

        return SiteComposition(
            propertyID: propertyID, grid: grid, plot: plot, drawing: d, index: DrawingIndex(d),
            sky: .day(p), extent: extent.union(d.bounds),
            siteRect: Rect(minX: siteX0, minY: groundBottom, maxX: siteX1, maxY: 0),
            frontageRect: Rect(minX: frontX0, minY: -maxBasementDepth, maxX: frontX1, maxY: 0),
            foundationRect: foundationRect,
            cameraBounds: Rect(minX: siteX0, minY: groundBottom, maxX: siteX1, maxY: skyCeiling))
    }
}
