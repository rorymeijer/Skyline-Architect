#if DEBUG
import Foundation
import ImageIO
import SpriteKit
import SwiftUI
import UniformTypeIdentifiers
import SkylineCore
import SkylineContent
import SkylinePersistence
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

    // Scale captures (Phase 19): the generated stress tower (developer tool, every unit let
    // at once) rendered and simulated in the real app; notes carry the simulation time of
    // the last frame and the render diagnostics are in the report.
    let steps: [Step] = [
        Step(name: "01-stress-overview", grid: false) { model, scene in
            model.setSpeed(.paused)  // captures advance time explicitly
            model.showDeveloperHUD = true
            model.loadStressTower(zones: 10)
            model.advanceSimulation(toTimeOfDay: 10)
            model.refreshSimulationSummary()
            model.scene?.withController { $0.jump(center: Vec2(41, 420), zoom: 0.75) }
            return "Stress tower: \(ScreenshotDirector.scale(model)); \(model.clockText)"
        },
        Step(name: "02-morning-rush", grid: false) { model, scene in
            model.advanceSimulation(ticks: SimClock.secondsPerDay)
            model.advanceSimulation(toTimeOfDay: 8, minute: 20)
            model.refreshSimulationSummary()
            model.scene?.withController { $0.jump(center: Vec2(41, 88), zoom: 9) }
            return "\(model.clockText), sky lobby 21 and zone 2 at rush hour; last step \(String(format: "%.1f", model.lastSimulationMs)) ms; \(ScreenshotDirector.scale(model))"
        },
        Step(name: "03-sky-lobby", grid: false) { model, scene in
            model.advanceSimulation(ticks: 90)
            model.refreshSimulationSummary()
            model.scene?.withController { $0.jump(center: Vec2(40, 86), zoom: 24) }
            let waiting: Int = ScreenshotDirector.waiting(in: model.world ?? GameWorld())
            return "\(model.clockText), close-up of the sky lobby on floor 21: \(waiting) people waiting in the tower"
        },
        Step(name: "04-upper-zones", grid: false) { model, scene in
            model.scene?.withController { $0.jump(center: Vec2(41, 780), zoom: 3) }
            return "Upper zones (floors 170–210) zoomed out: façade level of detail; \(ScreenshotDirector.scale(model))"
        },
        Step(name: "05-night", grid: false) { model, scene in
            model.advanceSimulation(toTimeOfDay: 22)
            model.refreshSimulationSummary()
            model.scene?.withController { $0.jump(center: Vec2(41, 420), zoom: 0.75) }
            return "\(model.clockText): 211 floors at night (lit homes, dark offices); \(ScreenshotDirector.scale(model))"
        },
        Step(name: "06-400-floors", grid: false) { model, scene in
            model.loadStressTower(zones: 19)
            model.advanceSimulation(toTimeOfDay: 10)
            model.refreshSimulationSummary()
            model.scene?.withController { $0.jump(center: Vec2(55, 790), zoom: 0.4) }
            return "400-floor stress tower: \(ScreenshotDirector.scale(model)); last step \(String(format: "%.1f", model.lastSimulationMs)) ms"
        },
        Step(name: "07-save-load", grid: false) { model, scene in
            let before = model.world
            let t0 = Date()
            let saved: Bool = model.save(slot: "capture-roundtrip", title: "Stress round trip")
            let t1 = Date()
            let loaded: Bool = model.load(slot: "capture-roundtrip")
            let t2 = Date()
            let identical: Bool = before != nil && before == model.world
            let ms = String(format: "save %.0f ms, load %.0f ms", t1.timeIntervalSince(t0) * 1000, t2.timeIntervalSince(t1) * 1000)
            return "400-floor tower saved and reloaded: saved=\(saved) loaded=\(loaded) worldIdentical=\(identical) (\(ms), Debug build, incl. scene rebuild)"
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
