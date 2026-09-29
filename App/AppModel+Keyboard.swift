import Foundation

extension AppModel {
    // MARK: Escape (F4)

    /// Esc closes what is on top, one thing per press: the construction tool, a tip, a
    /// full-screen view (manual, saves, mods, scenarios, the menu over a game), the
    /// selection, then the side panels from the bottom up. Mac and iPad keyboards alike.
    func handleEscape() {
        if activeTool != nil {
            scene?.cancelPlacement()
            select(tool: nil)
        } else if activeHint != nil {
            dismissHint()
        } else if showPanelPicker {
            showPanelPicker = false
        } else if showManual {
            showManual = false
        } else if showLoadSheet {
            showLoadSheet = false
        } else if showModManager {
            showModManager = false
        } else if showScenarioBrowser {
            showScenarioBrowser = false
        } else if showMainMenu {
            if menuOverGame { resumeFromMenu() }
        } else if unitReport != nil {
            selectRoom(at: nil)
        } else {
            closeLastPanel()
        }
    }

    /// Closes the lowest open side panel (the order of `SidePanel`).
    private func closeLastPanel() {
        if showBanksPanel { showBanksPanel = false }
        else if showLeasingPanel { showLeasingPanel = false }
        else if showFacilitiesPanel { showFacilitiesPanel = false }
        else if showEconomyPanel { showEconomyPanel = false }
        else if showProgressPanel { showProgressPanel = false }
        else if showIncidentsPanel { showIncidentsPanel = false }
        else if showEstatePanel { showEstatePanel = false }
        else if showScenarioPanel { showScenarioPanel = false }
        else if showFoundationPanel { showFoundationPanel = false }
        else if showTutorialPanel && tutorial != nil { showTutorialPanel = false }
    }
}
