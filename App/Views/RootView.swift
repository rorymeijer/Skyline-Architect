import SwiftUI
import SkylinePresentation

struct RootView: View {
    let model: AppModel

    var body: some View {
        if let scene = model.scene {
            ZStack(alignment: .topLeading) {
                WorldView(scene: scene, onToggleGrid: { model.toggleGrid() }, onToolKey: { model.handleToolKey($0) })
                    .ignoresSafeArea()
                DeveloperShortcut(model: model)
                EscapeShortcut(model: model)
                ChromeOverlay(model: model)
                    .textSize(model.textSize)
                    .id(model.textSize)                              // Mac fonts are read when views are built
            }
            .alert(model.alert?.title ?? "", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
                Button("OK", role: .cancel) { model.alert = nil }
            } message: {
                Text(model.alert?.message ?? "")
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.ui(.largeTitle))
                Text("Skyline Architect could not start")
                    .font(.ui(.headline))
                Text(model.loadError ?? "Unknown error")
                    .font(.ui(.callout).monospaced())
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
                if let tutorial = model.tutorial, model.showTutorialPanel, !model.showDeveloperHUD {
                    TutorialPanel(model: model, tutorial: tutorial)
                }
                if model.showDeveloperHUD {
                    DevHUDView(diagnostics: model.diagnostics, population: model.population, simulationMs: model.lastSimulationMs,
                               navigation: model.navigationMetrics)
                }
            }
            .padding(12)
            ViewControls(model: model)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            if model.showPanelPicker {
                PanelPicker(model: model)
                    .padding(.trailing, 12)
                    .padding(.bottom, 52)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            // Above the view controls (bottom right); tabs when the panels do not all fit.
            PanelStack(model: model)
                .padding(.top, 60)
                .padding(.trailing, 12)
                .padding(.bottom, 56)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            SimulationControls(model: model)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .top)
            if let hint = model.activeHint {
                HintBubble(model: model, hint: hint)
                    .padding(.top, 60)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
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
            if model.showManual {
                ManualView(model: model)
            } else if model.showLoadSheet {
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
                .font(.ui(.headline))
            Text("\(model.cityName) · \(mode)")
                .font(.ui(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// The developer HUD has no menu item or button: only ⌥⌘D shows or hides it. An invisible,
/// zero-size button carries the shortcut (hidden views lose theirs), on macOS and on an iPad
/// with a keyboard.
private struct DeveloperShortcut: View {
    let model: AppModel

    var body: some View {
        Button("") { model.showDeveloperHUD.toggle() }
            .keyboardShortcut("d", modifiers: [.command, .option])
            .buttonStyle(.plain)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

/// Esc closes what is on top (F4, `AppModel.handleEscape`), wherever the keyboard focus is:
/// an invisible button carries the shortcut, like the developer HUD's.
private struct EscapeShortcut: View {
    let model: AppModel

    var body: some View {
        Button("") { model.handleEscape() }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.plain)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)
    }
}
