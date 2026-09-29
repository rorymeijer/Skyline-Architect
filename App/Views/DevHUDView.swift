import SwiftUI
import SkylineSimulation

/// Developer diagnostics overlay, shown only with ⌥⌘D. Updated at 4 Hz.
struct DevHUDView: View {
    let diagnostics: RenderDiagnostics
    var population = PopulationSummary()
    var simulationMs = 0.0
    var navigation = NavigationMetrics()

    var body: some View {
        let d = diagnostics
        VStack(alignment: .leading, spacing: 3) {
            Text("DEVELOPER")
                .font(.ui(.caption2).weight(.bold))
                .foregroundStyle(.secondary)
            row("FPS", String(format: "%.0f  (%.1f ms)", d.fps, d.frameTimeMs))
            row("Scene update", String(format: "%.2f ms", d.sceneUpdateMs))
            row("Nodes", "\(d.nodeCount)")
            row("Tiles", "L\(d.tileLevel) · \(d.tilesVisible) shown · \(d.tilesCached) cached · \(d.tilesPending) pending")
            row("Rasterized", String(format: "%d tiles · %.1f ms avg", d.tilesRasterized, d.tileRasterMs))
            row("Memory", String(format: "%.0f MB", d.memoryMB))
            row("People", "\(d.agentsRendered) drawn · \(population.total) simulated")
            row("Simulation", String(format: "%.2f ms/frame", simulationMs))
            row("Paths", String(format: "%d queries · %.0f%% cached · %d failed", navigation.queries,
                                navigation.hitRate * 100, navigation.failures))
            row("Nav graph", "\(navigation.portals) portals · \(navigation.edges) links · \(navigation.graphBuilds) builds")
            row("Unreachable", "\(population.unreachable) people")
            row("Elevators", "\(population.cars) cars · \(population.riding) riding · \(population.waiting) waiting")
            row("Longest wait", population.waiting == 0 ? "—" : "\(population.longestWait) s")
            Divider()
            row("Zoom", String(format: "%.2f pt/m", d.zoom) + " · " + d.detailLevel)
            row("Center", String(format: "%.1f m, %.1f m", d.centerX, d.centerY))
            row("Viewport", String(format: "%.0f × %.0f pt @%.0fx", d.viewportWidth, d.viewportHeight, d.backingScale))
            row("Cursor", d.cursorWorld ?? "—")
            row("Cell", d.cursorCell ?? "—")
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(10)
        .frame(width: 360, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .environment(\.colorScheme, .dark)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).foregroundStyle(.secondary).frame(width: 92, alignment: .leading)
            Text(value).foregroundStyle(.primary)
        }
    }
}
