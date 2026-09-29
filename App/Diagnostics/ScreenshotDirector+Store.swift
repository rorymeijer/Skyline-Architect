#if DEBUG
import Foundation
import SkylineCore

/// The App Store screenshots (`--capture-set store`, 0.29.2): real game scenes on the Demo
/// Plaza (developer blueprint, leased by the developer tool) and the tutorial, with the game's
/// own interface. Weather is set to clear by the script.
extension ScreenshotDirector {
    static let storeSteps: [Step] = [
        Step(name: "01-lunch", grid: false) { model, scene in
            model.setSpeed(.paused)  // captures advance time explicitly
            model.showDeveloperHUD = false
            model.showMainMenu = false
            closePanels(model)
            model.applyBlueprint("demo-plaza")
            model.leaseAllVacant()
            model.advanceSimulation(toTimeOfDay: 12, minute: 40)
            force("clear", 21, model: model)
            quiet(model)
            scene.withController { $0.jump(center: point(model, column: 16, floor: 2.2), zoom: 19) }
            return "\(model.clockText): lunch in the Demo Plaza. " + amenityNote(model)
        },
        Step(name: "02-evening", grid: false) { model, scene in
            model.advanceSimulation(toTimeOfDay: 20, minute: 15)
            force("clear", 18, model: model)
            quiet(model)
            scene.withController { $0.jump(center: point(model, column: 16, floor: 2.2), zoom: 19) }
            return "\(model.clockText): the evening, lit up. " + amenityNote(model)
        },
        Step(name: "03-elevators", grid: false) { model, scene in
            model.advanceSimulation(toTimeOfDay: 8, minute: 40)
            force("clear", 16, model: model)
            model.showTraffic = true
            model.showBanksPanel = true
            quiet(model)
            scene.withController { $0.jump(center: point(model, column: 8, floor: 4), zoom: 15) }
            return "\(model.clockText): the morning rush with the traffic overlay and the Elevator Banks panel."
        },
        Step(name: "04-restaurant", grid: false) { model, scene in
            model.showTraffic = false
            model.showBanksPanel = false
            model.advanceSimulation(toTimeOfDay: 13, minute: 10)
            force("clear", 22, model: model)
            if let r = amenityRoom(model, "restaurant") { model.selectRoom(at: cell(of: r)) }
            quiet(model)
            scene.withController { $0.jump(center: point(model, column: 16, floor: 2.2), zoom: 19) }
            return "\(model.clockText): the restaurant selected: its tenant, takings and services."
        },
        Step(name: "05-tutorial", grid: false) { model, scene in
            closePanels(model)
            model.startTutorial()
            _ = buildTutorialSteps(model)
            model.showTutorialPanel = true
            model.paletteCategory = "office"
            quiet(model)
            scene.withController { $0.jump(center: point(model, column: 16, floor: 1), zoom: 11) }
            return "The tutorial after its construction steps: \(tutorialNote(model))."
        },
        Step(name: "06-scenarios", grid: false) { model, _ in
            model.paletteCategory = nil
            model.openScenarioBrowser()
            return "The scenario browser."
        },
    ]

    /// No tip, promotion or incident banner over a store picture.
    private static func quiet(_ model: AppModel) {
        model.refreshSimulationSummary()
        model.activeHint = nil
        model.promotionNotice = nil
        model.incidentNotice = nil
    }
}
#endif
