import Foundation
import SkylineCore

/// The money side of the simulation (Phase 9): daily closing (rent in; maintenance,
/// utilities and interest out; bankruptcy check), loans and the rent level. Every change is
/// a `Transaction` in the world's ledger, attributed to its tenant or building.
public enum Economy {
    /// Borrows one loan step if the limit allows. Returns whether it did.
    @discardableResult
    public static func borrow(_ world: inout GameWorld, rules: EconomyRules) -> Bool {
        guard world.ledger.loans + rules.loanStep <= rules.maxLoans else { return false }
        world.ledger.loans += rules.loanStep
        world.ledger.post(Transaction(tick: world.clock.tick, amount: rules.loanStep, category: .loan, detail: "Loan taken"))
        return true
    }

    /// Repays one loan step if there is cash and debt. Returns whether it did.
    @discardableResult
    public static func repay(_ world: inout GameWorld, rules: EconomyRules) -> Bool {
        let amount = min(rules.loanStep, world.ledger.loans)
        guard amount > 0, world.ledger.cash >= amount else { return false }
        world.ledger.loans -= amount
        world.ledger.post(Transaction(tick: world.clock.tick, amount: -amount, category: .loan, detail: "Loan repaid"))
        return true
    }

    /// Player rent setting per building (0.6…1.6). Applies to new leases and to how
    /// prospects and tenants appraise units; signed rents are contracts and do not change.
    public static func setRentLevel(_ level: Double, building: BuildingID, in world: inout GameWorld) {
        world.setRentLevel(level, building: building)
    }

    public static let rentLevels = 0.6...1.6
}

extension SimulationEngine {
    /// Daily closing at 06:00 (part of the market event): rent from every tenant, then per
    /// building maintenance and utilities, then loan interest; then the bankruptcy check.
    func closeDay(at now: Tick, world: inout GameWorld) {
        guard let economy = rules.economy, !world.ledger.bankrupt else { return }
        for tenant in world.tenants.values {
            let daily = tenant.rent / economy.rentDaysPerMonth
            guard daily > 0 else { continue }
            world.ledger.post(Transaction(tick: now, amount: daily, category: .rent, detail: "Rent — \(tenant.name)",
                                          building: tenant.buildingID, room: tenant.room, tenant: tenant.id))
        }
        for building in world.buildings.values {
            let rooms = world.rooms(in: building.id)
            let upkeep = rooms.reduce(0) { sum, room in
                sum + (catalog.spec(room.definitionID)?.maintenancePerModulePerDay ?? 0) * room.columns.count * room.floors.count
            }
            if upkeep > 0 {
                world.ledger.post(Transaction(tick: now, amount: -upkeep, category: .maintenance,
                                              detail: "Maintenance — \(rooms.count) spaces, \(building.name)", building: building.id))
            }
            let people = world.people.values.filter { $0.buildingID == building.id }.count
            let cars = world.elevators.values.filter { $0.buildingID == building.id }.count
            let utilities = people * economy.utilitiesPerPersonPerDay + cars * economy.elevatorCarPerDay
            if utilities > 0 {
                world.ledger.post(Transaction(tick: now, amount: -utilities, category: .utilities,
                                              detail: "Utilities — \(people) people, \(cars) elevator cars, \(building.name)",
                                              building: building.id))
            }
            let kWh = world.buildings[building.id]?.lightingKWh ?? 0
            let lighting = Int((kWh * (economy.lightingPricePerKWh ?? 0)).rounded())
            if lighting > 0 {
                world.ledger.post(Transaction(tick: now, amount: -lighting, category: .utilities,
                                              detail: "Lighting — \(Int(kWh.rounded())) kWh, \(building.name)", building: building.id))
            }
            world.setLightingEnergy(0, building: building.id)
        }
        let interest = Int((Double(world.ledger.loans) * economy.loanInterestRate / 365).rounded())
        if interest > 0 {
            world.ledger.post(Transaction(tick: now, amount: -interest, category: .interest, detail: "Loan interest"))
        }
        world.ledger.negativeDays = world.ledger.cash < 0 ? world.ledger.negativeDays + 1 : 0
        if world.ledger.negativeDays >= economy.bankruptcyDays { world.ledger.bankrupt = true }
    }
}

/// What the economy panel shows (Phase 9). Pure data.
public struct EconomySummary: Equatable, Sendable {
    public var cash = 0
    public var loans = 0
    public var canBorrow = false
    public var canRepay = false
    public var loanStep = 0
    /// The last completed daily closing and the last 7 days.
    public var lastDay = DayTotals(day: 0)
    public var week = DayTotals(day: 0)
    public var rentLevel = 1.0
    public var negativeDays = 0
    public var bankruptcyDays = 7
    public var bankrupt = false
    /// Latest transactions, newest first ("D3 06:00  +1,234  Rent — Meridian Labs").
    public var recent: [Transaction] = []

    public init() {}

    public static func make(world: GameWorld, rules: SimulationRules, building: BuildingID?, recent limit: Int = 10) -> EconomySummary {
        var s = EconomySummary()
        let ledger = world.ledger
        s.cash = ledger.cash
        s.loans = ledger.loans
        if let e = rules.economy {
            s.loanStep = e.loanStep
            s.canBorrow = ledger.loans + e.loanStep <= e.maxLoans
            s.canRepay = ledger.loans > 0 && ledger.cash >= min(e.loanStep, ledger.loans)
            s.bankruptcyDays = e.bankruptcyDays
        }
        let today = SimClock.day(world.clock.tick)
        s.lastDay = ledger.days.last(where: { $0.day == today }) ?? DayTotals(day: today)
        s.week = ledger.totals(lastDays: 7)
        s.rentLevel = building.flatMap { world.buildings[$0]?.rentLevel } ?? 1
        s.negativeDays = ledger.negativeDays
        s.bankrupt = ledger.bankrupt
        s.recent = ledger.journal.suffix(limit).reversed()
        return s
    }
}
