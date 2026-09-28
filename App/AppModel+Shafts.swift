import Foundation
import SkylineCore
import SkylinePresentation

/// One height control of a selected shaft: the command it would perform (nil = not
/// possible now) and its price or the reason why not.
struct ConstructionOption: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String
    let command: BuildCommand?
    let detail: String
}

extension AppModel {
    // MARK: Shaft height (0.20.2)

    /// Extend or shorten the selected shaft by one floor at the top or the bottom. The same
    /// `resizeRoom` command as dragging a shaft's end with its tool; validated here, not in
    /// the view.
    func refreshShaftOptions() {
        guard let world, let engine, let id = selectedRoom, let room = world.rooms[id],
              engine.catalog.spec(room.definitionID)?.kind == .shaft else {
            if !shaftOptions.isEmpty { shaftOptions = [] }
            return
        }
        let f = room.floors
        let steps: [(String, String, String, FloorSpan)] = [
            ("up", "Extend Up", "arrow.up.to.line", FloorSpan(lowest: f.lowest, highest: f.highest + 1)),
            ("top", "Shorten Top", "arrow.down.to.line", FloorSpan(lowest: f.lowest, highest: f.highest - 1)),
            ("down", "Extend Down", "arrow.down.to.line.compact", FloorSpan(lowest: f.lowest - 1, highest: f.highest)),
            ("bottom", "Shorten Bottom", "arrow.up.to.line.compact", FloorSpan(lowest: f.lowest + 1, highest: f.highest)),
        ]
        let options = steps.map { key, title, symbol, floors -> ConstructionOption in
            guard floors.lowest <= floors.highest else {
                return ConstructionOption(id: key, title: title, symbol: symbol, command: nil, detail: "Too short already")
            }
            let command = BuildCommand.resizeRoom(id, floors: floors)
            switch engine.validate(command, in: world) {
            case .success(let plan):
                let price = plan.cost < 0 ? "refund \(Money.format(-plan.cost))" : Money.format(plan.cost)
                guard plan.cost <= world.ledger.cash else {
                    return ConstructionOption(id: key, title: title, symbol: symbol, command: nil, detail: "Not enough money (\(price))")
                }
                return ConstructionOption(id: key, title: title, symbol: symbol, command: command, detail: price)
            case .failure(let error):
                return ConstructionOption(id: key, title: title, symbol: symbol, command: nil, detail: "\(error)")
            }
        }
        if options != shaftOptions { shaftOptions = options }
    }
}
