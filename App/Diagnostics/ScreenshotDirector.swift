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
        Step(name: "01-main-menu", grid: false) { model, scene in
            model.setSpeed(.paused)  // captures advance time explicitly
            model.showDeveloperHUD = false
            model.showMainMenu = true
            return "Main menu: New Game (standard, unlocks by building class) and New Sandbox (everything unlocked)."
        },
        Step(name: "02-standard-start", grid: false) { model, scene in
            model.startFromMenu()
            model.setSpeed(.paused)
            model.showProgressPanel = true
            if let world = model.world, let property = model.activePropertyID, let b = world.buildings(on: property).first {
                // A new game builds a new scene: move its camera, not the old one's.
                model.scene?.withController { $0.jump(center: Vec2(Double(b.footprint.start) + 16, 8), zoom: 14) }
            }
            model.refreshSimulationSummary()
            let p = model.progression
            return "Standard game: \(p.className), reputation \(Int(p.reputation)), floors up to \(p.maxFloor.map(String.init) ?? "∞"); " +
                "locked: \(p.lockedRooms.keys.sorted().joined(separator: ", "))."
        },
        Step(name: "03-class-c-tower", grid: false) { model, scene in
            model.applyBlueprint("demo-tower")
            model.refreshSimulationSummary()
            scene.withController { $0.jump(center: Vec2(22, 16), zoom: 11.5) }
            return "Demo tower built in class C: " + ScreenshotDirector.requirements(model.progression) + "."
        },
        Step(name: "04-first-tenants", grid: false) { model, scene in
            model.advanceSimulation(ticks: 2 * SimClock.secondsPerDay + 4 * 3600)
            model.refreshSimulationSummary()
            let p = model.progression
            return "\(model.clockText): \(model.leasing.leased)/\(model.leasing.units) units let, reputation \(Int(p.reputation)); " +
                ScreenshotDirector.requirements(p) + "."
        },
        Step(name: "05-promotion", grid: false) { model, scene in
            var days = 0
            while model.progression.classLevel == 0 && days < 12 {
                model.advanceSimulation(toTimeOfDay: 6, minute: 5)
                model.refreshSimulationSummary()
                days += 1
            }
            model.advanceSimulation(toTimeOfDay: 9)
            model.refreshSimulationSummary()
            return "\(model.clockText): \(model.progression.className) after \(days) more closing(s); banner: \(model.promotionNotice ?? "none")."
        },
        Step(name: "06-taller-than-class-c", grid: false) { model, scene in
            model.promotionNotice = nil
            var built: [Int] = []
            if let world = model.world, let property = model.activePropertyID, let b = world.buildings(on: property).first,
               let top = b.builtLevels?.highest, let span = b.plate(at: top)?.span {
                for level in (top + 1)...13 where model.perform(.buildFloor(building: b.id, level: level, span: span)) { built.append(level) }
            }
            model.refreshSimulationSummary()
            scene.withController { $0.jump(center: Vec2(22, 30), zoom: 11.5) }
            return "Floors built after the promotion: \(built.map(String.init).joined(separator: ", ")) (floor 13 needs class B); " +
                "limit now floor \(model.progression.maxFloor.map(String.init) ?? "∞")."
        },
        Step(name: "07-reputation-falls", grid: false) { model, scene in
            let before = model.progression.reputation
            // Neglect: the electrical room is demolished, so no unit has power.
            let plant = model.world?.rooms.values.first { $0.definitionID == "electrical-room" }
            let cut = plant.map { model.perform(.demolishRoom($0.id)) } ?? false
            model.advanceSimulation(ticks: 5 * SimClock.secondsPerDay)
            model.refreshSimulationSummary()
            scene.withController { $0.jump(center: Vec2(22, 16), zoom: 11.5) }
            return "\(model.clockText), electrical room demolished (\(cut)): reputation \(Int(before)) → " +
                "\(Int(model.progression.reputation)), moved out \(model.leasing.market.movedOut), let \(model.leasing.leased)/\(model.leasing.units); " +
                "still \(model.progression.className)."
        },
        Step(name: "08-save-load-roundtrip", grid: false) { model, scene in
            let before = model.world
            let saved = model.save(slot: "capture-roundtrip", title: "Capture round trip")
            let loaded = model.load(slot: "capture-roundtrip")
            let identical = before != nil && before == model.world
            model.refreshSimulationSummary()
            return "Saved and reloaded with class and reputation: saved=\(saved) loaded=\(loaded) worldIdentical=\(identical), " +
                "\(model.progression.className) \(Int(model.progression.reputation))"
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
