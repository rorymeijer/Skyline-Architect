import Foundation
import SkylineCore
import SkylinePresentation

extension AppModel {
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
