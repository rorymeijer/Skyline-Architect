import Foundation
import Observation
import SkylineCore
import SkylineContent
import SkylinePersistence
import SkylinePresentation
import SkylineSimulation

/// A message for the player (errors from saving, loading or construction).
struct AppAlert: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var message: String
}

/// App-level state: the authoritative game model, construction session (engine, undo
/// history, active tool), saves, view settings and the renderer for the active property.
/// Views read it; the renderer derives everything it draws from `world`.
@Observable
final class AppModel {
    /// Authoritative state. Not observed: the simulation mutates it every tick; views read
    /// the 4 Hz summaries below instead.
    @ObservationIgnored var world: GameWorld?
    private(set) var activePropertyID: PropertyID?
    private(set) var propertyName = "—"
    private(set) var cityName = "—"

    // Simulation summaries (refreshed at 4 Hz).
    var speed: GameSpeed = .normal
    var clockText = "Day 1 · 06:00"
    var population = PopulationSummary()
    var navigationMetrics = NavigationMetrics()
    /// Developer navigation overlay (Debug builds, ⌥⌘N).
    var showNavigationOverlay = false
    /// Elevator traffic overlay (⌥⌘T) and bank panel (⌥⌘E).
    var showTraffic = false
    var showBanksPanel = false
    /// Elevator banks of the active property with statistics (refreshed at 4 Hz).
    var banks: [ElevatorTraffic.Bank] = []
    /// Selected room (click) and its inspector data; leasing overview (Phase 8, 4 Hz).
    var selectedRoom: RoomID?
    var unitReport: UnitReport?
    var leasing = LeasingSummary()
    var showLeasingPanel = false
    /// Money (Phase 9, 4 Hz), economy panel, start menu, bankruptcy.
    var economy = EconomySummary()
    var showEconomyPanel = false
    var showMainMenu = false
    private(set) var loadError: String?
    private(set) var scene: WorldScene?

    private(set) var showGrid = true
    var showDeveloperHUD: Bool
    private(set) var diagnostics = RenderDiagnostics()

    private(set) var activeTool: ConstructionTool?
    private(set) var canUndo = false
    private(set) var canRedo = false
    private(set) var lastSaveDescription: String?
    var alert: AppAlert?
    var showLoadSheet = false

    @ObservationIgnored private(set) var library: ContentLibrary?
    @ObservationIgnored private var engine: ConstructionEngine?
    @ObservationIgnored private var history = ConstructionHistory()
    @ObservationIgnored private(set) var saveStore: SaveStore
    @ObservationIgnored var hasUnsavedChanges = false
    @ObservationIgnored private var autosaveTimer: Timer?
    @ObservationIgnored private var screenshotDirector: AnyObject?
    @ObservationIgnored var simulation: SimulationEngine?
    @ObservationIgnored var host = SimulationHost()
    @ObservationIgnored var speedBeforePause: GameSpeed = .normal
    @ObservationIgnored var lastSimulationMs = 0.0

    static let autosaveInterval: TimeInterval = 120

    init(arguments: [String] = CommandLine.arguments) {
        #if DEBUG
        showDeveloperHUD = true
        #else
        showDeveloperHUD = false
        #endif
        saveStore = SaveStore(directory: Self.defaultSaveDirectory())
        do {
            let library = try ContentLibrary.loadBase()
            self.library = library
            engine = ConstructionEngine(catalog: library.buildCatalog)
            simulation = SimulationEngine(rules: library.simulationRules, catalog: library.buildCatalog)
            try startNewGame()
        } catch {
            loadError = "\(error)"
        }
        // The player starts at the main menu (the new game waits paused behind it).
        showMainMenu = true
        setSpeed(.paused)
        #if DEBUG
        if let config = ScreenshotDirector.Configuration(arguments: arguments), let scene {
            // Captures must never touch the player's real saves.
            saveStore = SaveStore(directory: config.directory.appendingPathComponent("saves", isDirectory: true))
            showDeveloperHUD = true
            showMainMenu = false
            let director = ScreenshotDirector(configuration: config, model: self)
            screenshotDirector = director
            scene.onReady = { [weak director] in director?.start() }
        }
        #endif
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: Self.autosaveInterval, repeats: true) { [weak self] _ in
            self?.autosaveIfNeeded()
        }
    }

    static func defaultSaveDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Skyline Architect", isDirectory: true).appendingPathComponent("Saves", isDirectory: true)
    }

    var catalog: BuildCatalog? { engine?.catalog }
    var art: ArtCatalog { library?.artCatalog ?? .empty }

    // MARK: Game lifecycle

    private func startNewGame() throws {
        guard let library else { return }
        let game = try NewGameFactory.make(startID: NewGameFactory.defaultStartID, library: library)
        install(world: game.world, activePropertyID: game.activePropertyID)
    }

    func newGame() {
        do { try startNewGame() } catch { alert = AppAlert(title: "Could not start a new game", message: "\(error)") }
    }

    /// Replaces the world and builds a fresh scene for it.
    private func install(world: GameWorld, activePropertyID: PropertyID) {
        var world = world
        if let library { PopulationSync.sync(&world, catalog: library.buildCatalog, rules: library.simulationRules) }
        simulation?.replanAfterConstruction(&world)     // also creates elevator cars
        self.world = world
        self.activePropertyID = activePropertyID
        showMainMenu = false
        let property = world.properties[activePropertyID]
        propertyName = property?.name ?? "—"
        cityName = property.flatMap { world.cities[$0.cityID]?.name } ?? "—"
        refreshSimulationSummary()
        history.clear()
        refreshUndoState()
        hasUnsavedChanges = false
        activeTool = nil
        guard let composition = SiteComposer.compose(world: world, propertyID: activePropertyID, catalog: catalog, art: art) else {
            loadError = "The starting property could not be composed."
            return
        }
        let previous = scene
        let scene = WorldScene(composition: composition)
        scene.showGrid = showGrid
        scene.onDiagnostics = { [weak self] d in
            self?.diagnostics = d
            self?.refreshSimulationSummary()
        }
        scene.onFrame = { [weak self] dt in self?.stepSimulation(realDelta: dt) }
        scene.peopleProvider = { [weak self] visible, zoom in
            guard let self, let world = self.world, let property = self.activePropertyID else { return [] }
            return PeopleView.visible(world: world, propertyID: property, time: Double(world.clock.tick) + self.host.fraction,
                                      visible: visible, zoom: zoom)
        }
        scene.carProvider = { [weak self] visible, zoom in
            guard let self, let world = self.world, let property = self.activePropertyID else { return [] }
            return ElevatorView.visible(world: world, propertyID: property, time: Double(world.clock.tick) + self.host.fraction,
                                        visible: visible, zoom: zoom) { self.doorSeconds(of: $0) }
        }
        scene.previewProvider = { [weak self] tool, anchor, current in
            guard let self, let world = self.world, let property = self.activePropertyID, let engine = self.engine else { return nil }
            return PlacementPlanner.preview(tool: tool, anchor: anchor, current: current, world: world, propertyID: property, engine: engine)
        }
        scene.roomLabelProvider = { [weak self] visible, zoom in
            guard let self, let world = self.world, let property = self.activePropertyID, let catalog = self.catalog else { return [] }
            return RoomLabels.build(world: world, propertyID: property, catalog: catalog, visible: visible, zoom: zoom,
                                    text: self.roomLabelText)
        }
        #if DEBUG
        scene.navigationProvider = { [weak self] in self?.navigationOverlay() }
        #endif
        scene.trafficProvider = { [weak self] in
            guard let self, self.showTraffic else { return nil }
            return self.traffic()
        }
        scene.onCommit = { [weak self] command in self?.perform(command) }
        scene.onSelect = { [weak self] cell in self?.selectRoom(at: cell) }
        scene.lightingProvider = { [weak self] visible in
            guard let self, let world = self.world, let property = self.activePropertyID, let catalog = self.catalog else { return (1, []) }
            let t = Double(world.clock.tick) + self.host.fraction
            return (DayNight.daylight(atTick: t),
                    DayNight.litRooms(world: world, propertyID: property, catalog: catalog, time: t, visible: visible))
        }
        if let previous {
            scene.onReady = previous.onReady
            // Keep the camera where the player was looking.
            let cam = previous.controller.camera
            scene.initialPlacement = (cam.center, cam.zoom)
        }
        self.scene = scene
    }

    // MARK: Construction

    func select(tool: ConstructionTool?) {
        activeTool = tool
        scene?.activeTool = tool
    }

    func handleToolKey(_ key: String) {
        switch key {
        case "floor": select(tool: activeTool == .floor ? nil : .floor)
        case "demolish": select(tool: activeTool == .demolish ? nil : .demolish)
        case "pause": togglePause()
        case "speed1": setSpeed(.normal)
        case "speed2": setSpeed(.double)
        case "speed3": setSpeed(.quadruple)
        case "speed4": setSpeed(.fastest)
        default:
            select(tool: nil)
            selectRoom(at: nil)
        }
    }

    /// Applies a player command through the undo history.
    @discardableResult
    func perform(_ command: BuildCommand) -> Bool {
        guard var world, let engine else { return false }
        do {
            let applied = try history.perform(command, engine: engine, world: &world)
            commit(world, plan: applied.plan)
            return true
        } catch {
            alert = AppAlert(title: "Cannot build here", message: "\(error)")
            return false
        }
    }

    func undo() {
        guard var world, let engine else { return }
        do {
            if let applied = try history.undo(engine: engine, world: &world) {
                commit(world, plan: applied.plan)
            }
        } catch {
            alert = AppAlert(title: "Undo failed", message: "\(error)")
        }
    }

    func redo() {
        guard var world, let engine else { return }
        do {
            if let applied = try history.redo(engine: engine, world: &world) {
                commit(world, plan: applied.plan)
            }
        } catch {
            alert = AppAlert(title: "Redo failed", message: "\(error)")
        }
    }

    /// Applies a content blueprint as a sequence of player commands (developer tool).
    func applyBlueprint(_ id: String) {
        guard var world, let engine, let property = activePropertyID,
              let blueprint = library?.blueprint(id), let building = world.buildings(on: property).first else { return }
        do {
            #if DEBUG
            // Developer tool: grant whatever the blueprint costs beyond the cash at hand.
            let cost = blueprint.commands(for: building).reduce(0) { sum, c in
                sum + max((try? engine.validate(c, in: world).get().cost) ?? 0, 0)
            }
            if cost > world.ledger.cash {
                world.ledger.post(Transaction(tick: world.clock.tick, amount: cost - world.ledger.cash, category: .grant,
                                              detail: "Developer grant for blueprint \(id)"))
            }
            #endif
            for command in blueprint.commands(for: building) {
                try history.perform(command, engine: engine, world: &world)
            }
        } catch {
            alert = AppAlert(title: "Blueprint failed", message: "\(error)")
        }
        commit(world, plan: nil)
    }

    /// Stores the new world and re-renders only what changed (`plan` nil = everything).
    /// The population follows the rooms (occupants appear for new rooms, leave demolished ones)
    /// and trips follow the structure.
    private func commit(_ newWorld: GameWorld, plan: ConstructionPlan?) {
        var newWorld = newWorld
        if let library { PopulationSync.sync(&newWorld, catalog: library.buildCatalog, rules: library.simulationRules) }
        // Trips through removed stairs are re-planned now, so even a paused game is consistent.
        simulation?.replanAfterConstruction(&newWorld)
        world = newWorld
        hasUnsavedChanges = true
        refreshUndoState()
        guard let scene else { return }
        let composition = SiteComposer.recompose(scene.composition, world: newWorld, catalog: catalog, art: art)
        scene.updateComposition(composition, dirty: plan.map { SiteComposer.dirtyRect(for: $0, grid: newWorld.grid) })
    }

    private func refreshUndoState() {
        canUndo = history.canUndo
        canRedo = history.canRedo
    }

    // MARK: Saving

    var packReferences: [ContentPackReference] {
        library.map { [ContentPackReference(id: $0.manifest.id, version: $0.manifest.version)] } ?? []
    }

    private func makeSave(title: String) -> SaveGame? {
        guard let world, let property = activePropertyID else { return nil }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        return SaveGame(metadata: SaveMetadata(title: title, savedAt: Date(), gameVersion: version),
                        contentPacks: packReferences, activePropertyID: property, world: world)
    }

    @discardableResult
    func save(slot: String = SaveStore.quicksaveSlot, title: String? = nil) -> Bool {
        guard let save = makeSave(title: title ?? propertyName) else { return false }
        do {
            try saveStore.write(save, slot: slot)
            hasUnsavedChanges = false
            lastSaveDescription = "Saved “\(slot)” at \(Self.timeFormatter.string(from: save.metadata.savedAt))"
            return true
        } catch {
            alert = AppAlert(title: "Saving failed", message: "\(error)")
            return false
        }
    }

    @discardableResult
    func load(slot: String) -> Bool {
        do {
            let save = try saveStore.load(slot: slot, availablePacks: packReferences)
            install(world: save.world, activePropertyID: save.activePropertyID)
            lastSaveDescription = "Loaded “\(slot)”"
            return true
        } catch {
            alert = AppAlert(title: "This save cannot be loaded", message: "\(error)")
            return false
        }
    }

    func availableSaves() -> [SaveSlotInfo] { saveStore.list() }

    func autosaveIfNeeded() {
        guard hasUnsavedChanges, let save = makeSave(title: "Autosave") else { return }
        do {
            try saveStore.writeAutosave(save)
            hasUnsavedChanges = false
            lastSaveDescription = "Autosaved at \(Self.timeFormatter.string(from: save.metadata.savedAt))"
        } catch {
            alert = AppAlert(title: "Autosave failed", message: "\(error)")
        }
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    // MARK: View commands

    func zoom(by factor: Double) {
        guard let scene else { return }
        let center = scene.controller.camera.viewportSize / 2
        scene.withController { $0.zoom(by: factor, at: center, animated: true) }
    }

    func apply(_ preset: CameraPreset) { scene?.apply(preset: preset) }

    func toggleGrid() { setGrid(!showGrid) }

    func setGrid(_ visible: Bool) {
        showGrid = visible
        scene?.showGrid = visible
    }
}
