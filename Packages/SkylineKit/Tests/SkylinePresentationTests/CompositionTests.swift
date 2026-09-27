import Testing
import SkylineCore
import SkylineContent
@testable import SkylinePresentation

@Suite struct CompositionTests {
    func compose() throws -> SiteComposition {
        let game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: ContentLibrary.loadBase())
        return try #require(SiteComposer.compose(world: game.world, propertyID: game.activePropertyID))
    }

    @Test func compositionIsDeterministic() throws {
        let a = try compose(), b = try compose()
        #expect(a.site.drawing.items == b.site.drawing.items)
        #expect(a.buildings.drawing.items == b.buildings.drawing.items)
    }

    @Test func sectionsArePresentInPaintOrder() throws {
        let c = try compose()
        #expect(c.site.drawing.sections.map(\.name) == ["backdrop", "neighbors", "terrain", "site"])
        #expect(c.site.drawing.sections.allSatisfy { !$0.range.isEmpty })
        #expect(c.buildings.drawing.sections.count == 1)
    }

    @Test func foundationLiesWithinFrontageAndReachesPileDepth() throws {
        let c = try compose()
        let f = try #require(c.foundationRect)
        #expect(f.minX >= c.frontageRect.minX - 1 && f.maxX <= c.frontageRect.maxX + 1)
        let deepest = c.buildings.drawing.items.map(\.bounds.minY).min()!
        #expect(deepest <= -20 && deepest > -21)  // piles reach 20 m (+ rounded toe)
    }

    /// The widest possible view (2560 pt at minimum zoom) must be fully covered by art.
    @Test func extentCoversWidestView() throws {
        let c = try compose()
        let cam = Camera2D(center: c.siteRect.center, zoom: 0.35, viewportSize: Vec2(2560, 1600),
                           limits: .standard(bounds: c.cameraBounds))
        #expect(cam.visibleRect.minX >= c.extent.minX && cam.visibleRect.maxX <= c.extent.maxX)
    }

    @Test func presetsProduceValidPlacements() throws {
        let c = try compose()
        for preset in CameraPreset.allCases {
            let p = preset.placement(for: c, viewport: Vec2(1440, 900))
            #expect(p.zoom >= 0.35 && p.zoom <= 96)
            #expect(c.cameraBounds.contains(p.center))
        }
    }

    @Test func fineDetailIsHiddenWhenZoomedOut() throws {
        let c = try compose()
        let view = c.siteRect
        let far = c.items(in: view, detail: 2).count
        let near = c.items(in: view, detail: 128).count
        #expect(far * 5 < near)
    }

    @Test func svgRendersVisibleItems() throws {
        let c = try compose()
        let svg = SVGRenderer.render(c, view: Rect(minX: 0, minY: -20, maxX: 48, maxY: 5), options: .init(pixelsPerMeter: 10))
        #expect(svg.hasPrefix("<svg"))
        #expect(svg.contains("<polygon"))
        #expect(svg.hasSuffix("</svg>"))
    }
}

@Suite struct ArchitecturalGridTests {
    let grid = GridSpec.standard
    let plot = Plot(frontage: ColumnSpan(start: 0, count: 48), maxBasementFloors: 3, siteMargin: 40,
                    strata: [SoilStratum(material: .clay, thickness: 10), SoilStratum(material: .bedrock, thickness: 1)])

    @Test(arguments: [0.35, 1, 3, 10, 30, 96])
    func lineCountIsBoundedByScreenNotWorld(zoom: Double) {
        let viewport = Vec2(1440, 900)
        let cam = Camera2D(center: Vec2(24, viewport.y / zoom / 2 - 10), zoom: zoom, viewportSize: viewport,
                           limits: .standard(bounds: Rect(minX: -40, minY: -60, maxX: 88, maxY: 3000)))
        let o = ArchitecturalGrid.build(grid: grid, plot: plot, visible: cam.visibleRect, zoom: zoom)
        let maxLines = Int(viewport.x / ArchitecturalGrid.minLineSpacing + viewport.y / ArchitecturalGrid.minLineSpacing) + 4
        #expect(o.lines.count <= maxLines)
        // Horizontal spacing never below the minimum.
        #expect(grid.floorHeight * Double(o.floorStride) * zoom >= ArchitecturalGrid.minLineSpacing || o.floorStride == 2500)
        // Everything stays inside the frontage and above the deepest basement.
        for l in o.lines {
            #expect(l.from.x >= 0 && l.to.x <= 48)
            #expect(min(l.from.y, l.to.y) >= -12 - 1e-9)
        }
    }

    @Test func closeZoomShowsModulesAndEveryFloorLabel() {
        let visible = Rect(minX: 0, minY: -12, maxX: 48, maxY: 20)
        let o = ArchitecturalGrid.build(grid: grid, plot: plot, visible: visible, zoom: 30)
        #expect(o.columnStride == 1)
        #expect(o.floorStride == 1)
        #expect(o.labels.map(\.text) == ["B3", "B2", "B1", "G", "1", "2", "3", "4"])
        #expect(o.lines.contains { $0.style == .grade })
        #expect(o.lines.filter { $0.style == .plotBoundary }.count == 2)
        #expect(o.lines.contains { $0.style == .bay })
    }

    /// No floor limit: the grid continues far above any existing construction.
    @Test func gridReachesHighAltitudes() {
        let visible = Rect(minX: -100, minY: 1900, maxX: 150, maxY: 2100)
        let o = ArchitecturalGrid.build(grid: grid, plot: plot, visible: visible, zoom: 2)
        #expect(o.labels.contains { $0.floor >= 480 })
    }
}
