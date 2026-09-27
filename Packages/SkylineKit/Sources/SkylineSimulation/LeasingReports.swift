import Foundation
import SkylineCore

/// Everything the unit inspector shows about one room (Phase 8). Pure data.
public struct UnitReport: Equatable, Sendable {
    public struct Occupant: Equatable, Sendable {
        public var name: String
        public var typeName: String
        public var members: Int
        /// Members inside the unit right now.
        public var present: Int
        public var rent: Int
        public var sinceDay: Tick
        public var satisfaction: Double
        public var unhappyDays: Int
        public var appraisal: UnitAppraisal?
    }

    /// How a vacant unit looks to each tenant type that could rent it.
    public struct Interest: Equatable, Sendable {
        public var typeName: String
        public var appraisal: UnitAppraisal
        public var wouldSign: Bool
    }

    public var roomID: RoomID
    public var title: String
    public var floor: String
    public var width: Int
    public var leasable: Bool
    public var askingRent: Int?
    public var occupant: Occupant?
    public var interest: [Interest] = []
    /// Recent market events for this unit, newest first.
    public var history: [LeasingEvent] = []

    public static func make(room: Room, world: GameWorld, engine: SimulationEngine) -> UnitReport? {
        guard let spec = engine.catalog.spec(room.definitionID) else { return nil }
        let floor = room.floors.count == 1 ? FloorLabel.label(for: room.floors.lowest)
            : "\(FloorLabel.label(for: room.floors.lowest))–\(FloorLabel.label(for: room.floors.highest))"
        var report = UnitReport(roomID: room.id, title: spec.name, floor: floor, width: room.columns.count,
                                leasable: spec.rentPerModule != nil, askingRent: Leasing.askingRent(room, world: world, catalog: engine.catalog))
        if let tenant = world.tenants.values.first(where: { $0.room == room.id }) {
            let type = engine.rules.tenantType(tenant.typeID)
            let members = world.people.values.filter { $0.tenantID == tenant.id }
            let present = members.filter { if case let .room(r, _) = $0.place { r == room.id } else { false } }.count
            report.occupant = Occupant(name: tenant.name, typeName: type?.name ?? tenant.typeID, members: members.count, present: present,
                                       rent: tenant.rent, sinceDay: SimClock.day(tenant.since) + 1, satisfaction: tenant.satisfaction,
                                       unhappyDays: tenant.unhappyDays,
                                       appraisal: type.flatMap { Leasing.appraise(room, for: $0, world: world, engine: engine) })
        } else if report.leasable {
            report.interest = engine.rules.tenantTypes(for: room.definitionID).compactMap { type in
                Leasing.appraise(room, for: type, world: world, engine: engine).map {
                    Interest(typeName: type.name, appraisal: $0, wouldSign: $0.affordable && $0.total >= type.minScore)
                }
            }
            .sorted { $0.appraisal.total > $1.appraisal.total }
        }
        report.history = world.market.log.filter { $0.room == room.id }.reversed()
        return report
    }
}

/// The building's rental situation for the leasing panel (Phase 8). Pure data.
public struct LeasingSummary: Equatable, Sendable {
    public var units = 0
    public var leased = 0
    /// Sum of agreed monthly rents (not charged until Phase 9).
    public var rentRoll = 0
    public var households = 0
    public var businesses = 0
    public var averageSatisfaction = 0.0
    public var market = MarketState()
    /// Human-readable recent events, newest first.
    public var recent: [String] = []

    public init() {}

    public static func make(world: GameWorld, engine: SimulationEngine, buildings: [BuildingID], recent limit: Int = 8) -> LeasingSummary {
        var s = LeasingSummary()
        let ids = Set(buildings)
        s.units = world.rooms.values.filter { ids.contains($0.buildingID) && engine.catalog.spec($0.definitionID)?.rentPerModule != nil }.count
        let tenants = world.tenants.values.filter { ids.contains($0.buildingID) }
        s.leased = tenants.count
        s.rentRoll = tenants.reduce(0) { $0 + $1.rent }
        for t in tenants {
            if engine.rules.tenantType(t.typeID)?.kind == "business" { s.businesses += 1 } else { s.households += 1 }
        }
        s.averageSatisfaction = tenants.isEmpty ? 0 : tenants.reduce(0) { $0 + $1.satisfaction } / Double(tenants.count)
        s.market = world.market
        s.recent = world.market.log.suffix(limit).reversed().map { e in
            let type = engine.rules.tenantType(e.typeID)?.name ?? e.typeID
            let place = e.room.flatMap { world.rooms[$0] }.map { " · \(FloorLabel.label(for: $0.floors.lowest))" } ?? ""
            let when = "D\(SimClock.day(e.tick) + 1) \(SimClock.timeString(e.tick))"
            switch e.outcome {
            case .signed: return "\(when)  \(type) signed\(place)"
            case .declined: return "\(when)  \(type) declined\(place): \(e.reason.map(Self.describe) ?? "—")"
            case .movedOut: return "\(when)  \(type) moved out\(place): \(e.reason.map(Self.describe) ?? "—")"
            }
        }
        return s
    }

    public static func describe(_ reason: DeclineReason) -> String {
        switch reason {
        case .noVacancy: "no vacancy"
        case .tooExpensive: "too expensive"
        case .poorAccess: "hard to reach"
        case .tooNoisy: "too noisy"
        case .poorView: "poor view"
        case .poorServices: "poor services"
        }
    }
}
