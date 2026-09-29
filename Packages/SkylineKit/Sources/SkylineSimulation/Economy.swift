import Foundation
import SkylineCore

/// The money side of the simulation (Phase 9): daily closing (rent in; maintenance,
/// utilities and interest out; bankruptcy check), loans and the rent level. Every change is
/// a `Transaction` in the world's ledger, attributed to its tenant or building.
public enum Economy {
    /// Borrows one loan step if the limit allows. Returns whether it did.
    @discardableResult
    public static func borrow(_ world: inout GameWorld, rules: EconomyRules) -> Bool {
        guard canBorrow(world, rules: rules) else { return false }
        world.ledger.loans += rules.loanStep
        world.ledger.post(Transaction(tick: world.clock.tick, amount: rules.loanStep, category: .loan, detail: "Loan taken"))
        return true
    }

    /// Whether one more loan step fits the limit (and the scenario's, Phase C).
    public static func canBorrow(_ world: GameWorld, rules: EconomyRules) -> Bool {
        let total = world.ledger.loans + rules.loanStep
        return total <= rules.maxLoans && total <= (world.restrictions?.maxLoans ?? .max)
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
    /// Returns false when the scenario fixes rents (Phase C).
    @discardableResult
    public static func setRentLevel(_ level: Double, building: BuildingID, in world: inout GameWorld) -> Bool {
        guard world.restrictions?.rentIsFixed != true else { return false }
        world.setRentLevel(level, building: building)
        return true
    }

    public static let rentLevels = 0.6...1.6

    /// Player rent setting of one rentable unit (Phase E), on top of the building's level:
    /// 0.6…1.6 in steps of 10 %. Like the building level it applies to new leases and to
    /// appraisal; signed rents are contracts. Returns false for a room that is not a unit.
    @discardableResult
    public static func setRentFactor(_ factor: Double, room: RoomID, in world: inout GameWorld, catalog: BuildCatalog) -> Bool {
        guard let r = world.rooms[room], catalog.spec(r.definitionID)?.rentPerModule != nil,
              world.restrictions?.rentIsFixed != true else { return false }
        world.setRentFactor(factor, room: room)
        return true
    }
}

extension SimulationEngine {
    /// Daily closing at 06:00 (part of the market event): rent from every tenant, then per
    /// building maintenance, utilities and property tax, then loan interest and the profit
    /// tax on the closing's result (`before`: the day's totals when the closing began, so
    /// wages count); then the bankruptcy check.
    func closeDay(at now: Tick, since before: DayTotals, world: inout GameWorld) {
        guard let economy = rules.economy, !world.ledger.bankrupt else { return }
        for tenant in world.tenants.values {
            let daily = tenant.rent / economy.rentDaysPerMonth
            guard daily > 0 else { continue }
            world.ledger.post(Transaction(tick: now, amount: daily, category: .rent,
                                          detail: (tenant.isOwner ? "Service charges — " : "Rent — ") + tenant.name,
                                          building: tenant.buildingID, room: tenant.room, tenant: tenant.id))
        }
        postTurnover(at: now, world: &world)
        collectWaste(at: now, world: &world)
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
            // Heating and cooling (Phase 13): the bill grows with the distance from comfort.
            let city = world.city(of: building.id)
            let energy = energyPrice(city)
            let climate = energyFactor(city) * energy
            let utilities = Int((Double(people * economy.utilitiesPerPersonPerDay + cars * economy.elevatorCarPerDay) * climate).rounded())
            if utilities > 0 {
                let weather = city?.weather.map { String(format: ", %.0f °C ×%.2f", $0.temperature, climate) } ?? ""
                world.ledger.post(Transaction(tick: now, amount: -utilities, category: .utilities,
                                              detail: "Utilities — \(people) people, \(cars) elevator cars\(weather), \(building.name)",
                                              building: building.id))
            }
            let kWh = world.buildings[building.id]?.lightingKWh ?? 0
            let lighting = Int((kWh * (economy.lightingPricePerKWh ?? 0) * energy).rounded())
            if lighting > 0 {
                world.ledger.post(Transaction(tick: now, amount: -lighting, category: .utilities,
                                              detail: "Lighting — \(Int(kWh.rounded())) kWh, \(building.name)", building: building.id))
            }
            world.setLightingEnergy(0, building: building.id)
            let tax = Taxes.propertyTax(building, world: world, catalog: catalog, rules: economy)
            if tax > 0 {
                world.ledger.post(Transaction(tick: now, amount: -tax, category: .taxes,
                                              detail: "Property tax — \(building.name)", building: building.id))
            }
        }
        let interest = Int((Double(world.ledger.loans) * economy.loanInterestRate / 365).rounded())
        if interest > 0 {
            world.ledger.post(Transaction(tick: now, amount: -interest, category: .interest, detail: "Loan interest"))
        }
        postProfitTax(since: before, at: now, world: &world)
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
    /// The building's city: today's energy price and its tax level (Phase E).
    public var energyPrice = 1.0
    public var taxLevel = 1.0
    /// The scenario fixes rents (Phase C).
    public var rentFixed = false
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
            s.canBorrow = Economy.canBorrow(world, rules: e)
            s.canRepay = ledger.loans > 0 && ledger.cash >= min(e.loanStep, ledger.loans)
            s.bankruptcyDays = e.bankruptcyDays
        }
        let today = SimClock.day(world.clock.tick)
        s.lastDay = ledger.days.last(where: { $0.day == today }) ?? DayTotals(day: today)
        s.week = ledger.totals(lastDays: 7)
        s.rentLevel = building.flatMap { world.buildings[$0]?.rentLevel } ?? 1
        s.rentFixed = world.restrictions?.rentIsFixed == true
        if let city = building.flatMap({ world.city(of: $0) }) {
            s.energyPrice = city.energyPrice ?? city.economy.energy ?? 1
            s.taxLevel = city.economy.tax ?? 1
        }
        s.negativeDays = ledger.negativeDays
        s.bankrupt = ledger.bankrupt
        s.recent = ledger.journal.suffix(limit).reversed()
        return s
    }
}
