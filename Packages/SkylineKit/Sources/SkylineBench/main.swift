// skyline-bench — profiles the engine on a generated large tower (Phase 19).
// Build in release: `swift run -c release skyline-bench [--zones 10] [--width 64] [--days 1]`.
// Prints one line per stage; results are recorded in Documentation/PERFORMANCE.md.
import Foundation
import SkylineCore
import SkylineContent
import SkylinePersistence
import SkylinePresentation
import SkylineSimulation

let args = Array(CommandLine.arguments.dropFirst())
func option(_ name: String, _ fallback: Int) -> Int {
    guard let i = args.firstIndex(of: name), i + 1 < args.count, let v = Int(args[i + 1]) else { return fallback }
    return v
}
let zones = option("--zones", 10)
let width = max(option("--width", 64), StressTower.minimumWidth(zones: zones))
let days = option("--days", 1)
let step = Tick(option("--step", 240))

@discardableResult
func measure<T>(_ label: String, _ body: () throws -> T) rethrows -> T {
    let start = DispatchTime.now().uptimeNanoseconds
    let result = try body()
    let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
    print(label.padding(toLength: 40, withPad: " ", startingAt: 0) + String(format: "%10.1f ms", ms))
    return result
}

do {
    let library = try measure("load content") { try ContentLibrary.loadBase() }
    var (world, property) = try measure("build tower (\(zones) zones, \(width) m)") {
        try StressTower.world(zones: zones, width: width, library: library)
    }
    let rules = library.simulationRules, catalog = library.buildCatalog
    measure("population sync") { PopulationSync.sync(&world, catalog: catalog, rules: rules) }
    measure("lease every unit") { Leasing.fillAll(&world, catalog: catalog, rules: rules) }
    let engine = SimulationEngine(rules: rules, catalog: catalog)
    measure("elevator sync + first plan") { engine.replanAfterConstruction(&world) }
    let floors = StressTower.topFloor(zones: zones) + 2
    print("  floors \(floors), rooms \(world.rooms.count), people \(world.people.count), cars \(world.elevators.count), tenants \(world.tenants.count)")

    var worst = 0.0, events = 0
    var slowest: [(ms: Double, tick: Tick)] = []
    let steps = Int(Tick(days) * SimClock.secondsPerDay / step)
    measure("simulate \(days) day(s) in \(step)-tick steps") {
        for _ in 0..<steps {
            let s = DispatchTime.now().uptimeNanoseconds
            let at = world.clock.tick
            events += engine.advance(&world, by: step).eventsProcessed
            let ms = Double(DispatchTime.now().uptimeNanoseconds - s) / 1e6
            worst = max(worst, ms)
            slowest.append((ms, at))
        }
    }
    let top = slowest.sorted { $0.ms > $1.ms }.prefix(5).map { String(format: "%@ %.1f ms", SimClock.timeString($0.tick + step) as NSString, $0.ms) }
    print("  slowest steps (ending at): " + top.joined(separator: ", "))
    let m = engine.navigation.metrics
    print(String(format: "  %d steps, worst step %.1f ms, %d events; routes: %d queries, %d cache hits, %d graph builds",
                 steps, worst, events, m.queries, m.cacheHits, m.graphBuilds))
    // The app advances once per frame (1× = 24 ticks/s ≈ 0–1 tick per frame): the fixed cost
    // of a call matters as much as the events in it.
    var quiet = world
    let perCall = measure("600 one-tick calls (per-frame cost)") { () -> Double in
        let s = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<600 { engine.advance(&quiet, by: 1) }
        return Double(DispatchTime.now().uptimeNanoseconds - s) / 1e6 / 600
    }
    print(String(format: "  %.3f ms per call", perCall))
    let building = world.buildings(on: property).first!.id
    measure("utility allocation (1×)") { _ = Utilities.allocate(building: building, world: world, catalog: catalog, rules: rules) }
    measure("fire protection (1×)") { _ = FireSafety.protectedRooms(in: building, world: world, catalog: catalog, failureBelow: rules.facilities?.failureBelow ?? 0) }
    measure("economy summary (1×)") { _ = EconomySummary.make(world: world, rules: rules, building: building) }

    // What the app does per frame (providers, for a 114 × 76 m view at 9 pt/m) and at 4 Hz
    // (panel summaries), 20 repetitions each.
    let view = Rect(x: 0, y: 60, width: 114, height: 76)
    let t = Double(world.clock.tick)
    func per(_ label: String, _ body: () -> Void) {
        let s = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<20 { body() }
        print(label.padding(toLength: 40, withPad: " ", startingAt: 0)
              + String(format: "%10.2f ms each", Double(DispatchTime.now().uptimeNanoseconds - s) / 1e6 / 20))
    }
    print("per frame:")
    per("  people sprites") { _ = PeopleView.visible(world: world, propertyID: property, time: t, visible: view, zoom: 9) }
    per("  elevator cars") { _ = ElevatorView.visible(world: world, propertyID: property, time: t, visible: view, zoom: 9) }
    per("  lit rooms") { _ = DayNight.litRooms(world: world, propertyID: property, catalog: catalog, time: t, visible: view, zoom: 9) }
    per("  roofs + pavement") {
        _ = WeatherView.roofs(world: world, propertyID: property)
        _ = WeatherView.pavement(world: world, propertyID: property, visible: view)
    }
    per("  fire marks") {
        _ = FireView.flames(world: world, propertyID: property, time: t)
        _ = FireView.scorched(world: world, propertyID: property)
    }
    print("4 Hz summaries:")
    per("  facilities summary") { _ = FacilitiesSummary.make(world: world, engine: engine, building: building) }
    per("  lighting watts") { _ = Energy.lightingWatts(of: building, world: world, engine: engine) }
    per("  progression summary") { _ = ProgressionSummary.make(world: world, engine: engine, building: building) }
    per("  leasing summary") { _ = LeasingSummary.make(world: world, engine: engine, buildings: [building]) }
    per("  elevator traffic") { _ = ElevatorTraffic.make(world: world, rules: rules, buildings: [building], now: world.clock.tick) }
    per("  fire protection") { _ = FireSafety.protectedRooms(in: building, world: world, catalog: catalog, failureBelow: 0.1) }
    per("  estate summary") { _ = EstateSummary.make(world: world, library: library) }
    per("  app refresh (one shared allocation)") {
        let services = engine.utilityServices(world, buildings: [building])
        _ = FacilitiesSummary.make(world: world, engine: engine, building: building, service: services[building])
        _ = Energy.lightingWatts(of: building, world: world, engine: engine, service: services[building])
        _ = ProgressionSummary.make(world: world, engine: engine, building: building, service: services[building])
    }

    let save = SaveGame(metadata: SaveMetadata(title: "Bench", savedAt: Date(timeIntervalSince1970: 0), gameVersion: "bench"),
                        contentPacks: [ContentPackReference(id: "base", version: library.manifest.version)],
                        activePropertyID: property, world: world)
    let data = try measure("save encode") { try SaveCodec.encode(save) }
    print("  save size \(data.count / 1024) KB")
    _ = try measure("save decode + validate") { try SaveCodec.decode(data, availablePacks: [ContentPackReference(id: "base", version: "0.1.0")]) }
    let composition = measure("compose site (drawing IR)") {
        SiteComposer.compose(world: world, propertyID: property, catalog: catalog, art: library.artCatalog)
    }
    print("  building items \(composition?.buildings.drawing.items.count ?? 0)")
} catch {
    FileHandle.standardError.write(Data("skyline-bench: \(error)\n".utf8))
    exit(1)
}
