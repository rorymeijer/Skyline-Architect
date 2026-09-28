import SwiftUI
import SkylinePersistence

/// Saves on this device, newest first, with their iCloud state (Phase 18). Replaces the
/// Phase 2 load sheet; drawn in plain SwiftUI so it looks the same in captures and on iPad.
struct SavesPanel: View {
    let model: AppModel
    @State private var confirmDelete: String?

    static let pageSize = 6

    var body: some View {
        let saves = model.availableSaves()
        let pages = max((saves.count + Self.pageSize - 1) / Self.pageSize, 1)
        let page = min(model.savesPage, pages - 1)
        let shown = Array(saves.dropFirst(page * Self.pageSize).prefix(Self.pageSize))
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Saves").font(.title2.weight(.bold))
                    Spacer()
                    Button { model.setSyncEnabled(!model.syncEnabled) } label: {
                        Label(model.syncEnabled ? "iCloud Drive: On" : "iCloud Drive: Off",
                              systemImage: model.syncEnabled ? "icloud.fill" : "icloud.slash")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(model.syncEnabled ? Color.accentColor.opacity(0.35) : Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                Text(model.syncStatus).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if saves.isEmpty {
                    Text("No saves yet. Use File ▸ Save (⌘S).").foregroundStyle(.secondary)
                }
                ForEach(shown, id: \.slot) { info in
                    SaveRow(model: model, info: info, confirmDelete: $confirmDelete)
                }
                if pages > 1 {
                    HStack {
                        PanelButton(title: "Newer", enabled: page > 0) { model.savesPage = page - 1 }
                        Text("Page \(page + 1) of \(pages)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        PanelButton(title: "Older", enabled: page + 1 < pages) { model.savesPage = page + 1 }
                    }
                }
                HStack {
                    if model.syncEnabled { MenuButton(title: "Sync Now", subtitle: nil) { model.syncSaves() } }
                    MenuButton(title: "Close", subtitle: nil) { model.showLoadSheet = false }
                }
            }
            .padding(24)
            .frame(width: 560)
            .fixedSize(horizontal: false, vertical: true)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .environment(\.colorScheme, .dark)
    }
}

private struct SaveRow: View {
    let model: AppModel
    let info: SaveSlotInfo
    @Binding var confirmDelete: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: badge.symbol).foregroundStyle(badge.color).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.metadata?.title ?? info.slot).font(.headline)
                Text("\(info.slot) · \(date) · \(badge.text)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if confirmDelete == info.slot {
                PanelButton(title: "Delete") { confirmDelete = nil; model.deleteSave(slot: info.slot) }
                PanelButton(title: "Keep") { confirmDelete = nil }
            } else {
                PanelButton(title: "Load") {
                    if model.load(slot: info.slot) { model.showLoadSheet = false }
                }
                Button { confirmDelete = info.slot } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
    }

    private var date: String {
        info.metadata.map { $0.savedAt.formatted(date: .abbreviated, time: .shortened) } ?? "unreadable"
    }

    private var badge: (symbol: String, color: Color, text: String) {
        if info.isAutosave { return ("internaldrive", .secondary, "autosave, this device only") }
        if model.syncConflicts.contains(info.slot) || info.slot.contains(" conflict ") {
            return ("exclamationmark.icloud", .orange, "conflict copy — the other device's version")
        }
        guard model.syncEnabled else { return ("internaldrive", .secondary, "on this device") }
        return model.syncedSlots.contains(info.slot) ? ("checkmark.icloud", .green, "in iCloud Drive") : ("icloud.and.arrow.up", .yellow, "not synced yet")
    }
}
