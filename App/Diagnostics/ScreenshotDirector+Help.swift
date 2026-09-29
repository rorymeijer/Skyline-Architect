#if DEBUG
import Foundation
import SkylineCore

/// Capture helpers for the tutorial (F3): the first tutorial steps built through the
/// player's own command path (`AppModel.perform`, with costs and undo).
extension ScreenshotDirector {
    /// Floors B1–2, lobby, stairwell, plant, two offices, an elevator and two flats on the
    /// tutorial's lot. Returns how many commands were refused.
    static func buildTutorialSteps(_ model: AppModel) -> Int {
        guard let world = model.world, let property = model.activePropertyID,
              let b = world.buildings(on: property).first else { return -1 }
        let s = b.footprint.start, span = b.footprint
        func room(_ def: String, _ start: Int, _ width: Int, _ lo: Int, _ hi: Int? = nil) -> BuildCommand {
            .placeRoom(building: b.id, definition: def, columns: ColumnSpan(start: s + start, count: width),
                       floors: FloorSpan(lowest: lo, highest: hi ?? lo))
        }
        var refused = 0
        func run(_ commands: [BuildCommand]) { for c in commands where !model.perform(c) { refused += 1; model.alert = nil } }
        run([.buildFloor(building: b.id, level: -1, span: span), .buildFloor(building: b.id, level: 0, span: span),
             room("lobby", 7, 25, 0), room("stairs", 0, 4, -1, 0),
             room("mechanical", 7, 4, -1), room("electrical-room", 11, 4, -1), room("telecom-room", 15, 3, -1),
             .buildFloor(building: b.id, level: 1, span: span), room("office-small", 7, 8, 1), room("office-small", 15, 8, 1),
             .buildFloor(building: b.id, level: 2, span: span)])
        if let stairs = model.world?.rooms.values.first(where: { $0.definitionID == "stairs" })?.id {
            run([.resizeRoom(stairs, floors: FloorSpan(lowest: -1, highest: 2))])
        }
        run([room("elevator-shaft", 4, 3, -1, 2), room("apartment-studio", 7, 8, 2), room("apartment-studio", 15, 8, 2)])
        return refused
    }

    static func tutorialNote(_ model: AppModel) -> String {
        guard let t = model.tutorial else { return "no tutorial" }
        return "tutorial \(t.progress.completed) of \(t.steps.count) done, current step: \(t.current?.title ?? "none")"
    }
}
#endif
