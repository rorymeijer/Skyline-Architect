#if DEBUG
import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// Capture helpers for flats for sale (0.20.3).
extension ScreenshotDirector {
    static func studios(_ model: AppModel) -> [Room] {
        (model.world?.rooms.values ?? []).filter { $0.definitionID == "apartment-studio" }.sorted { ($0.floors.lowest, $0.id) < ($1.floors.lowest, $1.id) }
    }

    /// Script step: every studio's tenant moves out, so the flats are vacant.
    static func emptyStudios(_ model: AppModel) {
        guard var world = model.world else { return }
        for s in studios(model) {
            if let t = world.tenants.values.first(where: { $0.room == s.id }) { Leasing.moveOut(t.id, world: &world) }
        }
        model.world = world
    }

    /// "4 of 7 studios sold for $… in total; 3 for sale".
    static func salesNote(_ model: AppModel) -> String {
        guard let world = model.world else { return "" }
        let s = studios(model)
        let sold = s.filter { $0.tenure == .owned }.count, forSale = s.filter { $0.tenure == .forSale }.count
        let total = world.ledger.journal.filter { $0.category == .sales }.reduce(0) { $0 + $1.amount }
        return "\(sold) of \(s.count) studios sold for \(Money.format(total)) in total; \(forSale) still for sale."
    }
}
#endif
