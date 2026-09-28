import Foundation
import SkylineCore

/// A painter-ordered drawing with its spatial index.
public struct CompositionLayer: Sendable {
    public let name: String
    public let drawing: Drawing
    public let index: DrawingIndex

    public init(name: String, drawing: Drawing) {
        self.name = name
        self.drawing = drawing
        self.index = DrawingIndex(drawing)
    }

    /// Items touching `rect` visible at `detail` px/m, in paint order.
    public func items(in rect: Rect, detail: Double) -> [DrawItem] {
        index.items(in: rect, of: drawing, detail: detail).map { drawing.items[$0] }
    }
}

/// Everything static the renderer needs to draw one property, in two layers:
/// `site` (backdrop, neighbours, terrain — composed once) and `buildings` (foundations,
/// storeys, rooms — recomposed when construction changes, see `SiteComposer.recompose`).
public struct SiteComposition: Sendable {
    public let propertyID: PropertyID
    public let grid: GridSpec
    public let plot: Plot
    public let site: CompositionLayer
    public internal(set) var buildings: CompositionLayer
    /// Night lights of the city and the neighbours' windows (Phase 12). Not part of
    /// `layers`: the renderer adds it separately, scaled by darkness and by how many
    /// windows are still lit at that hour (`DayNight.cityActivity`).
    public let emission: CompositionLayer
    /// Glow of the street lamps: added like `emission`, but on all night.
    public let lamps: CompositionLayer
    /// Silhouettes of the property's buildings: emission (city lights behind them) is
    /// cleared there, so distant windows never shine through the tower.
    public internal(set) var occluders: [Rect] = []
    public let sky: SkyGradient
    /// Region covered by static art; tiles outside it are never requested.
    public internal(set) var extent: Rect
    let siteExtent: Rect
    /// Site columns (frontage + margins) from the bottom of the ground section to grade.
    public let siteRect: Rect
    /// Buildable frontage from the deepest permitted basement to grade.
    public let frontageRect: Rect
    /// Union of all building foundations (excavation, piles, grade slab).
    public internal(set) var foundationRect: Rect?
    /// Union of all built storeys (nil when nothing is built above the foundation).
    public internal(set) var superstructureRect: Rect?
    /// Region the camera center is clamped to (see `CameraLimits.bounds`).
    public let cameraBounds: Rect

    /// Layers in paint order.
    public var layers: [CompositionLayer] { [site, buildings] }

    /// Items of all layers touching `rect` visible at `detail` px/m, in paint order.
    public func items(in rect: Rect, detail: Double) -> [DrawItem] {
        layers.flatMap { $0.items(in: rect, detail: detail) }
    }
}

public enum SiteComposer {
    /// Maximum altitude the camera may reach; there is no floor limit, this only bounds
    /// empty sky. Raise together with the tallest supported building.
    public static let skyCeiling = 3000.0
    /// Art must cover the widest possible view: a 2560 pt window at minimum zoom (0.35 pt/m)
    /// spans ~7.3 km, so terrain extends ±6 km and the skyline ±4.5 km.
    static let terrainHalfWidth = 6000.0
    static let backdropHalfWidth = 4500.0

    public static func compose(world: GameWorld, propertyID: PropertyID, catalog: BuildCatalog? = nil,
                               art: ArtCatalog = .empty, palette p: ArtPalette = .standard) -> SiteComposition? {
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
        let extent = Rect(minX: midX - terrainHalfWidth, minY: groundBottom, maxX: midX + terrainHalfWidth, maxY: 200)

        var d = Drawing()
        var lights = Drawing(), lamps = Drawing()
        // Neighbours stand in front of the city: their rects are known first so that
        // distant lit windows behind them are left out.
        var neighbors: [(Rect, NeighborArt.Style, UInt64)] = []
        do {
            let leftRoom = frontX0 - siteX0, rightRoom = siteX1 - frontX1
            var rng = SeededRandom(seed: city.seed, stream: UInt64(propertyID.raw))
            if leftRoom >= 12 {
                let floors = Double(rng.int(in: 5..<8))
                neighbors.append((Rect(minX: siteX0 + 3, minY: 0, maxX: frontX0 - 2.5, maxY: floors * grid.floorHeight + 0.6), .masonry, city.seed &+ 1))
            }
            if rightRoom >= 12 {
                let floors = Double(rng.int(in: 9..<14))
                neighbors.append((Rect(minX: frontX1 + 2.5, minY: 0, maxX: siteX1 - 3, maxY: floors * grid.floorHeight + 1.2), .glass, city.seed &+ 2))
            }
        }
        d.section("backdrop") {
            BackdropArt.draw(into: &$0, lights: &lights, avoid: neighbors.map(\.0), span: (midX - backdropHalfWidth)...(midX + backdropHalfWidth),
                             focusX: midX + 180, palette: p, seed: city.seed)
        }
        d.section("neighbors") { d in
            for (rect, style, seed) in neighbors {
                NeighborArt.draw(into: &d, lights: &lights, rect: rect, style: style, grid: grid, palette: p, seed: seed)
            }
        }
        d.section("terrain") {
            TerrainArt.draw(into: &$0, plot: plot, extent: Rect(minX: extent.minX, minY: groundBottom, maxX: extent.maxX, maxY: 0),
                            detailSpan: siteX0...siteX1, palette: p, seed: city.seed ^ UInt64(propertyID.raw))
        }
        d.section("site") { d in
            // Survey stakes marking the plot corners.
            for x in [frontX0, frontX1] {
                d.fill(Rect(minX: x - 0.04, minY: 0, maxX: x + 0.04, maxY: 1.0), p.surveyStake)
                d.fill(Rect(minX: x - 0.05, minY: 0.85, maxX: x + 0.05, maxY: 1.05), p.surveyCap)
            }
            NightArt.streetLamps(site: &d, lights: &lamps, at: NightArt.lampPositions(span: (midX - 600)...(midX + 600), keepClear: frontX0...frontX1),
                                 palette: p)
        }
        let siteLayer = CompositionLayer(name: "site", drawing: d)
        let siteExtent = extent.union(d.bounds)

        var composition = SiteComposition(
            propertyID: propertyID, grid: grid, plot: plot, site: siteLayer,
            buildings: CompositionLayer(name: "buildings", drawing: Drawing()),
            emission: CompositionLayer(name: "emission", drawing: lights),
            lamps: CompositionLayer(name: "lamps", drawing: lamps),
            sky: .day(p), extent: siteExtent, siteExtent: siteExtent,
            siteRect: Rect(minX: siteX0, minY: groundBottom, maxX: siteX1, maxY: 0),
            frontageRect: Rect(minX: frontX0, minY: -maxBasementDepth, maxX: frontX1, maxY: 0),
            foundationRect: nil, superstructureRect: nil,
            cameraBounds: Rect(minX: siteX0, minY: groundBottom, maxX: siteX1, maxY: skyCeiling))
        composition = recompose(composition, world: world, catalog: catalog, art: art, palette: p)
        return composition
    }

    /// Rebuilds only the buildings layer (after construction). The site layer is reused.
    public static func recompose(_ c: SiteComposition, world: GameWorld, catalog: BuildCatalog?,
                                 art: ArtCatalog = .empty, palette p: ArtPalette = .standard) -> SiteComposition {
        let grid = c.grid
        let buildings = world.buildings(on: c.propertyID)
        var d = Drawing()
        for b in buildings {
            d.section("building-\(b.id.raw)") { d in
                FoundationArt.draw(into: &d, building: b, grid: grid, palette: p)
                BuildingArt.draw(into: &d, building: b, rooms: world.rooms(in: b.id), catalog: catalog, art: art, grid: grid, palette: p)
            }
        }
        var out = c
        out.buildings = CompositionLayer(name: "buildings", drawing: d)
        out.occluders = buildings.flatMap(\.floors).filter { $0.level >= 0 }.map { plate in
            grid.rect(columns: plate.span, floors: FloorSpan(lowest: plate.level, highest: plate.level)).insetBy(dx: -0.6, dy: -0.8)
        }
        out.extent = c.siteExtent.union(d.bounds)
        out.foundationRect = buildings.map { b -> Rect in
            Rect(minX: grid.x(ofColumn: b.footprint.start) - 1, minY: -b.foundation.pileDepth - 1,
                 maxX: grid.x(ofColumn: b.footprint.end) + 1, maxY: 1.5)
        }.reduce(nil as Rect?) { acc, r in acc.map { $0.union(r) } ?? r }
        out.superstructureRect = buildings.flatMap(\.floors).filter { $0.level >= 0 }.map { plate -> Rect in
            grid.rect(columns: plate.span, floors: FloorSpan(lowest: plate.level, highest: plate.level))
        }.reduce(nil as Rect?) { acc, r in acc.map { $0.union(r) } ?? r }
        return out
    }

    /// World region whose appearance changes when `plan` is applied or undone: the cells
    /// plus a margin for partitions, façades, roofs and parapets drawn around them.
    public static func dirtyRect(for plan: ConstructionPlan, grid: GridSpec) -> Rect {
        let floors = FloorSpan(lowest: plan.floors.lowest - 1, highest: plan.floors.highest + 1)
        let columns = ColumnSpan(start: plan.columns.start - 1, count: plan.columns.count + 2)
        return grid.rect(columns: columns, floors: floors).insetBy(dx: -0.5, dy: -1.5)
    }
}
