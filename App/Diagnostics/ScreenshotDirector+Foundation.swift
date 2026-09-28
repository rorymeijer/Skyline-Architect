#if DEBUG
import Foundation
import SkylineCore

/// Capture helpers for foundations (0.21).
extension ScreenshotDirector {
    /// Presses foundation-panel buttons by id, in order (each one undoable step).
    static func press(_ ids: [String], model: AppModel) {
        for id in ids {
            model.refreshSimulationSummary()
            if let command = model.foundation?.options.first(where: { $0.id == id })?.command { model.perform(command) }
        }
        model.refreshSimulationSummary()
    }

    /// "52 m wide · 2 of 3 basements · piles 30 m · carries 60 storeys; buttons: …".
    static func foundationNote(_ model: AppModel) -> String {
        guard let f = model.foundation else { return "no foundation panel" }
        let buttons = f.options.map { "\($0.title): \($0.detail)" }.joined(separator: "; ")
        return "\(f.widthMeters) m wide · \(f.basements) of \(f.maxBasements) basements · piles \(f.pileDepth) m · carries \(f.carries.map(String.init) ?? "any number of") storeys. \(buttons)."
    }
}
#endif
