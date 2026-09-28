import Foundation

public enum TenantTag {}
public typealias TenantID = EntityID<TenantTag>

/// A household or business renting one unit (room) — Phase 8. Its members are `Person`s
/// with `tenantID` set. What kind of tenant it is (size, schedules, preferences) comes from
/// content (`tenants.json`, `typeID`).
public struct Tenant: Codable, Hashable, Sendable, Identifiable {
    public let id: TenantID
    public var typeID: String
    public var name: String
    public var buildingID: BuildingID
    public var room: RoomID
    /// Monthly rent agreed at signing (not charged until the economy, Phase 9); for an
    /// owner, the monthly service charges.
    public var rent: Int
    /// Bought the unit (0.20.3; nil = renter): the price paid, if bought from the player
    /// (0 for a resale between private parties).
    public var purchasePrice: Int?
    public var since: Tick
    /// 0…1, updated daily from the unit's current qualities (rent, access, noise, view).
    public var satisfaction: Double
    /// Consecutive daily reviews below the type's threshold; at 3 the tenant moves out
    /// (owners hold on longer, `EconomyRules.ownerPatience`).
    public var unhappyDays: Int
    /// Amenity operators only (0.22): customers and takings since the last daily closing.
    public var sales: AmenitySales?

    public var isOwner: Bool { purchasePrice != nil }

    public init(id: TenantID, typeID: String, name: String, buildingID: BuildingID, room: RoomID, rent: Int,
                since: Tick, satisfaction: Double) {
        self.id = id
        self.typeID = typeID
        self.name = name
        self.buildingID = buildingID
        self.room = room
        self.rent = rent
        self.since = since
        self.satisfaction = satisfaction
        self.unhappyDays = 0
    }
}

/// What an amenity took (0.22): customers and money since the last daily closing, and
/// the totals of the previous day (for the UI).
public struct AmenitySales: Codable, Hashable, Sendable {
    public var visits = 0
    /// Of `visits`, how many came from the street (not living or working in the building).
    public var streetVisits = 0
    public var takings = 0
    public var lastVisits = 0
    public var lastStreetVisits = 0
    public var lastTakings = 0

    public init() {}

    public mutating func record(takings amount: Int, fromStreet: Bool) {
        visits += 1
        if fromStreet { streetVisits += 1 }
        takings += amount
    }

    /// Closes the day: today's totals become yesterday's.
    public mutating func closeDay() {
        lastVisits = visits
        lastStreetVisits = streetVisits
        lastTakings = takings
        visits = 0
        streetVisits = 0
        takings = 0
    }
}

/// Why a prospective tenant did not sign (their weakest criterion).
public enum DeclineReason: String, Codable, CaseIterable, Hashable, Sendable {
    case noVacancy, tooExpensive, poorAccess, tooNoisy, poorView, poorServices
}

/// One entry of the leasing log (kept short, for the UI).
public struct LeasingEvent: Codable, Hashable, Sendable {
    public enum Outcome: String, Codable, Hashable, Sendable { case signed, declined, movedOut }
    public var tick: Tick
    public var typeID: String
    public var outcome: Outcome
    public var room: RoomID?
    public var reason: DeclineReason?
    public var score: Double

    public init(tick: Tick, typeID: String, outcome: Outcome, room: RoomID?, reason: DeclineReason?, score: Double) {
        self.tick = tick
        self.typeID = typeID
        self.outcome = outcome
        self.room = room
        self.reason = reason
        self.score = score
    }
}

/// Rental market state of the world (saved): when it next runs and what happened.
public struct MarketState: Codable, Hashable, Sendable {
    /// Tick of the next hourly market step.
    public var nextTick: Tick = 3600
    public var prospects = 0
    public var signed = 0
    public var movedOut = 0
    /// Declines per reason, in `DeclineReason.allCases` order.
    public var declined: [Int] = Array(repeating: 0, count: DeclineReason.allCases.count)
    /// Most recent events, newest last (at most `logLimit`).
    public var log: [LeasingEvent] = []

    public static let logLimit = 40

    public init() {}

    public mutating func record(_ event: LeasingEvent) {
        log.append(event)
        if log.count > Self.logLimit { log.removeFirst(log.count - Self.logLimit) }
    }

    public func declines(_ reason: DeclineReason) -> Int {
        declined[DeclineReason.allCases.firstIndex(of: reason)!]
    }

    public mutating func countDecline(_ reason: DeclineReason) {
        declined[DeclineReason.allCases.firstIndex(of: reason)!] += 1
    }
}
