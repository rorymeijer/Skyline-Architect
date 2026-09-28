import Foundation
import SkylineCore

/// What the unit inspector shows about an amenity (0.22). Pure data.
public struct AmenityInfo: Equatable, Sendable {
    /// "09:00–21:00".
    public var hours: String
    public var isOpenNow: Bool
    public var seats: Int
    /// Customers inside right now.
    public var customers: Int
    /// Today so far and yesterday; `share` is the landlord's fraction of the takings.
    public var today = AmenitySales()
    public var share: Double
    /// No operator: closed.
    public var operated: Bool

    public static func make(room: Room, world: GameWorld, engine: SimulationEngine) -> AmenityInfo? {
        guard let spec = engine.rules.amenity(for: room.definitionID) else { return nil }
        let tenant = world.tenants.values.first { $0.room == room.id }
        let now = SimClock.secondOfDay(world.clock.tick)
        let customers = world.people.values.filter { p in
            guard case let .room(r, _) = p.place, r == room.id else { return false }
            return p.role == .visitor || p.tenantID != tenant?.id
        }.count
        return AmenityInfo(hours: "\(spec.opens)–\(spec.closes)", isOpenNow: tenant != nil && spec.isOpen(atSecondOfDay: now),
                           seats: spec.capacity(modules: room.columns.count), customers: customers,
                           today: tenant?.sales ?? AmenitySales(), share: spec.turnoverShare, operated: tenant != nil)
    }
}

/// The amenities of the shown buildings, for the leasing panel (0.22). Pure data.
public struct AmenitySummary: Equatable, Sendable {
    public var venues = 0
    public var open = 0
    /// Street visitors in the buildings right now.
    public var visitorsNow = 0
    /// Yesterday: customers (of whom from the street), takings and the landlord's share.
    public var lastVisits = 0
    public var lastStreetVisits = 0
    public var lastTakings = 0
    public var lastShare = 0

    public init() {}

    public static func make(world: GameWorld, engine: SimulationEngine, buildings: [BuildingID]) -> AmenitySummary {
        var s = AmenitySummary()
        guard !engine.rules.amenities.isEmpty else { return s }
        let ids = Set(buildings)
        let now = SimClock.secondOfDay(world.clock.tick)
        var leased: [RoomID: Tenant] = [:]
        for t in world.tenants where ids.contains(t.buildingID) { leased[t.room] = t }
        for room in world.rooms where ids.contains(room.buildingID) {
            guard let spec = engine.rules.amenity(for: room.definitionID) else { continue }
            s.venues += 1
            guard let tenant = leased[room.id] else { continue }
            if spec.isOpen(atSecondOfDay: now) { s.open += 1 }
            let sales = tenant.sales ?? AmenitySales()
            s.lastVisits += sales.lastVisits
            s.lastStreetVisits += sales.lastStreetVisits
            s.lastTakings += sales.lastTakings
            s.lastShare += Int((Double(sales.lastTakings) * spec.turnoverShare).rounded())
        }
        s.visitorsNow = world.people.values.filter { $0.role == .visitor && $0.place != .outside && ids.contains($0.buildingID) }.count
        return s
    }
}
