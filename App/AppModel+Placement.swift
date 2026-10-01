import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

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
    /// Every press changes the ghost, also when a room was held at its minimum width (0.30.1).
    func nudgeHeldPlacement(by step: Int) {
        guard let scene, let tool = activeTool, let world, let property = activePropertyID, let engine,
              let held = scene.heldCells else { return }
        scene.holdPlacement(end: PlacementPlanner.nudgedVisibly(held.end, anchor: held.anchor, tool: tool, world: world,
                                                                propertyID: property, engine: engine, by: step))
    }

    /// How the bar shapes the held placement (0.30.4): rooms and floors sideways, new shafts
    /// vertically. Nil for demolish, and when an existing shaft's end is being dragged (its
    /// resize keeps Taller / Lower).
    var heldEditAxis: PlacementPlanner.EditAxis? {
        guard let tool = activeTool, let catalog else { return nil }
        if case .resizeRoom? = heldPlacement?.command { return nil }
        if case .batch(let steps)? = heldPlacement?.command, steps.contains(where: { if case .resizeRoom = $0 { true } else { false } }) {
            return nil
        }
        return PlacementPlanner.editAxis(tool, catalog: catalog)
    }

    /// The held placement after `edit`, if that edit is possible (within the room's widths).
    private func heldAfter(_ edit: HeldEdit) -> (anchor: GridCell, end: GridCell)? {
        guard let scene, let tool = activeTool, let catalog, let held = scene.heldCells else { return nil }
        return PlacementPlanner.edited(edit, anchor: held.anchor, end: held.end, tool: tool, catalog: catalog)
    }

    func canEditHeldPlacement(_ edit: HeldEdit) -> Bool { heldAfter(edit) != nil }

    /// One step of an edge or of the whole ghost (the touch bar's arrows, 0.30.4).
    func editHeldPlacement(_ edit: HeldEdit) {
        guard let next = heldAfter(edit) else { return }
        scene?.holdPlacement(anchor: next.anchor, end: next.end)
    }

    /// "Wider" or "Taller" for the ± buttons of the active tool.
    var heldGrowsVertically: Bool {
        if case .room(let id)? = activeTool { return catalog?.spec(id)?.kind == .shaft }
        return false
    }

    // MARK: The picked tool (0.30.3)

    /// Name, size and price of the active tool, for the bar above the palette.
    var toolSummary: ToolSummary? {
        guard let tool = activeTool, let world, let property = activePropertyID, let catalog else { return nil }
        var detail: String?
        if case .room(let id) = tool { detail = simulation?.rules.elevator(for: id)?.name }
        return ToolSummary.make(tool: tool, world: world, propertyID: property, catalog: catalog, detail: detail)
    }

    /// The palette's icon for the active tool.
    var toolSymbol: String {
        switch activeTool {
        case .room(let id)?: catalog?.spec(id).map(BuildPalette.symbol(for:)) ?? "square.dashed"
        case .demolish?: "hammer"
        default: "square.stack.3d.up"
        }
    }

    /// Why the active room type cannot be placed yet, if so.
    var activeToolLock: String? {
        if case .room(let id)? = activeTool { return lockReason(of: id) }
        return nil
    }
}
