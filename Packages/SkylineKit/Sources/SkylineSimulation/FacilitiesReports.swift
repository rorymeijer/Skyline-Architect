import Foundation
import SkylineCore

/// What the facilities panel shows (Phase 10). Pure data.
public struct FacilitiesSummary: Equatable, Sendable {
    public struct UtilityLine: Equatable, Sendable {
        public var name: String
        public var supply: Double
        public var demand: Double
        /// Rooms not fully supplied.
        public var shortRooms: Int
    }

    public var utilities: [UtilityLine] = []
    public var brokenEquipment = 0
    public var janitors = 0
    public var technicians = 0
    /// Hotel housekeepers (0.30.1), their open and finished jobs.
    public var housekeepers = 0
    public var openHousekeeping = 0
    public var housekept = 0
    public var wagesPerDay = 0
    public var openCleaning = 0
    public var openRepairs = 0
    public var averageCleanliness = 1.0
    public var averageCondition = 1.0
    public var cleaned = 0
    public var repaired = 0
    /// Places in the building's staff rooms (Phase E; nil = no staff rooms in the content).
    public var staffCapacity: Int?
    public var staffCount = 0
    /// Waste per day and what the waste rooms take (Phase E).
    public var wastePerDay = 0.0
    public var wasteCapacity = 0.0
    /// Elevators broken down now, and breakdowns so far (Phase E).
    public var brokenElevators = 0
    public var breakdowns = 0

    public init() {}

    /// `service` may be an allocation the caller already made this refresh (Phase 19).
    public static func make(world: GameWorld, engine: SimulationEngine, building: BuildingID?,
                            service shared: UtilityService? = nil) -> FacilitiesSummary {
        var s = FacilitiesSummary()
        guard let rules = engine.rules.facilities, let building else { return s }
        let service = shared ?? Utilities.allocate(building: building, world: world, catalog: engine.catalog, rules: engine.rules)
        s.utilities = rules.utilities.map {
            UtilityLine(name: $0.name, supply: service.supply[$0.id] ?? 0, demand: service.demand[$0.id] ?? 0,
                        shortRooms: service.shortOf($0.id).count)
        }
        s.brokenEquipment = service.broken.count
        s.janitors = FacilitiesManagement.staff(.janitor, in: world).count
        s.technicians = FacilitiesManagement.staff(.technician, in: world).count
        s.housekeepers = FacilitiesManagement.staff(.housekeeper, in: world).count
        s.wagesPerDay = s.janitors * rules.janitorWagePerDay + s.technicians * rules.technicianWagePerDay + s.housekeepers * rules.housekeeperWage
        s.openHousekeeping = world.facilities.jobs.filter { $0.kind == .housekeeping }.count
        s.housekept = world.facilities.housekept ?? 0
        s.openCleaning = world.facilities.jobs.filter { $0.kind == .clean }.count
        s.openRepairs = world.facilities.jobs.filter { $0.kind == .repair }.count
        let rooms = world.rooms(in: building).compactMap { world.upkeep[$0.id] }
        if !rooms.isEmpty {
            s.averageCleanliness = rooms.reduce(0) { $0 + $1.cleanliness } / Double(rooms.count)
            s.averageCondition = rooms.reduce(0) { $0 + $1.condition } / Double(rooms.count)
        }
        s.cleaned = world.facilities.cleaned
        s.repaired = world.facilities.repaired
        s.staffCapacity = FacilitiesManagement.staffCapacity(of: building, world: world, catalog: engine.catalog)
        s.staffCount = FacilitiesManagement.staffCount(of: building, world: world)
        s.wastePerDay = Waste.produced(in: building, world: world, rules: engine.rules)
        s.wasteCapacity = Waste.capacity(of: building, world: world, catalog: engine.catalog)
        s.brokenElevators = world.elevators.values.filter { $0.buildingID == building && $0.isOutOfService }.count
        s.breakdowns = world.facilities.breakdowns ?? 0
        return s
    }
}

/// Per-room service state for the services overlay (⌥⌘U).
public struct ServiceMark: Equatable, Sendable {
    public enum Status: Int, Comparable, Sendable {
        case ok, dirty, worn, short, broken
        public static func < (a: Status, b: Status) -> Bool { a.rawValue < b.rawValue }
    }
    public var room: RoomID
    public var rect: Rect
    public var status: Status
}

public enum ServicesOverlay {
    /// The worst problem of every room of the property: failed equipment, missing utilities,
    /// wear or dirt (below the job thresholds), or fine.
    public static func marks(world: GameWorld, engine: SimulationEngine, buildings: [BuildingID],
                             services: [BuildingID: UtilityService] = [:]) -> [ServiceMark] {
        guard let rules = engine.rules.facilities else { return [] }
        var marks: [ServiceMark] = []
        for b in buildings {
            let service = services[b] ?? Utilities.allocate(building: b, world: world, catalog: engine.catalog, rules: engine.rules)
            let broken = Set(service.broken)
            for room in world.rooms(in: b) {
                let u = world.upkeep[room.id]
                var status = ServiceMark.Status.ok
                if (u?.cleanliness ?? 1) < rules.cleanBelow { status = max(status, .dirty) }
                if (u?.condition ?? 1) < rules.repairBelow { status = max(status, .worn) }
                if service.minimum(room.id) < 0.99 { status = max(status, .short) }
                if broken.contains(room.id) { status = .broken }
                marks.append(ServiceMark(room: room.id, rect: world.grid.rect(columns: room.columns, floors: room.floors), status: status))
            }
        }
        return marks
    }
}
