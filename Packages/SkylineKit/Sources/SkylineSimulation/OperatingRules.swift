import Foundation
import SkylineCore

/// Money rules (`economy.json`, Phase 9).
public struct EconomyRules: Codable, Hashable, Sendable {
    /// Loans are taken and repaid in steps of this amount, up to `maxLoans` outstanding.
    public var loanStep: Int
    public var maxLoans: Int
    /// Annual interest rate on outstanding loans (charged daily).
    public var loanInterestRate: Double
    /// Consecutive daily closings in the red that end the game.
    public var bankruptcyDays: Int
    public var utilitiesPerPersonPerDay: Int
    public var elevatorCarPerDay: Int
    /// Monthly rents are collected at each daily closing as rent / rentDaysPerMonth. The base
    /// content uses 1: time is compressed so that one game day bills one rent month.
    public var rentDaysPerMonth: Int
    /// Price of the lighting energy used in one game day, per kWh (Phase 12; nil = free).
    /// Like rent it is a month's worth per day (D-032).
    public var lightingPricePerKWh: Double?
    /// Selling flats (0.20.3). A flat sells for its asking rent × `saleMonths`; its owner
    /// then pays `serviceChargeShare` × the asking rent every month, and moves out only
    /// after `ownerPatience` bad reviews in a row (renters: 3). Defaults: 100, 0.25, 9.
    public var saleMonths: Double?
    public var serviceChargeShare: Double?
    public var ownerPatience: Int?
    /// Taxes (Phase E; nil = none). Property tax: this share of a building's assessed value
    /// (what it cost to build) per rent month — like rent, one game day — times the city's
    /// tax level. Profit tax: this share of the daily closing's positive result.
    public var propertyTaxRate: Double?
    public var profitTaxRate: Double?
    /// Waste collection per kg (Phase E; nil = free).
    public var wastePricePerKg: Double?
    /// Energy prices (Phase E): each morning a city's price moves by up to ± this share of
    /// its base level, and back toward the base by this fraction (nil = steady).
    public var energyVolatility: Double?
    public var energyReversion: Double?

    public var salePriceMonths: Double { saleMonths ?? 100 }
    public var serviceShare: Double { serviceChargeShare ?? 0.25 }
    public var ownerReviews: Int { ownerPatience ?? 9 }

    public init(loanStep: Int, maxLoans: Int, loanInterestRate: Double, bankruptcyDays: Int,
                utilitiesPerPersonPerDay: Int, elevatorCarPerDay: Int, rentDaysPerMonth: Int, lightingPricePerKWh: Double? = nil) {
        self.loanStep = loanStep
        self.maxLoans = maxLoans
        self.loanInterestRate = loanInterestRate
        self.bankruptcyDays = bankruptcyDays
        self.utilitiesPerPersonPerDay = utilitiesPerPersonPerDay
        self.elevatorCarPerDay = elevatorCarPerDay
        self.rentDaysPerMonth = rentDaysPerMonth
        self.lightingPricePerKWh = lightingPricePerKWh
    }

    public var problems: [String] {
        var p: [String] = []
        if loanStep <= 0 || maxLoans < loanStep { p.append("economy: loanStep must be positive and ≤ maxLoans") }
        if !(0...1).contains(loanInterestRate) { p.append("economy: loanInterestRate must be 0…1") }
        if bankruptcyDays < 1 { p.append("economy: bankruptcyDays must be ≥ 1") }
        if utilitiesPerPersonPerDay < 0 || elevatorCarPerDay < 0 { p.append("economy: daily costs must be ≥ 0") }
        if rentDaysPerMonth < 1 { p.append("economy: rentDaysPerMonth must be ≥ 1") }
        if (lightingPricePerKWh ?? 0) < 0 { p.append("economy: lightingPricePerKWh must be ≥ 0") }
        if (wastePricePerKg ?? 0) < 0 || !(0...0.5).contains(energyVolatility ?? 0) || !(0...1).contains(energyReversion ?? 0) {
            p.append("economy: wastePricePerKg ≥ 0, energyVolatility 0…0.5, energyReversion 0…1")
        }
        if !(0...0.1).contains(propertyTaxRate ?? 0) || !(0...0.9).contains(profitTaxRate ?? 0) {
            p.append("economy: propertyTaxRate must be 0…0.1 and profitTaxRate 0…0.9")
        }
        if salePriceMonths <= 0 || !(0...1).contains(serviceShare) || ownerReviews < 1 {
            p.append("economy: saleMonths > 0, serviceChargeShare 0…1, ownerPatience ≥ 1")
        }
        return p
    }
}

/// Utilities, upkeep and staff rules (`facilities.json`, Phase 10).
public struct FacilitiesRules: Codable, Hashable, Sendable {
    public struct Utility: Codable, Hashable, Sendable {
        public var id: String
        public var name: String
    }

    public var utilities: [Utility]
    public var janitorWagePerDay: Int
    public var technicianWagePerDay: Int
    /// Cleanliness lost per person belonging to a room, per day.
    public var dirtPerPersonPerDay: Double
    /// Cleanliness lost per day by shared rooms (lobbies, corridors).
    public var circulationDirtPerDay: Double
    /// Job thresholds: clean below, repair below (equipment earlier), equipment fails below.
    public var cleanBelow: Double
    public var repairBelow: Double
    public var equipmentRepairBelow: Double
    public var failureBelow: Double
    public var cleanMinutes: Int
    public var repairMinutes: Int
    /// Staff shift, "HH:MM".
    public var shiftStart: String
    public var shiftEnd: String
    /// Waste (Phase E; nil = none): kg per resident or worker and per amenity customer per
    /// day; waste beyond the waste rooms' capacity dirties the building by up to this much.
    public var wastePerPersonPerDay: Double?
    public var wastePerVisit: Double?
    public var overflowDirtPerDay: Double?
    /// Staff rooms (Phase E): a job farther than the staff room's range takes this much longer.
    public var outOfRangeFactor: Double?

    public init(utilities: [Utility], janitorWagePerDay: Int, technicianWagePerDay: Int, dirtPerPersonPerDay: Double,
                circulationDirtPerDay: Double, cleanBelow: Double, repairBelow: Double, equipmentRepairBelow: Double,
                failureBelow: Double, cleanMinutes: Int, repairMinutes: Int, shiftStart: String, shiftEnd: String) {
        self.utilities = utilities
        self.janitorWagePerDay = janitorWagePerDay
        self.technicianWagePerDay = technicianWagePerDay
        self.dirtPerPersonPerDay = dirtPerPersonPerDay
        self.circulationDirtPerDay = circulationDirtPerDay
        self.cleanBelow = cleanBelow
        self.repairBelow = repairBelow
        self.equipmentRepairBelow = equipmentRepairBelow
        self.failureBelow = failureBelow
        self.cleanMinutes = cleanMinutes
        self.repairMinutes = repairMinutes
        self.shiftStart = shiftStart
        self.shiftEnd = shiftEnd
    }

    var shift: (start: Tick, end: Tick)? {
        guard let a = Schedule.Event(at: shiftStart, jitterMinutes: 0, goal: .work).secondOfDay,
              let b = Schedule.Event(at: shiftEnd, jitterMinutes: 0, goal: .work).secondOfDay, a < b else { return nil }
        return (a, b)
    }

    public var problems: [String] {
        var p: [String] = []
        if utilities.isEmpty || Set(utilities.map(\.id)).count != utilities.count { p.append("facilities: utilities must be unique and not empty") }
        if janitorWagePerDay < 0 || technicianWagePerDay < 0 { p.append("facilities: wages must be ≥ 0") }
        for v in [dirtPerPersonPerDay, circulationDirtPerDay, cleanBelow, repairBelow, equipmentRepairBelow, failureBelow]
        where !(0...1).contains(v) { p.append("facilities: rates and thresholds must be 0…1") }
        if cleanMinutes < 1 || repairMinutes < 1 { p.append("facilities: job durations must be ≥ 1 minute") }
        if [wastePerPersonPerDay, wastePerVisit].contains(where: { ($0 ?? 0) < 0 }) || !(0...1).contains(overflowDirtPerDay ?? 0)
            || !(1...5).contains(outOfRangeFactor ?? 1) {
            p.append("facilities: waste ≥ 0, overflowDirtPerDay 0…1, outOfRangeFactor 1…5")
        }
        if shift == nil { p.append("facilities: shiftStart must be a time before shiftEnd") }
        return p
    }
}
