#if DEBUG
import Foundation
import SkylineCore
import SkylineContent

/// The screen tour (0.29.2): every full-screen view and side panel once, on the Mac, the iPad
/// and the iPhone, to check that each fits the screen. Panels open one at a time, except in
/// the step that opens three to show the tabs.
extension ScreenshotDirector {
    static let tourSteps: [Step] = [
        Step(name: "01-main-menu", grid: false) { model, _ in
            model.setSpeed(.paused)  // captures advance time explicitly
            model.showDeveloperHUD = false
            model.showMainMenu = true
            return "The main menu (\(platform))."
        },
        Step(name: "02-scenarios", grid: false) { model, _ in
            model.openScenarioBrowser()
            return "The scenario browser."
        },
        Step(name: "03-mods", grid: false) { model, _ in
            model.showScenarioBrowser = false
            model.openModManager()
            return "The mod manager."
        },
        Step(name: "04-demo-tower", grid: false) { model, scene in
            model.showModManager = false
            model.newGame()
            model.showMainMenu = false
            model.setSpeed(.paused)
            model.applyBlueprint("demo-tower")
            model.leaseAllVacant()
            model.advanceSimulation(toTimeOfDay: 10)
            _ = model.save()
            model.activeHint = nil
            model.refreshSimulationSummary()
            model.activeHint = nil
            scene.withController { $0.jump(center: point(model, column: 16, floor: 4), zoom: 11) }
            return "\(model.clockText): the demo tower (developer blueprint, leased by the developer tool), no panel open; quick-saved for the next step."
        },
        Step(name: "05-saves", grid: false) { model, _ in
            model.openSavesPanel()
            return "The saves panel."
        },
        Step(name: "06-unit", grid: false) { model, _ in
            model.showLoadSheet = false
            return "The unit inspector: \(select(model, "office-small"))."
        },
        panel("07-leasing", "Leasing") { $0.showLeasingPanel = true },
        panel("08-economy", "Economy") { $0.showEconomyPanel = true },
        panel("09-facilities", "Facilities") { $0.showFacilitiesPanel = true },
        panel("10-standing", "Standing") { $0.showProgressPanel = true },
        panel("11-estate", "Estate") { $0.toggleEstatePanel() },
        panel("12-elevators", "Elevator Banks") { $0.showBanksPanel = true },
        panel("13-foundation", "Foundation") { $0.toggleFoundationPanel() },
        panel("14-incidents", "Incidents, with a fire set by the developer tool") { model in
            model.igniteFirstOffice()
            model.advanceSimulation(ticks: 90)
            model.showIncidentsPanel = true
        },
        Step(name: "15-tip", grid: false) { model, _ in
            closePanels(model)
            model.dismissIncidentNotice()
            model.activeHint = model.manual?.hint("first-tenant")
            return "A first-time tip (set by the script)."
        },
        Step(name: "16-three-panels", grid: false) { model, _ in
            model.activeHint = nil
            model.showEconomyPanel = true
            model.showFacilitiesPanel = true
            model.showLeasingPanel = true
            return "Economy, Facilities and Leasing open at once."
        },
        Step(name: "17-manual-search", grid: false) { model, _ in
            closePanels(model)
            model.openManual()
            model.manualShowContents = true
            model.manualQuery = "elevator"
            return "The manual searching for 'elevator'."
        },
        Step(name: "18-scenario-result", grid: false) { model, _ in
            model.manualQuery = ""
            model.showManual = false
            model.startScenario("opening-day")
            model.setSpeed(.paused)
            if var world = model.world {
                world.scenario?.result = ScenarioResult(won: true, tick: world.clock.tick, reason: "All objectives met",
                                                        stars: 3, score: 1250)
                model.world = world
            }
            model.refreshScenario()
            return "The result screen (a won result set by the script on Opening Day)."
        },
        Step(name: "19-bankruptcy", grid: false) { model, _ in
            model.showScenarioResult = false
            if var world = model.world {
                world.ledger.bankrupt = true
                model.world = world
            }
            model.refreshEconomy()
            return "The bankruptcy screen (set by the script)."
        },
        Step(name: "20-elevator-stops", grid: false) { model, scene in
            // 0.30: a stairwell in front of rooms, and an elevator passing two floors.
            model.newGame()
            model.showMainMenu = false
            model.setSpeed(.paused)
            model.applyBlueprint("demo-tower")
            let stairs = stairsThroughRooms(model)
            let selected = select(model, "elevator-shaft")
            for floor in [3, 5] { model.setStop(floor, served: false) }
            if let shaft = shaft(model), let b = model.world?.buildings[shaft.buildingID] {
                let column = shaft.columns.start - b.footprint.start
                scene.withController { $0.jump(center: point(model, column: column + 4, floor: 4.5), zoom: 16) }
            }
            return "\(selected); floors 3 and 5 switched off (no number in the shaft). Stairwell: \(stairs)"
        },
        Step(name: "21-see-through-shafts", grid: false) { model, _ in
            model.seeThroughShafts = true
            return "The same view with see-through elevator shafts (the rooms behind show through)."
        },
    ]

    /// A step that closes the other side panels and opens one.
    private static func panel(_ name: String, _ title: String, open: @escaping (AppModel) -> Void) -> Step {
        Step(name: name, grid: false) { model, _ in
            closePanels(model)
            open(model)
            model.refreshSimulationSummary()
            model.activeHint = nil
            return "The \(title) panel."
        }
    }

    static func closePanels(_ model: AppModel) {
        model.selectRoom(at: nil)
        model.showFoundationPanel = false
        model.showScenarioPanel = false
        model.showEstatePanel = false
        model.showIncidentsPanel = false
        model.showProgressPanel = false
        model.showEconomyPanel = false
        model.showFacilitiesPanel = false
        model.showLeasingPanel = false
        model.showBanksPanel = false
        model.showTutorialPanel = false
    }

    /// Selects the lowest room of a kind, like a tap on it.
    static func select(_ model: AppModel, _ definition: String) -> String {
        guard let room = model.world?.rooms.values.filter({ $0.definitionID == definition })
            .min(by: { ($0.floors.lowest, $0.id) < ($1.floors.lowest, $1.id) }) else { return "no \(definition)" }
        model.selectRoom(at: GridCell(column: room.columns.start, floor: room.floors.lowest))
        return "\(definition) on floor \(room.floors.lowest) selected"
    }
}
#endif
