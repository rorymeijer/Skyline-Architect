import Foundation
import SkylineCore

extension SimulationEngine {
    // MARK: Fire steps

    /// Steps every fire that is due: growth, sprinklers and brigade, damage, spread; a fire
    /// with nothing left burning ends.
    func stepFires(at now: Tick, world: inout GameWorld, events: inout Events) {
        guard let rules = fireRules else { return }
        let failure = self.rules.facilities?.failureBelow ?? 0
        for index in world.incidents.fires.indices.reversed() where world.incidents.fires[index].nextStep <= now {
            var fire = world.incidents.fires[index]
            let protected = FireSafety.protectedRooms(in: fire.building, world: world, catalog: catalog, failureBelow: failure)
            for i in fire.burning.indices {
                let room = fire.burning[i].room
                var change = rules.growthPerStep
                if protected.contains(room) { change -= rules.sprinklerSuppressionPerStep }
                if now >= fire.brigadeArrives { change -= rules.brigadeSuppressionPerStep }
                fire.burning[i].intensity = min(max(fire.burning[i].intensity + change, 0), 1)
                let damage = rules.damagePerStep * fire.burning[i].intensity
                world.upkeep.update(room) { u in
                    u.condition = max(0, u.condition - damage)
                    u.cleanliness = max(0, u.cleanliness - damage * 1.5)
                }
            }
            var rng = SeededRandom(seed: Weather.seed(of: world) ^ UInt64(fire.incident), stream: 0x5B7E &+ now)
            for b in fire.burning where b.intensity >= rules.spreadAbove {
                guard let room = world.rooms[b.room] else { continue }
                for n in FireSafety.neighbours(of: room, in: world, catalog: catalog)
                where !fire.burning.contains(where: { $0.room == n.id }) && !burnt(n.id, fire: fire, world: world) {
                    let chance = rules.spreadChancePerStep * b.intensity * (protected.contains(n.id) ? rules.protectedSpreadFactor : 1)
                    if rng.chance(chance) {
                        fire.burning.append(.init(room: n.id, intensity: rules.startIntensity))
                        world.incidents.update(fire.incident) { $0.rooms.append(n.id) }
                    }
                }
            }
            fire.burning.removeAll { $0.intensity <= 0 || !world.rooms.contains($0.room) }
            if fire.burning.isEmpty {
                world.incidents.fires.remove(at: index)
                endFire(fire, at: now, world: &world)
            } else {
                fire.nextStep = now + Tick(rules.stepSeconds)
                world.incidents.fires[index] = fire
                events.push(fire.nextStep, .fires)
            }
        }
    }

    /// A room the fire already reached and that has gone out stays out.
    private func burnt(_ room: RoomID, fire: Fire, world: GameWorld) -> Bool {
        world.incidents.log.first { $0.id == fire.incident }?.rooms.contains(room) ?? false
    }

    /// The fire is out: repairs are billed and ordered, destroyed units lose their tenants,
    /// the building's reputation drops. People come back on their next event.
    private func endFire(_ fire: Fire, at now: Tick, world: inout GameWorld) {
        guard let rules = fireRules, let incident = world.incidents.log.first(where: { $0.id == fire.incident }) else { return }
        let rooms = incident.rooms.compactMap { world.rooms[$0] }
        let cost = rooms.reduce(0) { $0 + rules.repairCostPerModule * $1.columns.count * $1.floors.count }
        if cost > 0 {
            world.ledger.post(Transaction(tick: now, amount: -cost, category: .maintenance,
                                          detail: "Fire damage repairs — \(rooms.count) room\(rooms.count == 1 ? "" : "s")", building: fire.building))
        }
        var lost = 0
        for room in rooms {
            if !world.facilities.jobs.contains(where: { $0.room == room.id && $0.kind == .repair }) {
                world.facilities.jobs.append(FacilityJob(room: room.id, kind: .repair, created: now))
            }
            if (world.upkeep[room.id]?.condition ?? 1) < rules.destroyedBelow,
               let tenant = world.tenants.values.first(where: { $0.room == room.id }) {
                Leasing.moveOut(tenant.id, world: &world)
                world.market.movedOut += 1
                lost += 1
            }
        }
        if var standing = world.buildings[fire.building]?.standing {
            standing.reputation = max(0, standing.reputation - rules.reputationPenalty)
            world.setStanding(standing, building: fire.building)
        }
        let minutes = (now - incident.started) / 60
        world.incidents.update(fire.incident) {
            $0.ended = now
            $0.detail += " — out after \(minutes) min, \(rooms.count) room\(rooms.count == 1 ? "" : "s") damaged"
                + (lost > 0 ? ", \(lost) tenant\(lost == 1 ? "" : "s") lost" : "") + ", repairs $\(cost)"
        }
    }

    // MARK: Weather incidents

    /// Hourly: weather-driven incidents (storm damage, outages, burst pipes) may strike a
    /// room of each building; the damage opens a repair job at once.
    func checkWeatherIncidents(at now: Tick, world: inout GameWorld) {
        guard let defs = rules.events?.incidents, let state = world.weather else { return }
        let facilities = rules.facilities
        for building in world.buildings.values {
            for (k, def) in defs.enumerated() where def.weather.contains(state.today) && state.temperature <= (def.maxTemperature ?? .infinity) {
                var rng = SeededRandom(seed: Weather.seed(of: world) ^ UInt64(building.id.raw), stream: 0x1AC1 &+ now / 3600 &* 16 &+ UInt64(k))
                guard rng.chance(def.chancePerDay / 24) else { continue }
                let candidates = world.rooms(in: building.id).filter { room in
                    guard let spec = catalog.spec(room.definitionID), spec.kind == .room else { return false }
                    if def.target.hasPrefix("supplies:") { return (spec.utilitySupply?[String(def.target.dropFirst(9))] ?? 0) > 0 }
                    return true
                }
                guard !candidates.isEmpty else { continue }
                let room = candidates[rng.int(in: 0..<candidates.count)]
                world.upkeep.update(room.id) { u in
                    u.condition = min(max(u.condition + def.condition, 0), 1)
                    u.cleanliness = min(max(u.cleanliness + def.cleanliness, 0), 1)
                }
                if let f = facilities, let u = world.upkeep[room.id] {
                    let repairAt = catalog.spec(room.definitionID)?.utilitySupply != nil ? f.equipmentRepairBelow : f.repairBelow
                    if u.condition < repairAt, !world.facilities.jobs.contains(where: { $0.room == room.id && $0.kind == .repair }) {
                        world.facilities.jobs.append(FacilityJob(room: room.id, kind: .repair, created: now))
                    }
                    if u.cleanliness < f.cleanBelow, !world.facilities.jobs.contains(where: { $0.room == room.id && $0.kind == .clean }) {
                        world.facilities.jobs.append(FacilityJob(room: room.id, kind: .clean, created: now))
                    }
                }
                if def.cost > 0 {
                    world.ledger.post(Transaction(tick: now, amount: -def.cost, category: .maintenance, detail: def.name, building: building.id))
                }
                if def.reputation > 0, var standing = world.buildings[building.id]?.standing {
                    standing.reputation = max(0, standing.reputation - def.reputation)
                    world.setStanding(standing, building: building.id)
                }
                let id = world.incidents.nextID
                world.incidents.nextID += 1
                world.incidents.record(Incident(id: id, kind: def.id, name: def.name, building: building.id, rooms: [room.id], started: now,
                                                ended: now, detail: "\(def.name): \(catalog.spec(room.definitionID)?.name ?? "room"), "
                                                    + FloorLabel.label(for: room.floors.lowest)))
            }
        }
    }
}
