#if DEBUG
import Foundation
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// Capture helpers for Phase E: unit rents, staff rooms, taxes, waste, energy, breakdowns.
extension ScreenshotDirector {
    static func firstCar(_ model: AppModel) -> ElevatorCar? {
        model.world?.elevators.values.sorted { $0.id < $1.id }.first
    }

    /// Script step: wears the first car out, then runs the simulation in half-minute steps
    /// until it breaks down (at most two hours). Returns whether it did.
    static func breakFirstCar(_ model: AppModel) -> Bool {
        guard let car = firstCar(model) else { return false }
        model.world?.upkeep.update(car.id) { $0.condition = 0.02 }
        for _ in 0..<240 {
            model.advanceSimulation(ticks: 30)
            if model.world?.elevators[car.id]?.isOutOfService == true { return true }
        }
        return false
    }

    /// Runs until the first car is back in service (at most two hours).
    static func waitForRepair(_ model: AppModel) -> Bool {
        guard let car = firstCar(model) else { return false }
        for _ in 0..<240 {
            if model.world?.elevators[car.id]?.isOutOfService != true { return true }
            model.advanceSimulation(ticks: 30)
        }
        return false
    }

    /// "Taxes −$…, waste −$…, energy 1.04×" from the last closing.
    static func closingNote(_ model: AppModel) -> String {
        guard let world = model.world else { return "" }
        let day = world.ledger.totals(onDay: SimClock.day(world.clock.tick))
        let e = model.economy
        return "Last closing: taxes \(Money.format(day.amount(.taxes))), waste \(Money.format(day.amount(.waste))), "
            + "utilities \(Money.format(day.amount(.utilities))); energy price \(String(format: "%.2f", e.energyPrice))×."
    }

    /// "Staff 4 of 4 places; waste 170 of 320 kg".
    static func staffNote(_ model: AppModel) -> String {
        let s = model.facilities
        return "Staff \(s.staffCount) of \(s.staffCapacity.map(String.init) ?? "∞") places; waste \(Int(s.wastePerDay)) of \(Int(s.wasteCapacity)) kg a day."
    }
}
#endif
