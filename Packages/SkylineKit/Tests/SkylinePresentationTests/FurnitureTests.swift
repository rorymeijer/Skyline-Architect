import Testing
import SkylineCore
import SkylineContent
@testable import SkylinePresentation

@Suite struct LayoutResolverTests {
    static let materials = ["wood": RGBA(hex: 0x996633), "red": RGBA(hex: 0xAA0000), "blue": RGBA(hex: 0x0000AA)]
    static func box(_ id: String, _ w: Double) -> FurnitureDefinition {
        FurnitureDefinition(id: id, name: id, width: w, height: 1, parts: [FurniturePart(shape: .rect, x: 0, y: 0, w: w, h: 1, material: "wood")])
    }
    static let catalog = ArtCatalog(
        materials: materials,
        furniture: [box("door", 1), box("cabinet", 0.5), box("plant", 0.6), box("desk", 1.6), box("big", 3),
                    FurnitureDefinition(id: "car", name: "car", width: 4.5, height: 1.4,
                                        parts: [FurniturePart(shape: .rect, x: 0, y: 0, w: 4.5, h: 1, material: "$body")],
                                        variants: [["body": "red"], ["body": "blue"]])],
        layouts: [])

    func resolve(_ items: [InteriorLayout.Item], width: Double, seed: UInt64 = 1) -> [PlacedFurniture] {
        LayoutResolver.resolve(InteriorLayout(room: "r", items: items), catalog: Self.catalog, x0: 10, x1: 10 + width, floorY: 4, seed: seed)
    }

    @Test func anchorsPlaceAgainstWallsAndCenter() {
        let placed = resolve([
            .init(furniture: "door", anchor: .left, offset: 0.3),
            .init(furniture: "plant", anchor: .right, offset: 0.2),
            .init(furniture: "cabinet", anchor: .center),
        ], width: 8)
        #expect(placed.map(\.furniture) == ["door", "plant", "cabinet"])
        #expect(placed[0].x == 10.3)
        #expect(abs(placed[1].x - (18 - 0.2 - 0.6)) < 1e-9)
        #expect(abs(placed[2].x - 13.75) < 1e-9)
        #expect(placed.allSatisfy { $0.y == 4 })
    }

    @Test func collidingOrOversizedItemsAreSkipped() {
        let placed = resolve([
            .init(furniture: "big", anchor: .left, offset: 0),
            .init(furniture: "desk", anchor: .left, offset: 1),      // overlaps "big"
            .init(furniture: "big", anchor: .right, offset: 0),      // does not fit in 5 m with the first
        ], width: 5)
        #expect(placed.map(\.furniture) == ["big"])
    }

    @Test func roomWidthConditionsSelectAlternatives() {
        let items: [InteriorLayout.Item] = [
            .init(furniture: "big", anchor: .left, minRoomWidth: 7.5),
            .init(furniture: "desk", anchor: .left, maxRoomWidth: 7.49),
        ]
        #expect(resolve(items, width: 6).map(\.furniture) == ["desk"])
        #expect(resolve(items, width: 9).map(\.furniture) == ["big"])
    }

    @Test func repeatsFillTheWidestGapWithoutOverlap() {
        let items: [InteriorLayout.Item] = [
            .init(furniture: "door", anchor: .left, offset: 0.2),
            .init(furniture: "plant", anchor: .right, offset: 0.1),
            .init(repeat: .init(spacing: 2.2, margin: 0.3, items: [.init(furniture: "desk", offset: 0)])),
        ]
        for width in [6.0, 9.7, 15.5] {
            let placed = resolve(items, width: width)
            let desks = placed.filter { $0.furniture == "desk" }
            let free = width - 0.2 - 1 - 0.1 - 0.6 - 0.6
            #expect(desks.count == Int(((free - 1.6) / 2.2).rounded(.down)) + 1)
            // No reserved piece overlaps another.
            let spans = placed.map { p in (p.x, p.x + Self.catalog.furniture[p.furniture]!.width) }.sorted { $0.0 < $1.0 }
            for (a, b) in zip(spans, spans.dropFirst()) { #expect(a.1 <= b.0 + 1e-9) }
            #expect(spans.first!.0 >= 10 && spans.last!.1 <= 10 + width)
        }
    }

    @Test func variantsAreDeterministicPerSeed() {
        let items: [InteriorLayout.Item] = [.init(repeat: .init(spacing: 5, items: [.init(furniture: "car", offset: 0)]))]
        let a = resolve(items, width: 30, seed: 7), b = resolve(items, width: 30, seed: 7)
        #expect(a == b)
        #expect(Set(a.map(\.variant)).isSubset(of: [0, 1]))
    }

    @Test func flippedPartsMirrorWithinTheirPiece() {
        var d = Drawing()
        let def = FurnitureDefinition(id: "x", name: "x", width: 2, height: 1, parts: [FurniturePart(shape: .rect, x: 0, y: 0, w: 0.5, h: 1, material: "wood")])
        let cat = ArtCatalog(materials: Self.materials, furniture: [def], layouts: [])
        FurnitureArt.draw(into: &d, PlacedFurniture(furniture: "x", x: 10, y: 0, flip: true, variant: 0), catalog: cat)
        #expect(d.items.first?.bounds == Rect(minX: 11.5, minY: 0, maxX: 12, maxY: 1))
    }
}

@Suite struct ArtContentTests {
    @Test func baseArtCatalogIsCompleteAndValid() throws {
        let lib = try ContentLibrary.loadBase()
        let art = lib.artCatalog
        #expect(art.furniture.count >= 25)
        for room in ["office-small", "apartment-studio", "lobby", "corridor", "mechanical", "parking"] {
            #expect(art.layouts[room] != nil, "missing layout for \(room)")
        }
        #expect(ArtCatalog.validate(materials: art.materials, furniture: Array(art.furniture.values), layouts: Array(art.layouts.values)).isEmpty)
    }

    @Test func validationReportsBrokenReferences() {
        let bad = FurnitureDefinition(id: "b", name: "b", width: 1, height: 1, parts: [
            FurniturePart(shape: .rect, x: 0, y: 0, w: 1, h: 1, material: "nope"),
            FurniturePart(shape: .polygon, points: [[0, 0]], material: "wood"),
            FurniturePart(shape: .rect, x: 0, y: 0, w: 1, h: 1, material: "$slot"),
        ])
        let problems = ArtCatalog.validate(materials: ["wood": .black], furniture: [bad],
                                           layouts: [InteriorLayout(room: "r", items: [.init(furniture: "ghost")])])
        #expect(problems.count == 4)
    }

    @Test func colorsParse() {
        #expect(ArtCatalog.parseColor("#FF0000") == RGBA(1, 0, 0))
        #expect(ArtCatalog.parseColor("#00FF0080")?.a == 128.0 / 255.0)
        #expect(ArtCatalog.parseColor("red") == nil)
    }

    /// Standard office widths get a sensible number of workstations.
    @Test func officeDeskCountScalesWithWidth() throws {
        let art = try ContentLibrary.loadBase().artCatalog
        let layout = try #require(art.layouts["office-small"])
        func desks(_ w: Double) -> Int {
            LayoutResolver.resolve(layout, catalog: art, x0: 0, x1: w, floorY: 0, seed: 1).filter { $0.furniture == "desk-workstation" }.count
        }
        #expect(desks(5.7) >= 1)
        #expect(desks(15.6) > desks(9.8))
    }
}

@Suite struct FacadeLODTests {
    func towerComposition() throws -> SiteComposition {
        let lib = try ContentLibrary.loadBase()
        var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: lib)
        let b = try #require(game.world.buildings(on: game.activePropertyID).first)
        for c in try #require(lib.blueprint("demo-tower")).commands(for: b) { try ConstructionEngine(catalog: lib.buildCatalog).apply(c, to: &game.world) }
        return try #require(SiteComposer.compose(world: game.world, propertyID: game.activePropertyID,
                                                 catalog: lib.buildCatalog, art: lib.artCatalog))
    }

    @Test func detailBandsAreRespected() {
        var d = Drawing()
        d.detailBand(min: 6) { $0.fill(Rect(x: 0, y: 0, width: 1, height: 1), .black) }
        d.detailBand(max: 6) { $0.fill(Rect(x: 0, y: 0, width: 1, height: 1), .white, minDetail: 2) }
        let index = DrawingIndex(d)
        let r = Rect(x: 0, y: 0, width: 1, height: 1)
        #expect(index.items(in: r, of: d, detail: 1) == [])
        #expect(index.items(in: r, of: d, detail: 4) == [1])
        #expect(index.items(in: r, of: d, detail: 6) == [0])
    }

    /// Zoomed out, the tower is a façade; zoomed in, a furnished cutaway — never both.
    @Test func facadeReplacesCutawayWhenZoomedOut() throws {
        let c = try towerComposition()
        let storey = Rect(minX: 8, minY: 8, maxX: 40, maxY: 12)  // floor 2
        let far = c.buildings.items(in: storey, detail: 4)
        let near = c.buildings.items(in: storey, detail: 32)
        #expect(far.contains { $0.maxDetail == BuildingArt.cutawayDetail })  // façade present
        #expect(near.count > far.count * 3)
        #expect(far.allSatisfy { $0.maxDetail <= BuildingArt.cutawayDetail || $0.maxDetail == .infinity })
        #expect(near.allSatisfy { $0.maxDetail > 32 })
    }
}
