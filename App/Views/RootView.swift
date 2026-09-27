import SwiftUI
import SkylinePresentation

struct RootView: View {
    let model: AppModel

    var body: some View {
        if let scene = model.scene {
            ZStack(alignment: .topLeading) {
                WorldView(scene: scene, onToggleGrid: { model.toggleGrid() })
                    .ignoresSafeArea()
                ChromeOverlay(model: model)
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
                    DevHUDView(diagnostics: model.diagnostics)
                }
            }
            .padding(12)
            ViewControls(model: model)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}

/// Property / city identification in the top-left corner.
struct TitleBadge: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.activeProperty?.name ?? "—")
                .font(.headline)
            Text("\(model.activeCity?.name ?? "—") · Sandbox · Phase 1 preview")
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
    }
}

private struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0)))
    }
}
