import SwiftUI
import SkylinePresentation

@main
struct SkylineArchitectApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        #if os(macOS)
        Window("Skyline Architect", id: "main") {
            RootView(model: model)
                .frame(minWidth: 960, minHeight: 600)
        }
        .defaultSize(width: 1440, height: 900)
        .commands { GameCommands(model: model) }
        #else
        WindowGroup {
            RootView(model: model)
        }
        #endif
    }
}

/// Native menu items with keyboard shortcuts for simulation-view controls.
struct GameCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button(model.showGrid ? "Hide Architectural Grid" : "Show Architectural Grid") { model.toggleGrid() }
                .keyboardShortcut("g", modifiers: [.command, .option])
            Button(model.showDeveloperHUD ? "Hide Developer HUD" : "Show Developer HUD") { model.showDeveloperHUD.toggle() }
                .keyboardShortcut("d", modifiers: [.command, .option])
            Divider()
            Button("Zoom In") { model.zoom(by: 1.5) }
                .keyboardShortcut("=", modifiers: .command)
            Button("Zoom Out") { model.zoom(by: 1 / 1.5) }
                .keyboardShortcut("-", modifiers: .command)
            Button("Reset View") { model.apply(.overview) }
                .keyboardShortcut("0", modifiers: .command)
            Divider()
            Button("Site Overview") { model.apply(.overview) }
                .keyboardShortcut("1", modifiers: .command)
            Button("Foundation") { model.apply(.foundation) }
                .keyboardShortcut("2", modifiers: .command)
            Button("Detail Close-up") { model.apply(.detail) }
                .keyboardShortcut("3", modifiers: .command)
            Button("Skyline") { model.apply(.skyline) }
                .keyboardShortcut("4", modifiers: .command)
        }
    }
}
