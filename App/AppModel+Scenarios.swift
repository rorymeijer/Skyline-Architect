import Foundation
import SkylineContent
import SkylineCore
import SkylinePersistence

extension AppModel {
    // MARK: Scenarios (Phase 16)

    var scenarioBriefs: [ScenarioBrief] { library.map { ScenarioBrief.all(library: $0) } ?? [] }

    /// Live objectives; announces a result once (pausing the game) when a closing decides it.
    func refreshScenario() {
        guard let world, let simulation, let library else { return }
        scenario = ScenarioSummary.make(world: world, engine: simulation, library: library)
        if let result = world.scenario?.result, result != seenScenarioResult {
            seenScenarioResult = result
            recordScenarioResult(result)
            showScenarioResult = true
            if speed != .paused { setSpeed(.paused) }
        }
    }

    // MARK: Completion record (Phase C)

    var scenarioRecordStore: ScenarioRecordStore { ScenarioRecordStore(directory: saveStore.directory) }

    func loadScenarioRecords() {
        scenarioRecords = scenarioRecordStore.load()
    }

    /// Counts a result just decided in this session (once; a loaded save's result is not).
    private func recordScenarioResult(_ result: ScenarioResult) {
        guard let s = world?.scenario else { return }
        var records = scenarioRecordStore.load()
        let days = Int(SimClock.day(result.tick)) - Int(s.startDay ?? 0)
        scenarioNewBest = records.add(scenarioID: s.id, result: result, days: max(days, 0), at: Date()) && result.won
        scenarioRecords = records
        try? scenarioRecordStore.save(records)
        if syncEnabled { syncSaves() }
    }

    func openScenarioBrowser() {
        loadScenarioRecords()
        if selectedScenarioID == nil { selectedScenarioID = scenarioBriefs.first?.id }
        showScenarioResult = false
        showScenarioBrowser = true
    }

    /// Starts a scenario from its start, with its objectives shown.
    func startScenario(_ id: String) {
        guard let library else { return }
        do {
            let game = try NewGameFactory.make(scenarioID: id, library: library)
            install(world: game.world, activePropertyID: game.activePropertyID, keepCamera: false)
        } catch {
            alert = AppAlert(title: "Could not start the scenario", message: "\(error)")
            return
        }
        showScenarioBrowser = false
        showMainMenu = false
        showScenarioPanel = true
        setSpeed(.normal)
    }

    /// After the result: the game goes on as free play on the same estate.
    func keepPlaying() {
        showScenarioResult = false
        setSpeed(.normal)
    }

    func returnToMainMenu() {
        showScenarioResult = false
        showScenarioBrowser = false
        showMainMenu = true
        setSpeed(.paused)
    }
}
