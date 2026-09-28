import Foundation

/// What a transaction is for (Phase 9). Positive amounts are income, negative expenses.
public enum LedgerCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case construction, demolition, rent, maintenance, utilities, loan, interest, grant, wages, land
}

/// One traceable money movement: when, how much, why and for whom.
public struct Transaction: Codable, Hashable, Sendable {
    public var tick: Tick
    /// Signed amount in whole currency units (+ income, − expense).
    public var amount: Int
    public var category: LedgerCategory
    /// Human-readable reason ("Rent — Meridian Labs", "Place Small Office, floor 3").
    public var detail: String
    public var building: BuildingID?
    public var room: RoomID?
    public var tenant: TenantID?

    public init(tick: Tick, amount: Int, category: LedgerCategory, detail: String,
                building: BuildingID? = nil, room: RoomID? = nil, tenant: TenantID? = nil) {
        self.tick = tick
        self.amount = amount
        self.category = category
        self.detail = detail
        self.building = building
        self.room = room
        self.tenant = tenant
    }
}

/// Totals per category for one game day.
public struct DayTotals: Codable, Hashable, Sendable {
    public var day: Tick
    /// Signed sums per category, in `LedgerCategory.allCases` order.
    public var amounts: [Int]

    public init(day: Tick) {
        self.day = day
        amounts = Array(repeating: 0, count: LedgerCategory.allCases.count)
    }

    public func amount(_ c: LedgerCategory) -> Int { amounts[LedgerCategory.allCases.firstIndex(of: c)!] }
    public var income: Int { amounts.filter { $0 > 0 }.reduce(0, +) }
    public var expenses: Int { amounts.filter { $0 < 0 }.reduce(0, +) }
}

/// The player's money (saved). Every change goes through `post`, so the cash balance always
/// equals the sum of all transactions since the start (the journal keeps the most recent
/// ones; daily totals the last 60 days).
public struct Ledger: Codable, Hashable, Sendable {
    public var cash: Int
    /// Outstanding loan principal.
    public var loans: Int = 0
    public var journal: [Transaction] = []
    public var days: [DayTotals] = []
    /// Consecutive daily closings with negative cash.
    public var negativeDays = 0
    public var bankrupt = false

    public static let journalLimit = 400
    public static let dayLimit = 60

    public init(cash: Int = 0) { self.cash = cash }

    public mutating func post(_ t: Transaction) {
        cash += t.amount
        journal.append(t)
        if journal.count > Self.journalLimit { journal.removeFirst(journal.count - Self.journalLimit) }
        let day = SimClock.day(t.tick)
        if days.last?.day != day {
            days.append(DayTotals(day: day))
            if days.count > Self.dayLimit { days.removeFirst(days.count - Self.dayLimit) }
        }
        days[days.count - 1].amounts[LedgerCategory.allCases.firstIndex(of: t.category)!] += t.amount
    }

    /// Totals over the last `n` days (including today).
    public func totals(lastDays n: Int) -> DayTotals {
        var sum = DayTotals(day: days.last?.day ?? 0)
        for d in days.suffix(n) { sum.amounts = zip(sum.amounts, d.amounts).map(+) }
        return sum
    }
}

public enum LedgerError: Error, Equatable, CustomStringConvertible {
    case insufficientFunds(needed: Int, available: Int)

    public var description: String {
        switch self {
        case let .insufficientFunds(needed, available): "Not enough money: needs \(needed), have \(available)"
        }
    }
}
