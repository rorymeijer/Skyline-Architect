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
struct ViewControls: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 6) {
            Button { model.zoom(by: 1 / 1.5) } label: { Image(systemName: "minus.magnifyingglass") }
                .help("Zoom Out (⌘−)")
            Button { model.zoom(by: 1.5) } label: { Image(systemName: "plus.magnifyingglass") }
                .help("Zoom In (⌘=)")
            Divider().frame(height: 18)
            Menu {
                Button("Site Overview") { model.apply(.overview) }
                Button("Foundation") { model.apply(.foundation) }
                Button("Detail Close-up") { model.apply(.detail) }
                Button("Skyline") { model.apply(.skyline) }
            } label: {
                Image(systemName: "viewfinder")
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Camera presets (⌘1–⌘4)")
            Button { model.toggleGrid() } label: {
                Image(systemName: model.showGrid ? "square.grid.3x3.fill" : "square.grid.3x3")
            }
            .help("Architectural grid (G, ⌥⌘G)")
        }
        .buttonStyle(.borderless)
        .font(.title3)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
    }
}
