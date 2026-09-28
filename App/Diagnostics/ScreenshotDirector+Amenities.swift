#if DEBUG
import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// Capture helpers for amenities and visitors (0.22).
extension ScreenshotDirector {
    static func amenityRoom(_ model: AppModel, _ definition: String) -> Room? {
        model.world?.rooms.values.first { $0.definitionID == definition }
    }

    /// "14 occupants and 23 visitors at amenities; takings today $2,310".
    static func amenityNote(_ model: AppModel) -> String {
        guard let world = model.world, let rules = model.simulation?.rules else { return "" }
        var occupants = 0, visitors = 0
        for p in world.people {
            guard case let .room(r, _) = p.place, let room = world.rooms[r], rules.amenity(for: room.definitionID) != nil else { continue }
            if p.role == .visitor { visitors += 1 } else if r != p.anchorRoom { occupants += 1 }
        }
        let takings = world.tenants.values.reduce(0) { $0 + ($1.sales?.takings ?? 0) }
        return "\(occupants) workers and residents and \(visitors) street visitors at amenities; takings today \(Money.format(takings))."
    }
}
#endif
