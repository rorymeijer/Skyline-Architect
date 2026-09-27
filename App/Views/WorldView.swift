import SpriteKit
import SwiftUI

/// Hosts the SpriteKit world in SwiftUI. The scene is owned by `AppModel`, so SwiftUI
/// re-rendering never recreates it.
#if os(macOS)
struct WorldView: NSViewRepresentable {
    let scene: WorldScene
    let onToggleGrid: () -> Void
    let onToolKey: (String) -> Void

    func makeNSView(context: Context) -> GameSKView {
        let view = GameSKView(frame: .zero)
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 120
        view.onToggleGrid = onToggleGrid
        view.onToolKey = onToolKey
        view.presentScene(scene)
        return view
    }

    /// A loaded game gets a new scene; present it in the existing view.
    func updateNSView(_ view: GameSKView, context: Context) {
        if view.scene !== scene {
            scene.backingScale = view.window?.backingScaleFactor ?? 2
            view.presentScene(scene)
        }
    }
}
#else
struct WorldView: UIViewRepresentable {
    let scene: WorldScene
    let onToggleGrid: () -> Void
    let onToolKey: (String) -> Void

    func makeUIView(context: Context) -> GameSKView {
        let view = GameSKView(frame: .zero)
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 120
        view.onToggleGrid = onToggleGrid
        view.onToolKey = onToolKey
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: GameSKView, context: Context) {
        if view.scene !== scene {
            scene.backingScale = view.window?.screen.scale ?? view.contentScaleFactor
            view.presentScene(scene)
        }
    }
}
#endif
