#if DEBUG
import Foundation
import ImageIO
import SpriteKit
import SwiftUI
import UniformTypeIdentifiers
import SkylineCore
import SkylinePresentation
import SkylineSimulation
#if os(macOS)
import AppKit
#endif

/// Debug-only automated capture used by CI and `Scripts/capture-screenshots.sh`.
///
/// Launch with `--capture-screenshots <dir>`: the director runs a deterministic script
/// (build the demo tower through the construction engine, show placement previews, save and
/// reload, undo), sets camera presets, waits until the camera is at rest and every wanted
/// tile is displayed,
/// captures the SKView's rendered scene (scene = viewport, DECISIONS D-004), composites
/// the real SwiftUI chrome on top via `ImageRenderer`, writes PNGs plus
/// `capture-report.json`, then exits.
final class ScreenshotDirector {
    struct Configuration {
        let directory: URL

        init?(arguments: [String]) {
            guard let i = arguments.firstIndex(of: "--capture-screenshots"), i + 1 < arguments.count else { return nil }
            directory = URL(fileURLWithPath: arguments[i + 1], isDirectory: true)
        }
    }

    struct Step {
        let name: String
        let grid: Bool
        /// Prepares the scene (camera, tool, world changes). Returns a note for the report.
        let setup: (AppModel, WorldScene) -> String
    }

    struct ReportEntry: Codable {
        let file: String
        let note: String
        let grid: Bool
        let settled: Bool
        let waitSeconds: Double
        let pixelWidth: Int
        let pixelHeight: Int
        let diagnostics: RenderDiagnostics
    }

    private let configuration: Configuration
    private weak var model: AppModel?
    private var scene: WorldScene? { model?.scene }
    private var stepIndex = 0
    private var report: [ReportEntry] = []
    private var started = false

    let steps: [Step] = [
        Step(name: "01-vacant-tower", grid: false) { model, scene in
            model.setSpeed(.paused)  // captures advance time explicitly
            model.applyBlueprint("demo-tower")
            model.showDeveloperHUD = false
            model.showLeasingPanel = true
            model.refreshSimulationSummary()
            scene.withController { $0.jump(center: Vec2(22, 16), zoom: 11.5) }
            return "New demo tower at \(model.clockText): \(model.leasing.units) rentable units, \(model.leasing.leased) let, nobody inside."
        },
        Step(name: "02-first-tenants", grid: false) { model, scene in
            model.advanceSimulation(toTimeOfDay: 20, minute: 0)
            model.refreshSimulationSummary()
            let m = model.leasing.market
            return "\(model.clockText): \(model.leasing.leased)/\(model.leasing.units) let after \(m.prospects) prospects " +
                "(\(m.signed) signed); rent roll \(model.leasing.rentRoll)/month."
        },
        Step(name: "03-inspector-tenant", grid: false) { model, scene in
            model.showLeasingPanel = false
            guard let world = model.world, let tenant = world.tenants.values.first(where: { t in
                model.simulation?.rules.tenantType(t.typeID)?.kind == "business" }) ?? world.tenants.values.first,
                  let room = world.rooms[tenant.room] else { return "no tenant yet" }
            model.selectRoom(at: ScreenshotDirector.cell(of: room))
            return "\(model.clockText): inspector for \(tenant.name) (\(tenant.typeID)), rent \(tenant.rent)/month."
        },
        Step(name: "04-inspector-vacant", grid: false) { model, scene in
            guard let world = model.world, let simulation = model.simulation else { return "no world" }
            let vacant = Leasing.vacantUnits(world, catalog: simulation.catalog)
            guard let room = vacant.min(by: { a, b in
                let sa = UnitReport.make(room: a, world: world, engine: simulation)?.interest.first?.appraisal.total ?? 0
                let sb = UnitReport.make(room: b, world: world, engine: simulation)?.interest.first?.appraisal.total ?? 0
                return (sa, a.id) < (sb, b.id)
            }) else { return "no vacant unit left at \(model.clockText)" }
            model.selectRoom(at: ScreenshotDirector.cell(of: room))
            let r = model.unitReport
            return "\(model.clockText): vacant \(r?.title ?? "") on \(r?.floor ?? "") — " +
                (r?.interest.map { "\($0.typeName) \(Int($0.appraisal.total * 100))% \($0.wouldSign ? "would sign" : LeasingSummary.describe($0.appraisal.weakest))" }
                    .joined(separator: ", ") ?? "")
        },
        Step(name: "05-mixed-schedules", grid: false) { model, scene in
            model.selectRoom(at: nil)
            model.showDeveloperHUD = true
            model.advanceSimulation(toTimeOfDay: 7, minute: 20)       // day 2
            model.advanceSimulation(ticks: SimClock.secondsPerDay)    // day 3
            model.advanceSimulation(ticks: model.ticksToBestMoment(within: 3 * 3600, step: 60) { ScreenshotDirector.travelling(in: $0) })
            model.refreshSimulationSummary()
            let types = Dictionary(grouping: model.world?.tenants.values ?? [], by: \.typeID).map { "\($0.key) \($0.value.count)" }.sorted()
            return "Day 3 \(model.clockText): \(model.population.travelling) on the move; tenants: " + types.joined(separator: ", ")
        },
        Step(name: "06-leasing-week", grid: false) { model, scene in
            model.showDeveloperHUD = false
            model.showLeasingPanel = true
            model.advanceSimulation(toTimeOfDay: 9, minute: 0)
            model.advanceSimulation(ticks: 4 * SimClock.secondsPerDay)  // day 7
            model.refreshSimulationSummary()
            let s = model.leasing, m = s.market
            return "\(model.clockText): \(s.leased)/\(s.units) let, avg satisfaction \(Int(s.averageSatisfaction * 100))%, " +
                "prospects \(m.prospects), signed \(m.signed), moved out \(m.movedOut), declines " +
                DeclineReason.allCases.map { "\($0.rawValue) \(m.declines($0))" }.joined(separator: " ")
        },
        Step(name: "07-save-load-roundtrip", grid: false) { model, scene in
            model.showLeasingPanel = false
            let before = model.world
            let saved = model.save(slot: "capture-roundtrip", title: "Capture round trip")
            let loaded = model.load(slot: "capture-roundtrip")
            let identical = before != nil && before == model.world
            model.refreshSimulationSummary()
            scene.apply(preset: .building)
            return "Saved and reloaded with \(model.population.total) people: saved=\(saved) loaded=\(loaded) worldIdentical=\(identical)"
        },
    ]

    init(configuration: Configuration, model: AppModel) {
        self.configuration = configuration
        self.model = model
    }

    func start() {
        guard !started else { return }
        started = true
        #if os(macOS)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
        try? FileManager.default.createDirectory(at: configuration.directory, withIntermediateDirectories: true)
        log("capturing \(steps.count) screenshots to \(configuration.directory.path)")
        // Give the window a moment to reach its final size before the first step.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.runStep() }
    }

    private func runStep() {
        guard stepIndex < steps.count, let scene, let model else { finish(); return }
        let step = steps[stepIndex]
        model.setGrid(step.grid)
        let note = step.setup(model, scene)
        log("\(step.name): \(note)")
        waitUntilSettled(started: Date(), stableChecks: 0) { settled, waited in
            self.capture(step, note: note, settled: settled, waited: waited)
            self.stepIndex += 1
            self.runStep()
        }
    }

    /// Polls until the scene has been settled for several consecutive checks (tiles done,
    /// camera still, diagnostics refreshed) or a timeout passes.
    private func waitUntilSettled(started: Date, stableChecks: Int, completion: @escaping (Bool, Double) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let waited = Date().timeIntervalSince(started)
            let settled = self.scene?.isSettled ?? false
            let checks = settled ? stableChecks + 1 : 0
            if checks >= 6 && waited >= 1.0 {
                completion(true, waited)
            } else if waited > 20 {
                completion(false, waited)
            } else {
                self.waitUntilSettled(started: started, stableChecks: checks, completion: completion)
            }
        }
    }

    private func capture(_ step: Step, note: String, settled: Bool, waited: Double) {
        guard let scene, let view = scene.view, let model else { return }
        guard let texture = view.texture(from: scene, crop: CGRect(origin: .zero, size: scene.size)) else {
            log("\(step.name): SKView returned no texture")
            return
        }
        let world = texture.cgImage()
        let size = scene.size
        let scale = CGFloat(world.width) / max(size.width, 1)
        // ImageRenderer is main-actor isolated; this code always runs on the main queue.
        let chrome = MainActor.assumeIsolated { () -> UncheckedBox<CGImage?> in
            let renderer = ImageRenderer(content: ChromeOverlay(model: model)
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark))
            renderer.scale = scale
            return UncheckedBox(value: renderer.cgImage)
        }.value
        guard let composed = compose(world: world, chrome: chrome, background: scene.backgroundColor) else { return }
        let file = "\(step.name).png"
        let url = configuration.directory.appendingPathComponent(file)
        if writePNG(composed, to: url) {
            log("\(file): \(composed.width)×\(composed.height) settled=\(settled) after \(String(format: "%.1f", waited)) s")
        }
        report.append(ReportEntry(file: file, note: note, grid: step.grid, settled: settled,
                                  waitSeconds: waited, pixelWidth: composed.width, pixelHeight: composed.height,
                                  diagnostics: scene.currentDiagnostics))
    }

    private func compose(world: CGImage, chrome: CGImage?, background: SKColor) -> CGImage? {
        let w = world.width, h = world.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: ColorSpaces.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        ctx.setFillColor(background.cgColor)
        ctx.fill(rect)
        ctx.draw(world, in: rect)
        if let chrome { ctx.draw(chrome, in: rect) }
        return ctx.makeImage()
    }

    private func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest)
    }

    private func finish() {
        let info = Bundle.main.infoDictionary
        let payload: [String: Any] = [
            "version": info?["CFBundleShortVersionString"] as? String ?? "?",
            "build": info?["CFBundleVersion"] as? String ?? "?",
        ]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(report) {
            try? data.write(to: configuration.directory.appendingPathComponent("capture-report.json"))
        }
        log("done (\(report.count) captures, app \(payload["version"] ?? "?") build \(payload["build"] ?? "?"))")
        exit(report.count == steps.count ? 0 : 2)
    }

    private struct UncheckedBox<T>: @unchecked Sendable { let value: T }

    static func travelling(in world: GameWorld) -> Int {
        world.people.values.filter { if case .travelling = $0.place { true } else { false } }.count
    }

    /// Positions of people currently on stairs (optionally only between G and floor 3).
    static func climbers(in world: GameWorld, lowFloorsOnly: Bool) -> [Vec2] {
        world.people.values.compactMap { p in
            guard case let .travelling(legs, _) = p.place,
                  let s = PersonMotion.sample(legs, at: Double(world.clock.tick), grid: world.grid), s.onStairs else { return nil }
            if lowFloorsOnly && !(0...14).contains(s.position.y) { return nil }
            return s.position
        }
    }

    private func log(_ message: String) {
        FileHandle.standardError.write(Data("[capture] \(message)\n".utf8))
    }
}
#endif
