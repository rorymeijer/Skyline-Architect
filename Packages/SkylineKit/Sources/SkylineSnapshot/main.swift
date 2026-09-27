// skyline-snapshot — renders a composition view to SVG for design review.
// These are DESIGN PREVIEWS of the drawing IR, not screenshots of the running game.
//
// Usage: skyline-snapshot [--preset overview|foundation|detail|skyline|building] [--width 1440]
//                         [--height 900] [--scale 1] [--no-grid] [--blueprint demo-tower]
//                         [--center x,y --zoom z] --out file.svg
import Foundation
import SkylineCore
import SkylineContent
import SkylinePresentation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("skyline-snapshot: \(message)\n".utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

let presetName = option("--preset") ?? "overview"
guard let preset = CameraPreset(rawValue: presetName) else { fail("unknown preset \(presetName)") }
let viewport = Vec2(Double(option("--width") ?? "1440") ?? 1440, Double(option("--height") ?? "900") ?? 900)
let scale = Double(option("--scale") ?? "1") ?? 1
guard let out = option("--out") else { fail("--out is required") }

do {
    let library = try ContentLibrary.loadBase()
    var game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: library)
    let catalog = library.buildCatalog
    if let id = option("--blueprint") {
        guard let blueprint = library.blueprint(id), let building = game.world.buildings(on: game.activePropertyID).first else {
            fail("unknown blueprint \(id)")
        }
        let engine = ConstructionEngine(catalog: catalog)
        for command in blueprint.commands(for: building) { try engine.apply(command, to: &game.world) }
    }
    guard let composition = SiteComposer.compose(world: game.world, propertyID: game.activePropertyID, catalog: catalog) else {
        fail("property missing")
    }
    var placement = preset.placement(for: composition, viewport: viewport)
    if let c = option("--center")?.split(separator: ",").compactMap({ Double($0) }), c.count == 2,
       let z = option("--zoom").flatMap(Double.init) {
        placement = (Vec2(c[0], c[1]), z)
    }
    var camera = Camera2D(center: placement.center, zoom: placement.zoom, viewportSize: viewport,
                          limits: .standard(bounds: composition.cameraBounds))
    camera.setCenter(placement.center)
    let view = camera.visibleRect
    let grid = args.contains("--no-grid") ? nil
        : ArchitecturalGrid.build(grid: composition.grid, plot: composition.plot, visible: view, zoom: camera.zoom)
    let level = DetailLevelPolicy().level(forZoom: camera.zoom, current: nil)
    let caption = "DESIGN PREVIEW (skyline-snapshot, not a game screenshot) — preset \(preset.rawValue), \(String(format: "%.2f", camera.zoom)) pt/m, LOD \(level)"
    let labels = RoomLabels.build(world: game.world, propertyID: game.activePropertyID, catalog: catalog, visible: view, zoom: camera.zoom)
    let svg = SVGRenderer.render(composition, view: view, options: .init(
        pixelsPerMeter: camera.zoom * scale, gridOverlay: grid, caption: caption, roomLabels: labels))
    try svg.write(toFile: out, atomically: true, encoding: .utf8)
    let items = composition.layers.map { $0.drawing.items.count }.reduce(0, +)
    print("wrote \(out) — \(items) items total, view \(view)")
} catch {
    fail("\(error)")
}
