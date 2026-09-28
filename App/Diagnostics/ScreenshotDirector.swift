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

    // Fires are started with the developer tool (`igniteForTesting`) and the storm is set
    // by the script; everything that follows is the simulation's own doing.
    let steps: [Step] = [
        Step(name: "01-ignition", grid: false) { model, scene in
            model.setSpeed(.paused)  // captures advance time explicitly
            model.showDeveloperHUD = false
            model.applyBlueprint("demo-tower")
            model.leaseAllVacant()
            ScreenshotDirector.force("clear", 22, model: model)
            model.advanceSimulation(toTimeOfDay: 10, minute: 30)
            let office = ScreenshotDirector.office(model, index: 2)
            let lit = office.map { model.igniteForTesting($0.id) } ?? false
            model.advanceSimulation(ticks: 90)
            model.refreshSimulationSummary()
            if let r = office, let world = model.world {
                scene.withController { $0.jump(center: world.grid.rect(columns: r.columns, floors: r.floors).center + Vec2(0, 1), zoom: 24) }
            }
            return "\(model.clockText): fire started in an office (developer tool: \(lit)); alert: \(model.incidentNotice ?? "none")"
        },
        Step(name: "02-evacuation", grid: false) { model, scene in
            model.advanceSimulation(ticks: 150)
            model.refreshSimulationSummary()
            scene.withController { $0.jump(center: Vec2(22, 14), zoom: 11.5) }
            let inside = model.population.inRooms + model.population.travelling
            return "\(model.clockText): evacuation by the stairs, no elevator rides; \(inside) still inside or on their way out."
        },
        Step(name: "03-spreading", grid: false) { model, scene in
            model.advanceSimulation(ticks: 11 * 60)
            model.refreshSimulationSummary()
            return "\(model.clockText): \(model.incidents.fires.first.map { "\($0.burningRooms) room(s) burning, brigade in \($0.brigadeInMinutes) min" } ?? "out"); building empty: \(model.population.inRooms == 0)."
        },
        Step(name: "04-fire-brigade", grid: false) { model, scene in
            let arrives = model.world?.incidents.fires.first?.brigadeArrives ?? 0
            let now = model.world?.clock.tick ?? 0
            model.advanceSimulation(ticks: max(arrives, now) - now + 120)
            model.refreshSimulationSummary()
            scene.withController { $0.jump(center: Vec2(10, 12), zoom: 11.5) }
            return "\(model.clockText): fire brigade on site — \(model.incidentNotice ?? "")"
        },
        Step(name: "05-aftermath", grid: false) { model, scene in
            var guardSteps = 0
            while !(model.world?.incidents.fires.isEmpty ?? true), guardSteps < 180 {
                model.advanceSimulation(ticks: 60)
                guardSteps += 1
            }
            model.advanceSimulation(ticks: 60)
            model.showIncidentsPanel = true
            model.showEconomyPanel = false
            model.refreshSimulationSummary()
            scene.withController { $0.jump(center: Vec2(22, 14), zoom: 11.5) }
            let repairs = model.world?.ledger.journal.last { $0.detail.hasPrefix("Fire damage") }
            return "\(model.clockText): \(model.incidents.recent.first?.detail ?? "—"); ledger: \(repairs.map { "\($0.detail) \($0.amount)" } ?? "—"); soot on the damaged rooms."
        },
        Step(name: "06-sprinklers", grid: false) { model, scene in
            model.showIncidentsPanel = false
            // A fire control room on a new floor 9 protects the whole tower.
            if let world = model.world, let property = model.activePropertyID, let b = world.buildings(on: property).first,
               let span = b.plate(at: 8)?.span {
                model.perform(.buildFloor(building: b.id, level: 9, span: span))
                model.perform(.placeRoom(building: b.id, definition: "fire-control-room", columns: ColumnSpan(start: span.start, count: 5),
                                         floors: FloorSpan(lowest: 9, highest: 9)))
            }
            model.advanceSimulation(toTimeOfDay: 14)
            let office = ScreenshotDirector.office(model, index: 5)
            let lit = office.map { model.igniteForTesting($0.id) } ?? false
            model.advanceSimulation(ticks: 120)
            model.refreshSimulationSummary()
            if let r = office, let world = model.world {
                scene.withController { $0.jump(center: world.grid.rect(columns: r.columns, floors: r.floors).center + Vec2(0, 1), zoom: 24) }
            }
            return "\(model.clockText): fire control room built; second fire (\(lit)) under sprinklers: \(model.sprinklerRooms.count) rooms protected."
        },
        Step(name: "07-sprinklers-win", grid: false) { model, scene in
            let start = model.world?.incidents.log.last?.started ?? 0
            var guardSteps = 0
            while !(model.world?.incidents.fires.isEmpty ?? true), guardSteps < 120 {
                model.advanceSimulation(ticks: 30)
                guardSteps += 1
            }
            model.refreshSimulationSummary()
            let minutes = ((model.world?.clock.tick ?? 0) - start) / 60
            if let world = model.world, let property = model.activePropertyID, let b = world.buildings(on: property).first,
               let room = world.rooms(in: b.id).first(where: { $0.definitionID == "fire-control-room" }) {
                scene.withController { $0.jump(center: world.grid.rect(columns: room.columns, floors: room.floors).center + Vec2(0, 1), zoom: 30) }
            }
            return "\(model.clockText): sprinklers put the fire out in about \(minutes) min — \(model.incidents.recent.first?.detail ?? "")"
        },
        Step(name: "08-storm-damage", grid: false) { model, scene in
            var days = 0
            let before = model.world?.incidents.log.count ?? 0
            while (model.world?.incidents.log.count ?? 0) == before, days < 6 {
                ScreenshotDirector.force("storm", 12, model: model)
                model.advanceSimulation(ticks: 3 * 3600)
                days += 1
            }
            model.showIncidentsPanel = true
            model.refreshSimulationSummary()
            scene.withController { $0.jump(center: Vec2(22, 16), zoom: 11.5) }
            return "\(model.clockText) (storm set): \(model.incidentNotice ?? "no incident yet")"
        },
        Step(name: "09-save-load", grid: false) { model, scene in
            model.showIncidentsPanel = false
            let office = ScreenshotDirector.office(model, index: 7)
            _ = office.map { model.igniteForTesting($0.id) }
            model.advanceSimulation(ticks: 300)
            let before = model.world
            let saved = model.save(slot: "capture-roundtrip", title: "Capture round trip")
            let loaded = model.load(slot: "capture-roundtrip")
            model.refreshSimulationSummary()
            return "Saved and reloaded during a fire: saved=\(saved) loaded=\(loaded) worldIdentical=\(before != nil && before == model.world), fires \(model.world?.incidents.fires.count ?? 0)"
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
