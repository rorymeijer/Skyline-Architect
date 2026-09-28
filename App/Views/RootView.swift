import SwiftUI
import SkylinePresentation

struct RootView: View {
    let model: AppModel

    var body: some View {
        if let scene = model.scene {
            ZStack(alignment: .topLeading) {
                WorldView(scene: scene, onToggleGrid: { model.toggleGrid() }, onToolKey: { model.handleToolKey($0) })
                    .ignoresSafeArea()
                ChromeOverlay(model: model)
            }
            .alert(model.alert?.title ?? "", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
                Button("OK", role: .cancel) { model.alert = nil }
            } message: {
                Text(model.alert?.message ?? "")
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                Text("Skyline Architect could not start")
                    .font(.headline)
                Text(model.loadError ?? "Unknown error")
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// All SwiftUI chrome drawn over the world. Also rendered by the screenshot director.
struct ChromeOverlay: View {
    let model: AppModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 10) {
                TitleBadge(model: model)
                if model.showDeveloperHUD {
                    DevHUDView(diagnostics: model.diagnostics, population: model.population, simulationMs: model.lastSimulationMs,
                               navigation: model.navigationMetrics)
                }
            }
            .padding(12)
            ViewControls(model: model)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            VStack(alignment: .trailing, spacing: 8) {
                if let report = model.unitReport {
                    UnitInspector(report: report) { model.selectRoom(at: nil) }
                }
                if model.showScenarioPanel {
                    ScenarioPanel(model: model)
                }
                if model.showEstatePanel {
                    EstatePanel(model: model)
                }
                if model.showIncidentsPanel {
                    IncidentsPanel(model: model)
                }
                if model.showProgressPanel {
                    ProgressPanel(model: model)
                }
                if model.showEconomyPanel {
                    EconomyPanel(model: model)
                }
                if model.showFacilitiesPanel {
                    FacilitiesPanel(model: model)
                }
                if model.showLeasingPanel {
                    LeasingPanel(summary: model.leasing) { model.showLeasingPanel = false }
                }
                if model.showBanksPanel {
                    ElevatorBanksPanel(model: model)
                }
            }
            .padding(.top, 60)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            SimulationControls(model: model)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .top)
            VStack(spacing: 8) {
                if let alert = model.incidentNotice {
                    IncidentBanner(text: alert, fire: !model.incidents.fires.isEmpty, show: { model.showIncident() },
                                   close: { model.dismissIncidentNotice() })
                }
                if let notice = model.promotionNotice {
                    PromotionBanner(text: notice) { model.promotionNotice = nil }
                }
                StatusPill(model: model)
                BuildPalette(model: model)
            }
            .padding(.bottom, 58)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            if model.showLoadSheet {
                SavesPanel(model: model)
            } else if model.showModManager {
                ModManagerView(model: model)
            } else if model.showScenarioBrowser {
                ScenarioBrowserView(model: model)
            } else if model.showScenarioResult {
                ScenarioResultView(model: model)
            } else if model.economy.bankrupt {
                BankruptcyView(model: model)
            } else if model.showMainMenu {
                MainMenuView(model: model)
            }
        }
    }
}

/// Property / city identification in the top-left corner.
struct TitleBadge: View {
    let model: AppModel

    private var mode: String {
        if model.scenario != nil { return "Scenario" }
        return model.progression.byClass ? "Standard" : "Sandbox"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.propertyName)
                .font(.headline)
            Text("\(model.cityName) · \(mode) · Phase 20")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Floating camera controls (bottom-right). Mirrors the View menu for touch users.
/// Drawn entirely in SwiftUI (no AppKit-backed controls) so it renders identically in
/// the window and in automated captures.
struct ViewControls: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 2) {
            ControlButton(symbol: "minus.magnifyingglass", help: "Zoom Out (⌘−)") { model.zoom(by: 1 / 1.5) }
            ControlButton(symbol: "plus.magnifyingglass", help: "Zoom In (⌘=)") { model.zoom(by: 1.5) }
            separator
            ControlButton(symbol: "map", help: "Site Overview (⌘1)") { model.apply(.overview) }
            ControlButton(symbol: "building.columns", help: "Foundation (⌘2)") { model.apply(.foundation) }
            ControlButton(symbol: "scope", help: "Detail Close-up (⌘3)") { model.apply(.detail) }
            ControlButton(symbol: "building.2", help: "Skyline (⌘4)") { model.apply(.skyline) }
            separator
            ControlButton(symbol: "square.grid.3x3", help: "Architectural Grid (G, ⌥⌘G)", isOn: model.showGrid) { model.toggleGrid() }
            ControlButton(symbol: "arrow.up.arrow.down", help: "Elevator Traffic (⌥⌘T)", isOn: model.showTraffic) { model.showTraffic.toggle() }
            ControlButton(symbol: "slider.horizontal.3", help: "Elevator Banks (⌥⌘E)", isOn: model.showBanksPanel) { model.showBanksPanel.toggle() }
            if model.scenario != nil {
                ControlButton(symbol: "flag.checkered", help: "Objectives (⌥⌘O)", isOn: model.showScenarioPanel) { model.showScenarioPanel.toggle() }
            }
            ControlButton(symbol: "globe.europe.africa", help: "Estate (⌥⌘K)", isOn: model.showEstatePanel) { model.toggleEstatePanel() }
            ControlButton(symbol: "flame", help: "Incidents (⌥⌘I)", isOn: model.showIncidentsPanel) { model.showIncidentsPanel.toggle() }
            ControlButton(symbol: "rosette", help: "Standing (⌥⌘P)", isOn: model.showProgressPanel) { model.showProgressPanel.toggle() }
            ControlButton(symbol: "key", help: "Leasing (⌥⌘L)", isOn: model.showLeasingPanel) { model.showLeasingPanel.toggle() }
            ControlButton(symbol: "banknote", help: "Economy (⌥⌘M)", isOn: model.showEconomyPanel) { model.showEconomyPanel.toggle() }
            ControlButton(symbol: "wrench.and.screwdriver", help: "Facilities (⌥⌘F)", isOn: model.showFacilitiesPanel) { model.showFacilitiesPanel.toggle() }
            ControlButton(symbol: "bolt.horizontal", help: "Services overlay (⌥⌘U)", isOn: model.showServices) { model.showServices.toggle() }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
        .environment(\.colorScheme, .dark)
    }

    private var separator: some View {
        Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 18).padding(.horizontal, 4)
    }
}

private struct ControlButton: View {
    let symbol: String
    let help: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 32, height: 28)
                .foregroundStyle(isOn ? Color.accentColor : Color.white.opacity(0.9))
                .contentShape(Rectangle())
        }
        .buttonStyle(ControlButtonStyle())
        .help(help)
        // "Elevator Traffic (⌥⌘T)" → "Elevator Traffic"; toggles report their state.
        .accessibilityLabel(help.components(separatedBy: " (").first ?? help)
        .accessibilityValue(isOn ? "On" : "")
    }
}

private struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0)))
    }
}
