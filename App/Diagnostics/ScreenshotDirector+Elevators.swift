#if DEBUG
import Foundation
import SkylineCore
import SkylinePresentation
import SkylineContent
import SkylinePersistence
import SkylineSimulation

/// Scenario helpers for the Phase 6 (elevator) captures.
extension ScreenshotDirector {
    static func waiting(in world: GameWorld, floor: Int? = nil) -> Int {
        world.people.values.filter { p in
            guard case let .waiting(ride, _, _) = p.place else { return false }
            return floor.map { ride.fromFloor == $0 } ?? true
        }.count
    }

    /// Cars standing with doors open and people inside (boarding / alighting moments).
    static func boardingCar(in world: GameWorld) -> ElevatorCar? {
        world.elevators.values.first { car in
            if case .stopped = car.motion { return !car.passengers.isEmpty } else { return false }
        }
    }

    /// Riders in a moving car, and where the car is (world meters, cab centre).
    static func movingCar(in world: GameWorld) -> (riders: Int, center: Vec2)? {
        for car in world.elevators {
            guard case .moving = car.motion, !car.passengers.isEmpty, let shaft = world.rooms[car.id] else { continue }
            let x = (world.grid.x(ofColumn: shaft.columns.start) + world.grid.x(ofColumn: shaft.columns.end)) / 2
            let y = ElevatorMotion.y(of: car, at: Double(world.clock.tick), grid: world.grid)
            return (car.passengers.count, Vec2(x, y + 1.3))
        }
        return nil
    }

    /// Someone walking across `floor` from one elevator to the next (a sky-lobby transfer).
    static func skyLobbyWalker(on floor: Int, in world: GameWorld) -> Vec2? {
        let now = world.clock.tick
        for p in world.people {
            guard p.pendingRide != nil, case let .travelling(legs, _) = p.place,
                  let leg = legs.first(where: { now < $0.end }), case .walk(floor, _, _, let start, let end) = leg,
                  end > start + 3, now > start + 1, now + 1 < end,          // mid-walk, not at a door
                  let s = PersonMotion.sample(legs, at: Double(now), grid: world.grid) else { continue }
            return s.position
        }
        return nil
    }

    /// A staff member at work (job started), and where.
    static func staffAtWork(_ role: PersonRole, in world: GameWorld) -> Vec2? {
        for p in world.people where p.role == role {
            guard case let .room(r, x) = p.place, p.job?.until != nil, let room = world.rooms[r] else { continue }
            return Vec2(x, world.grid.y(ofFloor: room.floors.lowest))
        }
        return nil
    }

    /// "Population 12/35 ✗, …" for the next class's requirements.
    static func requirements(_ p: ProgressionSummary) -> String {
        guard let next = p.nextClassName else { return "highest class" }
        return "next \(next): " + p.requirements.map { "\($0.label) \(Int($0.current))/\(Int($0.needed)) \($0.met ? "✓" : "✗")" }.joined(separator: ", ")
    }

    /// Sets today's weather (developer tool for captures): no transition, clear tomorrow.
    static func force(_ kind: String, _ temperature: Double, model: AppModel) {
        guard let day = model.world?.weather?.day else { return }
        model.world?.weather = WeatherState(day: day, yesterday: kind, today: kind, tomorrow: "clear", temperature: temperature)
    }

    /// The `index`-th office from the bottom.
    static func office(_ model: AppModel, index: Int) -> Room? {
        guard let world = model.world else { return nil }
        let offices = world.rooms.values.filter { $0.definitionID == "office-small" }.sorted { ($0.floors.lowest, $0.id) < ($1.floors.lowest, $1.id) }
        return offices.indices.contains(index) ? offices[index] : offices.last
    }

    static func weatherNote(_ model: AppModel) -> String {
        guard let w = model.weather else { return "no weather" }
        return "\(w.season), \(w.name) \(w.temperature) °C, tomorrow \(w.tomorrowName)" + (w.effects.isEmpty ? "" : " — \(w.effects)")
    }

    /// A grid cell inside a room (for selecting it like a click would).
    static func cell(of room: Room) -> GridCell {
        GridCell(column: room.columns.start + room.columns.count / 2, floor: room.floors.lowest)
    }

    /// "Units let ≥ 12: 9 ✗, …" for the scenario panel (Phase 16).
    static func objectives(_ model: AppModel) -> String {
        guard let s = model.scenario else { return "no scenario" }
        return "\(s.daysLeft) closings left; " + s.rows.map { "\($0.label): \($0.current) \($0.met ? "✓" : "✗")" }.joined(separator: ", ")
    }

    /// "Base (active), Kestrel Bay (active), …" for the mod manager (Phase 17).
    static func packs(_ model: AppModel) -> String {
        model.modRows.map { row -> String in
            let state: String
            switch row.status.state {
            case .active: state = "active"
            case .disabled: state = row.enabled ? "off, on after Apply" : "off"
            case .failed(let why): state = "failed: \(why)"
            }
            return "\(row.status.name) (\(state))"
        }.joined(separator: "; ")
    }

    /// A mod whose tenant type rents a room type nobody defines (for the validation capture).
    static func writeBrokenMod(into mods: URL) {
        let folder = mods.appendingPathComponent("harbour-lights", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifest = #"{"id":"harbour-lights","name":"Harbour Lights","version":"0.1.0","formatVersion":1,"description":"Lighthouse keepers (broken on purpose).","author":"Capture script","files":{"tenants":"tenants.json"}}"#
        let tenants = #"[{"id":"lighthouse-keeper","name":"Lighthouse Keeper","kind":"household","rooms":["lighthouse-flat"],"role":"resident","members":{"fixed":1},"schedules":["resident-commuter"],"budgetPerModule":200,"weights":{"rent":1,"access":1,"noise":1,"view":1},"minScore":0.5,"leaveBelow":0.3,"prospectsPerDay":1}]"#
        try? manifest.write(to: folder.appendingPathComponent("pack.json"), atomically: true, encoding: .utf8)
        try? tenants.write(to: folder.appendingPathComponent("tenants.json"), atomically: true, encoding: .utf8)
    }

    /// Slots in the stand-in cloud folder (Phase 18).
    static func cloudSlots(_ model: AppModel) -> [String] {
        guard let folder = model.syncFolderOverride else { return [] }
        return SaveStore(directory: folder).list().map(\.slot).sorted()
    }

    /// Worlds the simulated other device wrote, by slot (to check what was loaded).
    static var otherDeviceWorlds: [String: GameWorld] = [:]

    /// Writes a save into the stand-in cloud folder as another device would: the current
    /// world advanced by `hours` on a copy.
    static func writeFromOtherDevice(_ model: AppModel, slot: String, title: String, hours: Int) -> Bool {
        guard let folder = model.syncFolderOverride, var world = model.world, let simulation = model.simulation,
              let property = model.activePropertyID else { return false }
        simulation.advance(&world, by: Tick(hours * 3600))
        let save = SaveGame(metadata: SaveMetadata(title: title, savedAt: Date(), gameVersion: "0.18.0 (iPad)"),
                            contentPacks: model.packReferences, activePropertyID: property, world: world)
        guard (try? SaveStore(directory: folder).write(save, slot: slot)) != nil else { return false }
        otherDeviceWorlds[slot] = world
        return true
    }

    /// "211 floors, 481 rooms, 950 people, 29 cars" (Phase 19).
    static func scale(_ model: AppModel) -> String {
        guard let world = model.world else { return "no world" }
        let floors = world.buildings.values.compactMap { $0.builtLevels?.count }.max() ?? 0
        return "\(floors) floors, \(world.rooms.count) rooms, \(world.people.count) people, \(world.elevators.count) cars"
    }

    /// Clouds the renderer is showing now (Phase 20).
    static func cloudCount(_ model: AppModel) -> Int {
        guard let world = model.world, let property = model.activePropertyID,
              let city = world.properties[property].flatMap({ world.cities[$0.cityID] }) else { return 0 }
        let t = Double(world.clock.tick)
        let look = model.weatherLook(at: t)
        let view = model.scene?.controller.camera.visibleRect
        let x = world.buildings(on: property).first.map { world.grid.x(ofColumn: $0.footprint.start) } ?? 0
        return CloudView.clouds(seed: city.seed, time: t, cover: look.cloud, centerX: x, visible: view).count
    }

    static func carCenter(_ car: ElevatorCar, in world: GameWorld) -> Vec2? {
        guard let shaft = world.rooms[car.id] else { return nil }
        let x = (world.grid.x(ofColumn: shaft.columns.start) + world.grid.x(ofColumn: shaft.columns.end)) / 2
        return Vec2(x, ElevatorMotion.y(of: car, at: Double(world.clock.tick), grid: world.grid) + 1.3)
    }
}
#endif
