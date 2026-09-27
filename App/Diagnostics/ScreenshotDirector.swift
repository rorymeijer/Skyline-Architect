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

    /// Phase 9 = milestone M1: the captures walk the First Playable checklist.
    let steps: [Step] = [
        Step(name: "01-main-menu", grid: false) { model, scene in
            model.showDeveloperHUD = false
            model.showMainMenu = true
            scene.apply(preset: .overview)
            return "Launch: main menu (no saves yet, so no Continue)."
        },
        Step(name: "02-build-and-pay", grid: false) { model, scene in
            model.startFromMenu()
            model.setSpeed(.paused)  // captures advance time explicitly
            let before = model.world?.ledger.cash ?? 0
            model.applyBlueprint("demo-tower")
            model.showEconomyPanel = true
            model.refreshSimulationSummary()
            scene.withController { $0.jump(center: Vec2(22, 16), zoom: 11.5) }
            let after = model.world?.ledger.cash ?? 0
            return "New game, demo tower built through construction commands: cash \(before) → \(after) (paid \(before - after))."
        },
        Step(name: "03-first-rent", grid: false) { model, scene in
            model.borrow()
            model.advanceSimulation(toTimeOfDay: 12, minute: 0)
            model.advanceSimulation(toTimeOfDay: 6, minute: 5)            // day 2, after the first closing
            model.refreshSimulationSummary()
            let e = model.economy
            return "\(model.clockText): first daily closing — rent \(e.lastDay.amount(.rent)), maintenance \(e.lastDay.amount(.maintenance)), " +
                "utilities \(e.lastDay.amount(.utilities)), interest \(e.lastDay.amount(.interest)); \(model.leasing.leased)/\(model.leasing.units) let; loan \(e.loans)."
        },
        Step(name: "04-dusk", grid: false) { model, scene in
            model.showEconomyPanel = false
            model.advanceSimulation(toTimeOfDay: 20, minute: 10)
            model.refreshSimulationSummary()
            return "\(model.clockText): dusk — ambient light \(Int(DayNight.daylight(atTick: Double(model.world?.clock.tick ?? 0)) * 100)) %, lights coming on."
        },
        Step(name: "05-night", grid: false) { model, scene in
            model.advanceSimulation(toTimeOfDay: 23, minute: 0)
            model.refreshSimulationSummary()
            return "\(model.clockText): night — occupied rooms lit, lobbies dim; \(model.population.inRooms) people inside."
        },
        Step(name: "06-economy-week", grid: false) { model, scene in
            model.advanceSimulation(toTimeOfDay: 7, minute: 0)
            model.advanceSimulation(ticks: 5 * SimClock.secondsPerDay)     // day 7
            model.showEconomyPanel = true
            model.refreshSimulationSummary()
            let e = model.economy
            return "\(model.clockText): cash \(e.cash), week income \(e.week.income), expenses \(e.week.expenses), loans \(e.loans)."
        },
        Step(name: "07-menu-continue", grid: false) { model, scene in
            model.showEconomyPanel = false
            let saved = model.save(title: "M1 walkthrough")
            model.startFromMenu()
            model.setSpeed(.paused)
            model.showMainMenu = true
            return "Saved (\(saved)), started over, back at the main menu: Continue offers \(model.latestSave?.metadata?.title ?? "nothing")."
        },
        Step(name: "08-continued", grid: false) { model, scene in
            let expected = try? model.saveStore.load(slot: model.latestSave?.slot ?? "", availablePacks: model.packReferences)
            model.continueLatest()
            model.setSpeed(.paused)
            model.refreshSimulationSummary()
            scene.withController { $0.jump(center: Vec2(22, 16), zoom: 11.5) }
            return "Continued at \(model.clockText) with cash \(model.economy.cash) and \(model.leasing.leased) tenants; " +
                "matches the save: \(expected.map { $0.world == model.world } ?? false)."
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
