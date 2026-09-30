import Foundation
import Observation
import SwiftUI
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
    /// Height controls when the selection is a shaft (empty otherwise).
    var shaftOptions: [ConstructionOption] = []
    /// Stop switches when the selection is an elevator shaft (0.30; empty otherwise).
    var elevatorStops: [ElevatorStopToggle] = []
    /// Foundation panel (0.21): the building's groundwork and what can be extended.
    var showFoundationPanel = false
    var foundation: FoundationSummary?
    var leasing = LeasingSummary()
    var showLeasingPanel = false
    /// Money (Phase 9, 4 Hz), economy panel, start menu, bankruptcy.
    var economy = EconomySummary()
    var showEconomyPanel = false
    var showMainMenu = false
    /// Facilities (Phase 10, 4 Hz), panel and services overlay.
    var facilities = FacilitiesSummary()
    var showFacilitiesPanel = false
    var showServices = false
    /// Elevator shafts drawn as glass (0.30, remembered): rooms behind them show through.
    var seeThroughShafts = false {
        didSet {
            guard seeThroughShafts != oldValue else { return }
            if persistsModSettings { UserDefaults.standard.set(seeThroughShafts, forKey: Self.seeThroughShaftsKey) }
            recomposeSite()
        }
    }
    static let seeThroughShaftsKey = "seeThroughShafts"
    /// Class and reputation (Phase 11, 4 Hz), progress panel and the latest promotion.
    var progression = ProgressionSummary()
    var showProgressPanel = false
    var promotionNotice: String?
    /// Served electricity per room (Phase 12, 4 Hz): lights need power.
    @ObservationIgnored var electricityServed: [RoomID: Double] = [:]
    /// Current lighting load and today's metered energy of the active property (4 Hz).
    var lightingKW = 0.0
    var lightingKWhToday = 0.0
    /// Today's weather and forecast (Phase 13, 4 Hz).
    var weather: WeatherSummary?
    /// Fires and incidents (Phase 14, 4 Hz), the incidents panel and the latest alert.
    var incidents = IncidentSummary()
    /// Properties, cities and land for sale (Phase 15), and the estate panel.
    var estate = EstateSummary()
    var showEstatePanel = false
    /// The scenario being played (Phase 16, 4 Hz; nil = free play), its panel, the browser
    /// and the result screen.
    var scenario: ScenarioSummary?
    var showScenarioPanel = false
    var showScenarioBrowser = false
    var selectedScenarioID: String?
    var showScenarioResult = false
    @ObservationIgnored var seenScenarioResult: ScenarioResult?
    /// The completion record (Phase C): best stars and points per scenario on this device;
    /// `scenarioNewBest` when the announced result beat the previous best.
    var scenarioRecords = ScenarioRecords()
    var scenarioNewBest = false
    /// The main menu was opened over a running game: it offers Resume (F4).
    var menuOverGame = false
    /// The narrow build palette's open category (F5, iPhone).
    var paletteCategory: String?
    /// The panel picker of the narrow view controls (F5, iPhone).
    var showPanelPicker = false
    /// Text size of the panels and menus (F4). nil follows the system (Dynamic Type on an
    /// iPad); a Mac has no system setting, so the player picks one here.
    var textSize: DynamicTypeSize? = nil {
        didSet {
            UIText.macScale = UIText.factor(textSize)
            if persistsModSettings { UserDefaults.standard.set(textSize.map(TextSizeSetting.key), forKey: TextSizeSetting.defaultsKey) }
        }
    }
    /// Help (F3): the manual (loaded once), its sheet and chapter; the tutorial scenario's
    /// steps (4 Hz); the first-time hint on screen and which ones this device has seen.
    @ObservationIgnored var manual: ManualContent?
    var showManual = false
    var manualChapterID: String?
    var manualQuery = ""
    /// Page of the open chapter (the manual pages instead of scrolling, like the saves list).
    var manualPage = 0
    /// The compact manual shows its chapter list instead of the page (F5, iPhone).
    var manualShowContents = false
    var tutorial: TutorialSummary?
    var showTutorialPanel = true
    var activeHint: ManualHint?
    var hintMemory = HintMemory(persists: false)
    var showIncidentsPanel = false
    var incidentNotice: String?
    @ObservationIgnored var seenIncidentID: Int?
    @ObservationIgnored var dismissedFireID: Int?
    @ObservationIgnored var sprinklerRooms: Set<RoomID> = []
    @ObservationIgnored var seenPromotions: Int?
    /// Utility allocation of the active property's buildings, made once per 4 Hz refresh and
    /// shared by the panels and the services overlay (Phase 19).
    @ObservationIgnored var utilityServices: [BuildingID: UtilityService] = [:]
    private(set) var loadError: String?
    private(set) var scene: WorldScene?

    var showGrid = true
    var showDeveloperHUD: Bool
    private(set) var diagnostics = RenderDiagnostics()

    private(set) var activeTool: ConstructionTool?
    private(set) var canUndo = false
    private(set) var canRedo = false
    private(set) var lastSaveDescription: String?
    var alert: AppAlert?
    var showLoadSheet = false

    @ObservationIgnored private(set) var library: ContentLibrary?
    @ObservationIgnored private(set) var engine: ConstructionEngine?
    @ObservationIgnored private var history = ConstructionHistory()
    @ObservationIgnored private(set) var saveStore: SaveStore
    @ObservationIgnored var hasUnsavedChanges = false
    @ObservationIgnored private var autosaveTimer: Timer?
    @ObservationIgnored private var screenshotDirector: AnyObject?
    @ObservationIgnored var simulation: SimulationEngine?
    @ObservationIgnored var host = SimulationHost()
    @ObservationIgnored var speedBeforePause: GameSpeed = .normal
    @ObservationIgnored var lastSimulationMs = 0.0

    /// Mods (Phase 17): the folder, the enabled ids in load order (applied, and being edited
    /// in the mod manager), and what the last load did with every pack.
    @ObservationIgnored var modsDirectory: URL
    @ObservationIgnored var persistsModSettings = true
    var enabledMods: [String]
    var modDraft: [String]
    var packStatuses: [PackStatus] = []
    var showModManager = false
    static let enabledModsKey = "enabledMods"
    /// Save sync with iCloud Drive (Phase 18; off by default), its last result and the
    /// saves panel's page.
    var syncEnabled = false
    var syncStatus = "Saves stay on this device."
    var syncedSlots: Set<String> = []
    var syncConflicts: [String] = []
    var savesPage = 0
    /// Debug captures: a local folder standing in for iCloud Drive.
    @ObservationIgnored var syncFolderOverride: URL?
    /// Whether the app has an iCloud container (needs the iCloud entitlement and a signed-in
    /// account). Without one the saves panel hides the iCloud switch rather than show a
    /// switch that cannot work.
    @ObservationIgnored var iCloudAvailable = false

    static let autosaveInterval: TimeInterval = 120

    init(arguments: [String] = CommandLine.arguments) {
        // Hidden until the player presses ⌥⌘D (no menu item; `DeveloperShortcut`).
        showDeveloperHUD = false
        saveStore = SaveStore(directory: Self.defaultSaveDirectory())
        var mods = Self.defaultModsDirectory()
        var enabled = UserDefaults.standard.stringArray(forKey: Self.enabledModsKey) ?? []
        var persists = true
        var sync = UserDefaults.standard.bool(forKey: Self.syncSavesKey)
        #if DEBUG
        if let config = ScreenshotDirector.Configuration(arguments: arguments) {
            // Captures use their own mods and sync folders and never read or change the
            // player's settings.
            mods = config.directory.appendingPathComponent("mods", isDirectory: true)
            enabled = []
            persists = false
            sync = false
            syncFolderOverride = config.directory.appendingPathComponent("cloud", isDirectory: true)
        }
        #endif
        syncEnabled = sync
        modsDirectory = mods
        enabledMods = enabled
        modDraft = enabled
        persistsModSettings = persists
        hintMemory = HintMemory(persists: persists)
        if persists { textSize = TextSizeSetting.load() }
        if persists { seeThroughShafts = UserDefaults.standard.bool(forKey: Self.seeThroughShaftsKey) }
        loadManual()
        do {
            try reloadContent()
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
        iCloudAvailable = syncFolderOverride != nil || FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
        syncSaves()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: Self.autosaveInterval, repeats: true) { [weak self] _ in
            self?.autosaveIfNeeded()
        }
    }

    /// On a Mac in Application Support (Open Folder shows it in Finder). On an iPad or iPhone
    /// in Documents, which the Files app shows as Skyline Architect ▸ Mods (0.29.2).
    static func defaultModsDirectory() -> URL {
        #if os(iOS)
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Mods", isDirectory: true)
        #else
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Skyline Architect", isDirectory: true).appendingPathComponent("Mods", isDirectory: true)
        #endif
    }

    /// Loads the base pack and the enabled mods (a failing mod is skipped and reported) and
    /// replaces the engines. Throws only when the base pack is invalid. The world is untouched.
    func reloadContent() throws {
        let result = try ModLoader.load(mods: ModLoader.discover(in: modsDirectory), enabled: enabledMods)
        library = result.library
        engine = ConstructionEngine(catalog: result.library.buildCatalog)
        simulation = SimulationEngine(rules: result.library.simulationRules, catalog: result.library.buildCatalog)
        packStatuses = result.packs
    }

    static func defaultSaveDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Skyline Architect", isDirectory: true).appendingPathComponent("Saves", isDirectory: true)
    }

    var catalog: BuildCatalog? { engine?.catalog }
    var art: ArtCatalog { library?.artCatalog ?? .empty }
    /// The palette with the view settings that change the building art (0.30).
    var palette: ArtPalette {
        var p = ArtPalette.standard
        p.seeThroughShafts = seeThroughShafts
        return p
    }

    // MARK: Game lifecycle

    private func startNewGame(startID: String = NewGameFactory.defaultStartID) throws {
        guard let library else { return }
        let game = try NewGameFactory.make(startID: startID, library: library)
        install(world: game.world, activePropertyID: game.activePropertyID)
    }

    /// A new game from a start (default: the standard game, unlocks by building class).
    func newGame(startID: String = NewGameFactory.standardStartID) {
        do { try startNewGame(startID: startID) } catch { alert = AppAlert(title: "Could not start a new game", message: "\(error)") }
    }

    /// Replaces the world and builds a fresh scene for it (also used to switch to another
    /// property, then without keeping the camera).
    func install(world: GameWorld, activePropertyID: PropertyID, keepCamera: Bool = true) {
        var world = world
        if let library {
            Estate.adoptLegacy(&world, library: library)
            PopulationSync.sync(&world, catalog: library.buildCatalog, rules: library.simulationRules)
        }
        simulation?.replanAfterConstruction(&world)     // also creates elevator cars
        // Plan every unit's access route now, while loading, rather than in the first daily
        // closing (a one-off ~0.9 s at 500 floors). The engine is not thread-safe, so this
        // stays on the main thread.
        simulation?.warmRouteCache(world)
        self.world = world
        self.activePropertyID = activePropertyID
        showMainMenu = false
        menuOverGame = false
        seenPromotions = nil
        promotionNotice = nil
        seenIncidentID = nil
        incidentNotice = nil
        // A result decided before this world was installed (a loaded save) is not announced.
        seenScenarioResult = world.scenario?.result
        showScenarioResult = false
        let property = world.properties[activePropertyID]
        propertyName = property?.name ?? "—"
        cityName = property.flatMap { world.cities[$0.cityID]?.name } ?? "—"
        refreshSimulationSummary()
        history.clear()
        refreshUndoState()
        hasUnsavedChanges = false
        activeTool = nil
        guard let composition = SiteComposer.compose(world: world, propertyID: activePropertyID, catalog: catalog, art: art, palette: palette) else {
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
            let rules = self.simulation?.rules
            return RoomLabels.build(world: world, propertyID: property, catalog: catalog, visible: visible, zoom: zoom,
                                    text: self.roomLabelText,
                                    stops: { room in
                                        guard let rules, world.elevators.contains(room.id) else { return nil }
                                        return ElevatorStops.served(room, world: world, rules: rules)
                                    })
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
        scene.servicesProvider = { [weak self] in self?.serviceMarks() }
        installEnvironment(on: scene)
        if let previous {
            scene.onReady = previous.onReady
            // Keep the camera where the player was looking (not when changing property).
            let cam = previous.controller.camera
            if keepCamera { scene.initialPlacement = (cam.center, cam.zoom) }
        }
        self.scene = scene
    }

    // MARK: Construction

    func select(tool: ConstructionTool?) {
        activeTool = tool
        scene?.activeTool = tool
        toolHint(tool)
    }

    func handleToolKey(_ key: String) {
        switch key {
        case "floor": select(tool: activeTool == .floor ? nil : .floor)
        case "demolish": select(tool: activeTool == .demolish ? nil : .demolish)
        case "pause": togglePause()
        case "speed1": setSpeed(.normal)
        case "speed2": setSpeed(.double)
        case "speed3": setSpeed(.quadruple)
        case "speed4": setSpeed(.fast)
        case "speed5": setSpeed(.faster)
        case "speed6": setSpeed(.fastest)
        default:
            handleEscape()
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
            // Developer tool: grant whatever the blueprint costs beyond the cash at hand
            // (priced step by step on a copy, since later steps build on earlier ones).
            var dryRun = world
            var cost = 0
            for c in blueprint.commands(for: building) {
                cost += max((try? engine.apply(c, to: &dryRun).plan.cost) ?? 0, 0)
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
    /// Footprints and foundations of a property's buildings: when they change, the site is
    /// composed anew (`commit`).
    private static func groundwork(_ world: GameWorld, property: PropertyID?) -> [Building.Groundwork] {
        property.map { world.buildings(on: $0).map(\.groundwork) } ?? []
    }

    private func commit(_ newWorld: GameWorld, plan: ConstructionPlan?) {
        var newWorld = newWorld
        if let library { PopulationSync.sync(&newWorld, catalog: library.buildCatalog, rules: library.simulationRules) }
        // Trips through removed stairs are re-planned now, so even a paused game is consistent.
        simulation?.replanAfterConstruction(&newWorld)
        let before = world.map { Self.groundwork($0, property: scene?.composition.propertyID) }
        world = newWorld
        hasUnsavedChanges = true
        refreshUndoState()
        guard let scene else { return }
        // A changed foundation can change the ground section itself: compose the site anew.
        if before != Self.groundwork(newWorld, property: scene.composition.propertyID),
           let fresh = SiteComposer.compose(world: newWorld, propertyID: scene.composition.propertyID, catalog: catalog, art: art, palette: palette) {
            scene.replaceComposition(fresh)
            return
        }
        let composition = SiteComposer.recompose(scene.composition, world: newWorld, catalog: catalog, art: art, palette: palette)
        scene.updateComposition(composition, dirty: plan.map { SiteComposer.dirtyRect(for: $0, grid: newWorld.grid) })
    }

    /// Composes the whole site anew (a view setting that changes the building art).
    func recomposeSite() {
        guard let world, let scene,
              let fresh = SiteComposer.compose(world: world, propertyID: scene.composition.propertyID, catalog: catalog, art: art, palette: palette)
        else { return }
        scene.replaceComposition(fresh)
    }

    private func refreshUndoState() {
        canUndo = history.canUndo
        canRedo = history.canRedo
    }

    // MARK: Saving

    var packReferences: [ContentPackReference] {
        library?.packs.map { ContentPackReference(id: $0.id, version: $0.version, hash: $0.contentHash) } ?? []
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
            syncSaves()
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
            let catalog = library?.buildCatalog
            let save = try saveStore.load(slot: slot, availablePacks: packReferences,
                                          isShaft: { catalog?.spec($0)?.kind == .shaft })
            install(world: save.world, activePropertyID: save.activePropertyID)
            lastSaveDescription = "Loaded “\(slot)”"
            let changed = SaveCodec.changedPacks(in: save, availablePacks: packReferences)
            if !changed.isEmpty {
                alert = AppAlert(title: "Content has changed since this save",
                                 message: "The game loaded, but some content may not match the world: " + changed.joined(separator: "; ") + ".")
            }
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
}
