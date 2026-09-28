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
