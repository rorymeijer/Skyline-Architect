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
        CommandGroup(replacing: .newItem) {
            Button("New Game") { model.newGame() }
                .keyboardShortcut("n", modifiers: .command)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { model.save() }
                .keyboardShortcut("s", modifiers: .command)
            Button("Load Game…") { model.showLoadSheet = true }
                .keyboardShortcut("o", modifiers: .command)
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo Construction") { model.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.canUndo)
            Button("Redo Construction") { model.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!model.canRedo)
        }
        CommandMenu("Build") {
            Button("Floor Tool") { model.handleToolKey("floor") }
            Button("Demolish Tool") { model.handleToolKey("demolish") }
            Button("Stop Building") { model.select(tool: nil) }
            #if DEBUG
            Divider()
            Button("Developer: Build Demo Tower") { model.applyBlueprint("demo-tower") }
            #endif
        }
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
