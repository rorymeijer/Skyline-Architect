import Foundation
import SkylineCore

/// How attractive a unit is to a tenant type, per criterion (each 0…1) and in total.
public struct UnitAppraisal: Equatable, Sendable {
    public var rentPerMonth: Int
    public var rent: Double
    public var access: Double
    public var noise: Double
    public var view: Double
    public var total: Double
    /// Street-to-unit travel time used for `access` (seconds, incl. expected elevator waits).
    public var accessSeconds: Double
    /// The weakest weighted criterion (why a prospect would decline).
    public var weakest: DeclineReason
    public var affordable: Bool
}

/// The rental market (Phase 8): prospective tenants arrive at random but deterministic
/// times, appraise the vacant units they could rent and sign the best one if it is good
/// enough; tenants review their unit daily and move out after three bad reviews.
public enum Leasing {
    // MARK: Units

    /// Rooms that can be rented (spec has `rentPerModule`) and have no tenant, in id order.
    public static func vacantUnits(_ world: GameWorld, catalog: BuildCatalog) -> [Room] {
        let leased = Set(world.tenants.values.map(\.room))
        return world.rooms.values.filter { catalog.spec($0.definitionID)?.rentPerModule != nil && !leased.contains($0.id) }
    }

    /// Monthly asking rent: base rent per module × width, +1 % per storey above ground, ×
    /// the building's rent level (player setting, Phase 9).
    public static func askingRent(_ room: Room, world: GameWorld, catalog: BuildCatalog) -> Int? {
        guard let base = catalog.spec(room.definitionID)?.rentPerModule else { return nil }
        let premium = 1 + 0.01 * Double(max(room.floors.lowest, 0))
        let level = world.buildings[room.buildingID]?.rentLevel ?? 1
        return Int((Double(base * room.columns.count) * premium * level).rounded())
    }

    // MARK: Appraisal

    public static func appraise(_ room: Room, for type: TenantType, world: GameWorld, engine: SimulationEngine) -> UnitAppraisal? {
        let catalog = engine.catalog
        guard let rent = askingRent(room, world: world, catalog: catalog), let building = world.buildings[room.buildingID] else { return nil }
        let perModule = Double(rent) / Double(max(room.columns.count, 1))
        let budget = Double(type.budgetPerModule)
        let rentScore = clamp((budget - perModule) / budget * 2 + 0.3)
        let seconds = accessSeconds(to: room, building: building, world: world, engine: engine)
        let accessScore = seconds.map { clamp(1 - ($0 - 30) / 270) } ?? 0
        let noiseScore = clamp(1 - noiseLevel(around: room, world: world, catalog: catalog))
        let viewScore = 0.2 + 0.8 * min(Double(max(room.floors.lowest, 0)) / 15, 1)
        let w = type.weights
        let sum = w.rent + w.access + w.noise + w.view
        // A unit nobody can reach is worthless whatever else it offers.
        let total = seconds == nil ? 0 : (w.rent * rentScore + w.access * accessScore + w.noise * noiseScore + w.view * viewScore) / sum
        let parts: [(DeclineReason, Double, Double)] = [(.tooExpensive, rentScore, w.rent), (.poorAccess, accessScore, w.access),
                                                        (.tooNoisy, noiseScore, w.noise), (.poorView, viewScore, w.view)]
        let weakest = seconds == nil ? .poorAccess : parts.filter { $0.2 > 0 }.min { $0.1 < $1.1 }?.0 ?? .poorAccess
        return UnitAppraisal(rentPerMonth: rent, rent: rentScore, access: accessScore, noise: noiseScore, view: viewScore,
                             total: total, accessSeconds: seconds ?? .infinity, weakest: perModule > budget ? .tooExpensive : weakest,
                             affordable: perModule <= budget)
    }

    static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }

    /// Noise from neighbours: rooms touching side by side count fully, rooms directly above
    /// or below (overlapping columns) half.
    static func noiseLevel(around room: Room, world: GameWorld, catalog: BuildCatalog) -> Double {
        var level = 0.0
        for other in world.rooms(in: room.buildingID) where other.id != room.id {
            guard let n = catalog.spec(other.definitionID)?.noise, n > 0 else { continue }
            let floorsOverlap = other.floors.lowest <= room.floors.highest && room.floors.lowest <= other.floors.highest
            if floorsOverlap, other.columns.end == room.columns.start || room.columns.end == other.columns.start {
                level += n
            } else if other.columns.overlaps(room.columns),
                      other.floors.highest == room.floors.lowest - 1 || other.floors.lowest == room.floors.highest + 1 {
                level += n / 2
            }
        }
        return level
    }

    /// Seconds from the street to the middle of the unit: walking and stairs from the route,
    /// plus for every elevator ride the bank's average wait (measured once it has 10
    /// boardings, otherwise the content estimate) and the ride itself. Nil if unreachable.
    static func accessSeconds(to room: Room, building: Building, world: GameWorld, engine: SimulationEngine) -> Double? {
        guard var from = RoutePlanner.street(of: building, rules: engine.rules) else { return nil }
        let grid = world.grid
        let target = Spot(floor: room.floors.lowest,
                          x: (grid.x(ofColumn: room.columns.start) + grid.x(ofColumn: room.columns.end)) / 2)
        var total = 0.0
        for _ in 0..<4 {
            guard let trip = RoutePlanner.plan(from: from, to: target, building: building, world: world, navigation: engine.navigation,
                                               catalog: engine.catalog, rules: engine.rules, now: 0),
                  let last = trip.legs.last else { return nil }
            total += Double(last.end)
            guard let ride = trip.ride else { return total }
            guard let shaft = world.rooms[ride.shaft], let spec = engine.rules.elevator(for: shaft.definitionID) else { return nil }
            let measured = ElevatorBanks.bank(of: ride.shaft, in: world, rules: engine.rules)
                .map { ElevatorBanks.stats(of: $0, in: world) }
            let wait = measured.flatMap { $0.boardings >= 10 ? $0.averageWait : nil } ?? spec.expectedWaitSeconds
            total += wait + Double(abs(ride.toFloor - ride.fromFloor)) * grid.floorHeight / spec.speed + Double(2 * spec.doorSeconds)
            from = Spot(floor: ride.toFloor, x: ride.x)
        }
        return total
    }

    // MARK: Signing and leaving

    /// Signs `type` into `room` at `now`: a tenant plus its members (residents move in
    /// shortly; workers start with their next scheduled event). Returns the new people.
    @discardableResult
    public static func sign(_ type: TenantType, into room: Room, at now: Tick, world: inout GameWorld, rules: SimulationRules,
                            catalog: BuildCatalog, satisfaction: Double) -> [PersonID] {
        let tenantID = world.makeTenantID()
        var rng = SeededRandom(seed: UInt64(tenantID.raw), stream: 0x7E4)
        let name: String
        if type.kind == "business", let words = rules.names.businessWords, let suffixes = rules.names.businessSuffixes,
           !words.isEmpty, !suffixes.isEmpty {
            name = words[rng.int(in: 0..<words.count)] + " " + suffixes[rng.int(in: 0..<suffixes.count)]
        } else {
            name = rules.names.last[rng.int(in: 0..<rules.names.last.count)] + " household"
        }
        world.tenants.insert(Tenant(id: tenantID, typeID: type.id, name: name, buildingID: room.buildingID, room: room.id,
                                    rent: askingRent(room, world: world, catalog: catalog) ?? 0, since: now, satisfaction: satisfaction))
        var added: [PersonID] = []
        for _ in 0..<type.members.count(modules: room.columns.count) {
            let id = world.makePersonID()
            var prng = SeededRandom(seed: UInt64(id.raw), stream: 0x9E0)
            let traits = UInt32(truncatingIfNeeded: prng.next())
            let personName = rules.names.first[prng.int(in: 0..<rules.names.first.count)] + " "
                + (type.kind == "household" ? name.replacingOccurrences(of: " household", with: "")
                                            : rules.names.last[prng.int(in: 0..<rules.names.last.count)])
            let age = type.role == .worker ? prng.int(in: 21..<66) : (type.id.contains("retired") ? prng.int(in: 64..<90) : prng.int(in: 19..<80))
            let scheduleID = type.schedules[Int(traits % UInt32(type.schedules.count))]
            var person = Person(id: id, name: personName, age: age, role: type.role, scheduleID: scheduleID, buildingID: room.buildingID,
                                homeRoom: type.role == .resident ? room.id : nil, workRoom: type.role == .worker ? room.id : nil,
                                place: .outside, nextEventTick: now, nextGoal: nil, traits: traits)
            person.tenantID = tenantID
            if type.role == .resident {
                person.nextGoal = .home                                   // moving in
                person.nextEventTick = now + Tick(prng.int(in: 0..<600))
            } else if let schedule = rules.schedule(scheduleID), let next = rules.nextScheduled(after: now, schedule: schedule, traits: traits) {
                person.nextGoal = next.goal
                person.nextEventTick = next.tick
            }
            world.people.insert(person)
            added.append(id)
        }
        return added
    }

    /// A tenant leaves: its members leave the building (out of any car) and the unit is vacant.
    public static func moveOut(_ tenant: TenantID, world: inout GameWorld) {
        for person in world.people.values where person.tenantID == tenant {
            if case let .riding(ride, _) = person.place {
                world.elevators.update(ride.shaft) { $0.passengers.removeAll { $0 == person.id } }
            }
            world.people.remove(person.id)
        }
        world.tenants.remove(tenant)
    }

    /// Developer/test shortcut: every vacant unit is rented at once by the first tenant type
    /// (content order) that rents that room type — deterministic, no appraisal.
    @discardableResult
    public static func fillAll(_ world: inout GameWorld, catalog: BuildCatalog, rules: SimulationRules) -> Int {
        var signed = 0
        for room in vacantUnits(world, catalog: catalog) {
            guard let type = rules.tenantTypes(for: room.definitionID).first else { continue }
            sign(type, into: room, at: world.clock.tick, world: &world, rules: rules, catalog: catalog, satisfaction: 0.7)
            signed += 1
        }
        return signed
    }
}

// MARK: - Market steps

extension SimulationEngine {
    /// Hourly market step (a scheduled event): prospects of each type may arrive and sign;
    /// at 06:00 every tenant reviews its unit. Returns people added (their events need queuing).
    func runMarket(at now: Tick, world: inout GameWorld) -> [PersonID] {
        var added: [PersonID] = []
        let seed = world.cities.values.first?.seed ?? 1
        let hour = now / 3600
        for (i, type) in rules.tenantTypes.enumerated() {
            var rng = SeededRandom(seed: seed, stream: hour &* 64 &+ UInt64(i))
            guard rng.unit() < type.prospectsPerDay / 24 else { continue }
            world.market.prospects += 1
            let candidates = Leasing.vacantUnits(world, catalog: catalog).filter { type.rooms.contains($0.definitionID) }
            let appraised = candidates.compactMap { room in Leasing.appraise(room, for: type, world: world, engine: self).map { (room, $0) } }
            guard let best = appraised.filter({ $0.1.affordable }).min(by: { ($1.1.total, $0.0.id) < ($0.1.total, $1.0.id) })
                    ?? appraised.min(by: { ($1.1.total, $0.0.id) < ($0.1.total, $1.0.id) }) else {
                world.market.countDecline(.noVacancy)          // counted, not logged (would flood a full building's log)
                continue
            }
            if best.1.affordable, best.1.total >= type.minScore {
                added += Leasing.sign(type, into: best.0, at: now, world: &world, rules: rules, catalog: catalog, satisfaction: best.1.total)
                world.market.signed += 1
                world.market.record(LeasingEvent(tick: now, typeID: type.id, outcome: .signed, room: best.0.id, reason: nil, score: best.1.total))
            } else {
                world.market.countDecline(best.1.weakest)
                world.market.record(LeasingEvent(tick: now, typeID: type.id, outcome: .declined, room: best.0.id,
                                                 reason: best.1.weakest, score: best.1.total))
            }
        }
        if SimClock.secondOfDay(now) == SimClock.startSecondOfDay {
            closeDay(at: now, world: &world)
            reviewTenants(at: now, world: &world)
        }
        world.market.nextTick = now + 3600
        return added
    }

    /// Daily review: satisfaction follows the unit's current appraisal (including measured
    /// elevator waits); three reviews in a row below the type's threshold → move out.
    func reviewTenants(at now: Tick, world: inout GameWorld) {
        for tenant in world.tenants.values {
            guard let type = rules.tenantType(tenant.typeID), let room = world.rooms[tenant.room],
                  let appraisal = Leasing.appraise(room, for: type, world: world, engine: self) else { continue }
            var t = tenant
            t.satisfaction = 0.6 * t.satisfaction + 0.4 * appraisal.total
            t.unhappyDays = appraisal.total < type.leaveBelow ? t.unhappyDays + 1 : 0
            if t.unhappyDays >= 3 {
                Leasing.moveOut(t.id, world: &world)
                world.market.movedOut += 1
                world.market.record(LeasingEvent(tick: now, typeID: type.id, outcome: .movedOut, room: room.id,
                                                 reason: appraisal.weakest, score: appraisal.total))
            } else {
                world.tenants.update(t.id) { $0 = t }
            }
        }
    }
}
