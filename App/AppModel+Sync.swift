import Foundation
import SkylinePersistence

extension AppModel {
    // MARK: Save sync (Phase 18)

    static let syncSavesKey = "syncSaves"

    /// The shared folder saves sync with: the app's iCloud Drive container, or (Debug
    /// captures) a local folder standing in for it. nil when iCloud Drive is unavailable.
    func remoteSaveStore() -> SaveStore? {
        if let folder = syncFolderOverride { return SaveStore(directory: folder) }
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        return SaveStore(directory: container.appendingPathComponent("Documents/Saves", isDirectory: true))
    }

    func setSyncEnabled(_ on: Bool) {
        syncEnabled = on
        if persistsModSettings { UserDefaults.standard.set(on, forKey: Self.syncSavesKey) }
        if on { syncSaves() } else {
            syncStatus = "Saves stay on this device."
            syncedSlots = []
            syncConflicts = []
        }
    }

    /// Two-way sync (see `SaveSync`): never overwrites a changed save silently; conflicts
    /// keep both versions. Runs on launch, after saving and when the saves panel opens.
    func syncSaves() {
        guard syncEnabled else { return }
        guard let remote = remoteSaveStore() else {
            syncStatus = "iCloud Drive is not available. Sign in to iCloud and allow iCloud Drive for Skyline Architect."
            syncedSlots = []
            return
        }
        do {
            let report = try SaveSync.sync(local: saveStore, remote: remote, now: Date())
            // The completion record travels with the saves: both sides keep the best (Phase C).
            scenarioRecords = try ScenarioRecordStore.sync(local: ScenarioRecordStore(directory: saveStore.directory),
                                                           remote: ScenarioRecordStore(directory: remote.directory))
            syncedSlots = Set(report.synced)
            syncConflicts = report.conflicts
            requestDownloads(report.pending, in: remote)
            var parts = ["\(report.synced.count) save\(report.synced.count == 1 ? "" : "s") in sync"]
            let moved = report.actions.filter {
                switch $0 { case .upload, .download, .deleteLocal, .deleteRemote: true; default: false }
            }.count
            if moved > 0 { parts.append("\(moved) updated") }
            if !report.conflicts.isEmpty { parts.append("\(report.conflicts.count) conflict\(report.conflicts.count == 1 ? "" : "s") — both versions kept") }
            if !report.pending.isEmpty { parts.append("\(report.pending.count) downloading") }
            syncStatus = parts.joined(separator: " · ")
        } catch {
            syncStatus = "Sync failed: \(error.localizedDescription). Local saves are unchanged."
        }
    }

    /// Asks iCloud to download placeholders; the next sync picks them up.
    private func requestDownloads(_ slots: [String], in remote: SaveStore) {
        guard syncFolderOverride == nil else { return }
        for slot in slots {
            if let url = try? remote.url(for: slot) { try? FileManager.default.startDownloadingUbiquitousItem(at: url) }
        }
    }

    /// Deletes a save here; with sync on, the deletion reaches the other devices unless one
    /// of them changed that save meanwhile (then it comes back).
    func deleteSave(slot: String) {
        do {
            try saveStore.delete(slot: slot)
        } catch {
            alert = AppAlert(title: "Could not delete the save", message: "\(error)")
        }
        syncSaves()
    }

    func openSavesPanel() {
        syncSaves()
        savesPage = 0
        showLoadSheet = true
    }
}
