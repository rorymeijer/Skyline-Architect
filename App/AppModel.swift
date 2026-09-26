import Foundation
import Observation
import SkylineCore
import SkylineContent
import SkylinePresentation

/// App-level state: the authoritative game model, view settings and the renderer for the
/// active property. Views read it; the renderer derives everything it draws from `world`.
@Observable
final class AppModel {
    private(set) var world: GameWorld?
    private(set) var activePropertyID: PropertyID?
    private(set) var loadError: String?

    private(set) var showGrid = true
    var showDeveloperHUD: Bool
    private(set) var diagnostics = RenderDiagnostics()

    @ObservationIgnored private(set) var scene: WorldScene?
    @ObservationIgnored private var screenshotDirector: AnyObject?

    init(arguments: [String] = CommandLine.arguments) {
        #if DEBUG
        showDeveloperHUD = true
        #else
        showDeveloperHUD = false
        #endif
        do {
            let library = try ContentLibrary.loadBase()
            let game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: library)
            world = game.world
            activePropertyID = game.activePropertyID
            guard let composition = SiteComposer.compose(world: game.world, propertyID: game.activePropertyID) else {
                loadError = "The starting property could not be composed."
                return
            }
            let scene = WorldScene(composition: composition)
            scene.onDiagnostics = { [weak self] d in self?.diagnostics = d }
            self.scene = scene
        } catch {
            loadError = "\(error)"
        }
        #if DEBUG
        if let config = ScreenshotDirector.Configuration(arguments: arguments), let scene {
            showDeveloperHUD = true
            let director = ScreenshotDirector(configuration: config, scene: scene, model: self)
            screenshotDirector = director
            scene.onReady = { [weak director] in director?.start() }
        }
        #endif
    }

    var activeProperty: Property? { activePropertyID.flatMap { world?.properties[$0] } }
    var activeCity: City? { activeProperty.flatMap { world?.cities[$0.cityID] } }

    // MARK: View commands

    func zoom(by factor: Double) {
        guard let scene else { return }
        let center = scene.controller.camera.viewportSize / 2
        scene.withController { $0.zoom(by: factor, at: center, animated: true) }
    }

    func apply(_ preset: CameraPreset) { scene?.apply(preset: preset) }

    func toggleGrid() { setGrid(!showGrid) }

    func setGrid(_ visible: Bool) {
        showGrid = visible
        scene?.showGrid = visible
    }
}
