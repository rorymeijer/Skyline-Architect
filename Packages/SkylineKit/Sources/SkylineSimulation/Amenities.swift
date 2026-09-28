import Foundation
import SkylineCore

/// When people use an amenity: at midday instead of going out for lunch (workers), or in
/// their free time (residents' evenings).
public enum AmenityOccasion: String, Codable, Hashable, Sendable {
    case lunch, leisure
}

/// What an amenity room offers (`amenities.json`, 0.22): opening hours, seats, how long and
/// how much a customer stays and spends, how many people come from the street, and the
/// landlord's share of the takings. The operator is a tenant renting the room (`tenants.json`);
/// an amenity without one is closed.
public struct AmenitySpec: Codable, Hashable, Sendable {
    /// Room definition id.
    public var room: String
    /// "HH:MM". `closes` before `opens` means after midnight (a bar open 17:00–01:00).
    public var opens: String
    public var closes: String
    public var occasions: [AmenityOccasion]
    /// Customers at once per module of width.
    public var capacityPerModule: Double
    /// Typical stay of a street visitor (personal variation ±30 %).
    public var stayMinutes: Int
    /// Average spend per visit, before the city's price level.
    public var spendPerVisit: Int
    /// Share of the takings paid to the landlord at the daily closing (0…1), on top of the rent.
    public var turnoverShare: Double
    /// Street visitors per module of width per opening hour, before demand, busy hours and height.
    public var streetVisitorsPerModulePerHour: Double
    /// Hours of the day (0…23) with twice the street visitors (lunch, evening).
    public var busyHours: [Int]?
    /// Extra street visitors per storey above ground (a view draws people up: 0.02 = +2 %).
    public var heightBonusPerFloor: Double?
    /// How much more attractive the building's other units become while this kind of amenity
    /// is open in it (added to their appraisal; each kind counts once).
    public var appeal: Double?

    public init(room: String, opens: String, closes: String, occasions: [AmenityOccasion], capacityPerModule: Double,
                stayMinutes: Int, spendPerVisit: Int, turnoverShare: Double, streetVisitorsPerModulePerHour: Double,
                busyHours: [Int]? = nil, heightBonusPerFloor: Double? = nil, appeal: Double? = nil) {
        self.room = room
        self.opens = opens
        self.closes = closes
        self.occasions = occasions
        self.capacityPerModule = capacityPerModule
        self.stayMinutes = stayMinutes
        self.spendPerVisit = spendPerVisit
        self.turnoverShare = turnoverShare
        self.streetVisitorsPerModulePerHour = streetVisitorsPerModulePerHour
        self.busyHours = busyHours
        self.heightBonusPerFloor = heightBonusPerFloor
        self.appeal = appeal
    }

    /// Opening and closing time in seconds since midnight.
    public var hours: (opens: Tick, closes: Tick)? {
        guard let a = Schedule.Event(at: opens, jitterMinutes: 0, goal: .leisure).secondOfDay,
              let b = Schedule.Event(at: closes, jitterMinutes: 0, goal: .leisure).secondOfDay, a != b else { return nil }
        return (a, b)
    }

    /// Whether it is open at a time of day (seconds since midnight).
    public func isOpen(atSecondOfDay s: Tick) -> Bool {
        guard let h = hours else { return false }
        return h.opens < h.closes ? (h.opens..<h.closes).contains(s) : s >= h.opens || s < h.closes
    }

    /// Seconds from a time of day until closing (0 when closed).
    public func secondsUntilClosing(atSecondOfDay s: Tick) -> Tick {
        guard isOpen(atSecondOfDay: s), let h = hours else { return 0 }
        return h.closes > s ? h.closes - s : h.closes + SimClock.secondsPerDay - s
    }

    public func capacity(modules: Int) -> Int { max(1, Int((Double(modules) * capacityPerModule).rounded(.down))) }

    public func serves(_ occasion: AmenityOccasion) -> Bool { occasions.contains(occasion) }

    /// Validation problems against the known rooms (empty if valid).
    public func problems(rooms: [RoomSpec]) -> [String] {
        var p: [String] = []
        let name = "amenity '\(room)'"
        if let spec = rooms.first(where: { $0.id == room }) {
            if spec.kind != .room || spec.rentPerModule == nil { p.append("\(name): needs a rentable room (with rentPerModule)") }
        } else {
            p.append("\(name): unknown room")
        }
        if hours == nil { p.append("\(name): opens and closes must be different HH:MM times") }
        if occasions.isEmpty { p.append("\(name): no occasions") }
        if !(capacityPerModule > 0 && capacityPerModule <= 10) { p.append("\(name): capacityPerModule must be in (0, 10]") }
        if !(1...600).contains(stayMinutes) { p.append("\(name): stayMinutes must be 1…600") }
        if spendPerVisit < 0 { p.append("\(name): spendPerVisit must be ≥ 0") }
        if !(0...1).contains(turnoverShare) { p.append("\(name): turnoverShare must be 0…1") }
        if !(0...10).contains(streetVisitorsPerModulePerHour) { p.append("\(name): streetVisitorsPerModulePerHour must be 0…10") }
        if (busyHours ?? []).contains(where: { !(0...23).contains($0) }) { p.append("\(name): busyHours must be 0…23") }
        if !(0...1).contains(heightBonusPerFloor ?? 0) { p.append("\(name): heightBonusPerFloor must be 0…1") }
        if !(0...0.5).contains(appeal ?? 0) { p.append("\(name): appeal must be 0…0.5") }
        return p
    }
}
