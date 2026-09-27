import SpriteKit
import SwiftUI

/// Hosts the SpriteKit world in SwiftUI. The scene is owned by `AppModel`, so SwiftUI
/// re-rendering never recreates it.
#if os(macOS)
struct WorldView: NSViewRepresentable {
    let scene: WorldScene
    let onToggleGrid: () -> Void

    func makeNSView(context: Context) -> GameSKView {
        let view = GameSKView(frame: .zero)
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 120
        view.onToggleGrid = onToggleGrid
        view.presentScene(scene)
        return view
    }

    func updateNSView(_ view: GameSKView, context: Context) {}
}
#else
struct WorldView: UIViewRepresentable {
    let scene: WorldScene
    let onToggleGrid: () -> Void

    func makeUIView(context: Context) -> GameSKView {
        let view = GameSKView(frame: .zero)
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 120
        view.onToggleGrid = onToggleGrid
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: GameSKView, context: Context) {}
}
#endif
