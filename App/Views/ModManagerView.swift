import SwiftUI
import SkylineContent

/// Installed content packs: enable, order, see what each changes or why it failed (Phase 17).
struct ModManagerView: View {
    let model: AppModel

    var body: some View {
        let rows = model.modRows
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Mods").font(.title2.weight(.bold))
                    Spacer()
                    Text("Data-only content packs, loaded in this order").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    ModRowView(model: model, row: row, canMoveUp: row.enabled && index > 1,
                               canMoveDown: row.enabled && index + 1 < rows.count && rows[index + 1].enabled)
                }
                if rows.count == 1 {
                    Text("No mods installed. Put pack folders into the mods folder, or install the examples.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Text(model.modsDirectory.path).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                HStack {
                    MenuButton(title: "Install Examples", subtitle: nil) { model.installExampleMods() }
                    #if os(macOS)
                    MenuButton(title: "Open Folder", subtitle: nil) { model.revealModsFolder() }
                    #endif
                    MenuButton(title: "Rescan", subtitle: nil) { model.rescanMods() }
                }
                HStack {
                    MenuButton(title: "Close", subtitle: nil) { model.showModManager = false }
                    MenuButton(title: "Apply", subtitle: model.hasPendingModChanges ? "Reloads content · unsaved progress is lost" : "No changes") {
                        model.applyMods()
                    }
                    .disabled(!model.hasPendingModChanges)
                    .opacity(model.hasPendingModChanges ? 1 : 0.5)
                }
            }
            .padding(24)
            .frame(width: 600)
            .fixedSize(horizontal: false, vertical: true)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .environment(\.colorScheme, .dark)
    }
}

private struct ModRowView: View {
    let model: AppModel
    let row: AppModel.ModRow
    let canMoveUp: Bool
    let canMoveDown: Bool

    var body: some View {
        let s = row.status
        let isBase = s.folder.isEmpty
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.title3).foregroundStyle(tint).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(s.name).font(.headline)
                    Text(s.version).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    if let author = s.author { Text("· \(author)").font(.caption).foregroundStyle(.secondary) }
                }
                if !s.description.isEmpty { Text(s.description).font(.caption).foregroundStyle(.secondary) }
                Text(detail).font(.caption2.monospacedDigit()).foregroundStyle(stateColor)
                    .lineLimit(3).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if !isBase {
                if row.enabled {
                    SmallButton(symbol: "chevron.up", enabled: canMoveUp) { model.moveMod(s.id, by: -1) }
                    SmallButton(symbol: "chevron.down", enabled: canMoveDown) { model.moveMod(s.id, by: 1) }
                }
                PanelButton(title: row.enabled ? "On" : "Off") { model.toggleMod(s.id) }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(row.enabled ? 0.1 : 0.04)))
    }

    private var icon: String {
        switch row.status.state {
        case .active: row.status.folder.isEmpty ? "shippingbox.fill" : "puzzlepiece.extension.fill"
        case .disabled: "puzzlepiece.extension"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        if case .failed = row.status.state { return .orange }
        return row.enabled ? .accentColor : .secondary
    }

    private var stateColor: Color {
        if case .failed = row.status.state { return .orange }
        return .secondary
    }

    /// "Active · adds 9, replaces 1" / "Off" / "Failed: …" (reflecting the last applied load).
    private var detail: String {
        let s = row.status
        switch s.state {
        case .active:
            if s.folder.isEmpty { return "Base game content · always loaded first" }
            let c = s.changes
            return "Active · adds \(c.added.count), replaces \(c.replaced.count)"
                + (c.replaced.isEmpty ? "" : " (" + c.replaced.prefix(3).joined(separator: ", ") + (c.replaced.count > 3 ? ", …" : "") + ")")
                + (row.enabled ? "" : " · turned off, applies on Apply")
        case .disabled:
            return row.enabled ? "Off · turned on, loads on Apply" : "Off"
        case .failed(let why):
            return "Not loaded: \(why)"
        }
    }
}

private struct SmallButton: View {
    let symbol: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) { Image(systemName: symbol).frame(width: 22, height: 22) }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.3)
    }
}
