import Foundation
import SkylineCore

/// A kind of household or business (`tenants.json`, Phase 8): which units it rents, how many
/// people it brings and on which schedules, what it can pay and what it cares about.
public struct TenantType: Codable, Hashable, Sendable {
    public struct Members: Codable, Hashable, Sendable {
        public var fixed: Int?
        public var perModule: Double?

        public init(fixed: Int? = nil, perModule: Double? = nil) {
            self.fixed = fixed
            self.perModule = perModule
        }

        /// People for a unit `modules` wide (at least 1).
        public func count(modules: Int) -> Int {
            if let fixed { return max(1, fixed) }
            return max(1, Int((Double(modules) * (perModule ?? 0)).rounded(.down)))
        }
    }

    /// Relative importance of each criterion (normalized when scoring).
    public struct Weights: Codable, Hashable, Sendable {
        public var rent: Double
        public var access: Double
        public var noise: Double
        public var view: Double
        /// Utilities, cleanliness and condition (Phase 10; default 0.25 when absent).
        public var services: Double?

        public init(rent: Double, access: Double, noise: Double, view: Double, services: Double? = nil) {
            self.rent = rent
            self.access = access
            self.noise = noise
            self.view = view
            self.services = services
        }
    }

    public var id: String
    public var name: String
    /// "household" or "business" (naming, UI).
    public var kind: String
    /// Room definition ids this tenant rents.
    public var rooms: [String]
    public var role: PersonRole
    public var members: Members
    /// Schedule ids; each member gets one by their traits.
    public var schedules: [String]
    /// Highest monthly rent per module this tenant accepts.
    public var budgetPerModule: Int
    public var weights: Weights
    /// A unit must score at least this to be rented.
    public var minScore: Double
    /// Daily reviews below this make the tenant unhappy (3 in a row: moves out).
    public var leaveBelow: Double
    /// Average prospective tenants of this type per game day.
    public var prospectsPerDay: Double
    /// Building class index a building needs before this type considers it (Phase 11;
    /// nil = 0). Ignored in a sandbox.
    public var minClass: Int?

    public init(id: String, name: String, kind: String, rooms: [String], role: PersonRole, members: Members,
                schedules: [String], budgetPerModule: Int, weights: Weights, minScore: Double, leaveBelow: Double,
                prospectsPerDay: Double, minClass: Int? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.rooms = rooms
        self.role = role
        self.members = members
        self.schedules = schedules
        self.budgetPerModule = budgetPerModule
        self.weights = weights
        self.minScore = minScore
        self.leaveBelow = leaveBelow
        self.prospectsPerDay = prospectsPerDay
        self.minClass = minClass
    }

    /// Validation problems against the loaded schedules and room ids (empty if valid).
    public func problems(schedules known: [Schedule], rooms roomIDs: Set<String>) -> [String] {
        var p: [String] = []
        if !["household", "business"].contains(kind) { p.append("tenant '\(id)': kind must be household or business") }
        if rooms.isEmpty { p.append("tenant '\(id)': no room types") }
        for r in rooms where !roomIDs.contains(r) { p.append("tenant '\(id)': unknown room type '\(r)'") }
        if members.fixed == nil && (members.perModule ?? 0) <= 0 { p.append("tenant '\(id)': members need 'fixed' or a positive 'perModule'") }
        if schedules.isEmpty { p.append("tenant '\(id)': no schedules") }
        for s in schedules {
            guard let schedule = known.first(where: { $0.id == s }) else { p.append("tenant '\(id)': unknown schedule '\(s)'"); continue }
            if schedule.role != role { p.append("tenant '\(id)': schedule '\(s)' is for \(schedule.role.rawValue)s") }
        }
        if budgetPerModule <= 0 { p.append("tenant '\(id)': budgetPerModule must be positive") }
        let w = weights
        if [w.rent, w.access, w.noise, w.view].contains(where: { $0 < 0 }) || w.rent + w.access + w.noise + w.view <= 0 {
            p.append("tenant '\(id)': weights must be non-negative and not all zero")
        }
        if !(0...1).contains(minScore) || !(0...1).contains(leaveBelow) { p.append("tenant '\(id)': minScore/leaveBelow must be 0…1") }
        if prospectsPerDay < 0 || prospectsPerDay > 240 { p.append("tenant '\(id)': prospectsPerDay must be 0…240") }
        return p
    }
}
