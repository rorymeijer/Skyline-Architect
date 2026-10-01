import Foundation
import SkylineCore
import SkylineSimulation

extension AppModel {
    // MARK: Progression (Phase 11)

    /// Refreshes class and reputation; a promotion since the last refresh (of this game)
    /// raises a notice listing what it unlocked.
    func refreshProgression() {
        guard let world, let simulation else { return }
        let building = activePropertyID.flatMap { world.buildings(on: $0).first?.id }
        let summary = ProgressionSummary.make(world: world, engine: simulation, building: building,
                                              service: building.flatMap { utilityServices[$0] })
        if let seen = seenPromotions, summary.promotions.count > seen {
            let unlocked = progression.nextUnlocks
            promotionNotice = "\(propertyName) is now \(summary.className)"
                + (summary.byClass && !unlocked.isEmpty ? " — unlocked: " + unlocked.joined(separator: ", ") : "")
        }
        seenPromotions = summary.promotions.count
        progression = summary
    }

    /// The class that unlocks a room type, if it is still locked in this game.
    func lockedClass(of definition: String) -> String? { progression.lockedRooms[definition] }

    /// Why a room tool is unavailable: the scenario forbids it (Phase C), or the building
    /// class does not allow it yet. nil = available.
    func lockReason(of definition: String) -> String? {
        if world?.restrictions?.forbids(definition) == true { return "not allowed in this scenario" }
        return lockedClass(of: definition).map { "unlocks at \($0)" + Self.standingShortcut }
    }

    /// The Standing panel's shortcut after a lock reason; touch devices have no keyboard (0.30.3).
    #if os(macOS)
    static let standingShortcut = " (⌥⌘P)"
    #else
    static let standingShortcut = ""
    #endif
}
