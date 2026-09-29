import Foundation
import SkylineContent
#if os(macOS)
import AppKit
#endif

extension AppModel {
    // MARK: Mods (Phase 17)

    /// A pack as the mod manager lists it: its last load status and whether the draft enables it.
    struct ModRow: Identifiable {
        var status: PackStatus
        var enabled: Bool
        var id: String { status.folder.isEmpty ? status.id : status.folder }
    }

    /// Base first, then the draft's order, then the other installed packs by folder.
    var modRows: [ModRow] {
        var rows = packStatuses.filter { $0.folder.isEmpty }.map { ModRow(status: $0, enabled: true) }
        let mods = packStatuses.filter { !$0.folder.isEmpty }
        for id in modDraft {
            if let s = mods.first(where: { $0.id == id }) { rows.append(ModRow(status: s, enabled: true)) }
        }
        rows += mods.filter { !modDraft.contains($0.id) }.map { ModRow(status: $0, enabled: false) }
        return rows
    }

    var hasPendingModChanges: Bool { modDraft != enabledMods }

    func openModManager() {
        modDraft = enabledMods
        rescanMods()
        showModManager = true
    }

    func toggleMod(_ id: String) {
        if let i = modDraft.firstIndex(of: id) { modDraft.remove(at: i) } else { modDraft.append(id) }
    }

    /// Moves an enabled mod earlier (-1) or later (+1) in the load order.
    func moveMod(_ id: String, by offset: Int) {
        guard let i = modDraft.firstIndex(of: id), modDraft.indices.contains(i + offset) else { return }
        modDraft.swapAt(i, i + offset)
    }

    /// Re-reads the mods folder (new or edited packs) without changing the running game.
    func rescanMods() {
        // The folder exists before anything is in it, so the Files app (iOS) lists it.
        try? FileManager.default.createDirectory(at: modsDirectory, withIntermediateDirectories: true)
        if let result = try? ModLoader.load(mods: ModLoader.discover(in: modsDirectory), enabled: enabledMods) {
            packStatuses = result.packs
        }
    }

    /// Copies the example mods shipped with the game into the mods folder (never overwrites).
    func installExampleMods() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: modsDirectory, withIntermediateDirectories: true)
            for url in ModLoader.discover(in: BaseContent.examplesURL) {
                let target = modsDirectory.appendingPathComponent(url.lastPathComponent)
                if !fm.fileExists(atPath: target.path) { try fm.copyItem(at: url, to: target) }
            }
        } catch {
            alert = AppAlert(title: "Could not install the example mods", message: "\(error)")
        }
        rescanMods()
    }

    #if os(macOS)
    func revealModsFolder() {
        try? FileManager.default.createDirectory(at: modsDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(modsDirectory)
    }
    #endif

    /// Applies the draft: reloads all content with the new mods and returns to the main menu
    /// with a fresh game (the running game is discarded; saves need the packs they list).
    func applyMods() {
        enabledMods = modDraft
        if persistsModSettings { UserDefaults.standard.set(enabledMods, forKey: Self.enabledModsKey) }
        do {
            try reloadContent()
        } catch {
            alert = AppAlert(title: "The base content could not be loaded", message: "\(error)")
            return
        }
        newGame(startID: NewGameFactory.defaultStartID)
        showMainMenu = true
        setSpeed(.paused)
    }
}
