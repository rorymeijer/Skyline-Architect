import Foundation
import SkylineCore
import SkylinePresentation

extension AppModel {
    // MARK: Held placement on touch (0.30)

    /// Builds the held placement (the Place button).
    func confirmHeldPlacement() {
        scene?.confirmHeldPlacement()
    }

    func cancelHeldPlacement() {
        scene?.cancelPlacement()
    }

    /// One module longer (+1) or shorter (−1): wider for rooms and floors, taller for shafts.
    func nudgeHeldPlacement(by step: Int) {
        guard let scene, let tool = activeTool, let catalog, let held = scene.heldCells else { return }
        scene.holdPlacement(end: PlacementPlanner.nudged(held.end, anchor: held.anchor, tool: tool, catalog: catalog, by: step))
    }

    /// "Wider" or "Taller" for the ± buttons of the active tool.
    var heldGrowsVertically: Bool {
        if case .room(let id)? = activeTool { return catalog?.spec(id)?.kind == .shaft }
        return false
    }
}
