import Foundation
import Testing
import SkylineCore
@testable import SkylinePersistence

/// Two devices syncing through one shared folder (standing in for iCloud Drive).
@Suite struct SaveSyncTests {
    struct Cloud {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sync-\(UUID().uuidString)")
        var remote: SaveStore { SaveStore(directory: root.appendingPathComponent("cloud")) }
        func device(_ name: String) -> SaveStore { SaveStore(directory: root.appendingPathComponent(name)) }
        func cleanUp() { try? FileManager.default.removeItem(at: root) }
    }

    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    func save(_ title: String) -> SaveGame {
        var world = GameWorld()
        world.addCity(definitionID: "c", name: title, seed: 1)
        return SaveGame(metadata: SaveMetadata(title: title, savedAt: Date(timeIntervalSince1970: 1_790_000_000), gameVersion: "0.18.0"),
                        contentPacks: [ContentPackReference(id: "base", version: "0.1.0")], activePropertyID: PropertyID(raw: 999), world: world)
    }

    func title(_ store: SaveStore, _ slot: String) throws -> String? {
        let url = try store.url(for: slot)
        return (try? Data(contentsOf: url)).flatMap(SaveCodec.peekMetadata)?.title
    }

    @Test func savesTravelBetweenDevices() throws {
        let cloud = Cloud()
        defer { cloud.cleanUp() }
        let a = cloud.device("a"), b = cloud.device("b")
        try a.write(save("Quay v1"), slot: "Quay")
        #expect(try SaveSync.sync(local: a, remote: cloud.remote, now: t0).actions == [.upload("Quay")])
        #expect(try SaveSync.sync(local: b, remote: cloud.remote, now: t0).actions == [.download("Quay")])
        #expect(try title(b, "Quay") == "Quay v1")
        // An edit on one device reaches the other; nothing else happens.
        try b.write(save("Quay v2"), slot: "Quay")
        #expect(try SaveSync.sync(local: b, remote: cloud.remote, now: t0).actions == [.upload("Quay")])
        #expect(try SaveSync.sync(local: a, remote: cloud.remote, now: t0).actions == [.download("Quay")])
        #expect(try title(a, "Quay") == "Quay v2")
        // Idempotent.
        let again = try SaveSync.sync(local: a, remote: cloud.remote, now: t0)
        #expect(again.actions.isEmpty && again.synced == ["Quay"])
    }

    /// Both devices changed the same save: both versions survive on both devices.
    @Test func conflictsKeepBothVersions() throws {
        let cloud = Cloud()
        defer { cloud.cleanUp() }
        let a = cloud.device("a"), b = cloud.device("b")
        try a.write(save("Quay v1"), slot: "Quay")
        try SaveSync.sync(local: a, remote: cloud.remote, now: t0)
        try SaveSync.sync(local: b, remote: cloud.remote, now: t0)
        try a.write(save("Quay by A"), slot: "Quay")
        try b.write(save("Quay by B"), slot: "Quay")
        try SaveSync.sync(local: a, remote: cloud.remote, now: t0)
        let report = try SaveSync.sync(local: b, remote: cloud.remote, now: t0.addingTimeInterval(3600))
        let copy = "Quay conflict 20260921-1513"
        #expect(report.actions == [.conflict("Quay", copy: copy)] && report.conflicts == [copy])
        #expect(try title(b, "Quay") == "Quay by B" && title(b, copy) == "Quay by A")
        try SaveSync.sync(local: a, remote: cloud.remote, now: t0)
        #expect(try title(a, "Quay") == "Quay by B" && title(a, copy) == "Quay by A")
        #expect(try SaveSync.sync(local: b, remote: cloud.remote, now: t0).actions.isEmpty)
        // The copy's name is a valid slot and never replaces an existing one.
        #expect(SaveSync.uniqueName(copy, taken: [copy]) == "\(copy) 2")
        #expect((try? SaveStore(directory: cloud.root).url(for: SaveSync.conflictName(for: String(repeating: "x", count: 64), at: t0))) != nil)
    }

    @Test func deletionsFollowOnlyUnchangedCopies() throws {
        let cloud = Cloud()
        defer { cloud.cleanUp() }
        let a = cloud.device("a"), b = cloud.device("b")
        for slot in ["Old", "Kept"] { try a.write(save(slot), slot: slot) }
        try SaveSync.sync(local: a, remote: cloud.remote, now: t0)
        try SaveSync.sync(local: b, remote: cloud.remote, now: t0)
        // A deletes both; B meanwhile changed "Kept".
        try a.delete(slot: "Old")
        try a.delete(slot: "Kept")
        try b.write(save("Kept, edited on B"), slot: "Kept")
        #expect(try SaveSync.sync(local: a, remote: cloud.remote, now: t0).actions == [.deleteRemote("Kept"), .deleteRemote("Old")])
        #expect(try SaveSync.sync(local: b, remote: cloud.remote, now: t0).actions == [.upload("Kept"), .deleteLocal("Old")])
        #expect(try SaveSync.sync(local: a, remote: cloud.remote, now: t0).actions == [.download("Kept")])
        #expect(try title(a, "Kept") == "Kept, edited on B")
    }

    /// iCloud placeholders are pending: never downloaded over, never taken as a deletion.
    @Test func placeholdersArePending() throws {
        let cloud = Cloud()
        defer { cloud.cleanUp() }
        let a = cloud.device("a")
        try a.write(save("Quay v1"), slot: "Quay")
        try SaveSync.sync(local: a, remote: cloud.remote, now: t0)
        let file = try cloud.remote.url(for: "Quay")
        try FileManager.default.moveItem(at: file, to: cloud.remote.directory.appendingPathComponent(".Quay.skylinesave.icloud"))
        let report = try SaveSync.sync(local: a, remote: cloud.remote, now: t0)
        #expect(report.actions == [.pending("Quay")] && report.pending == ["Quay"])
        #expect(try title(a, "Quay") == "Quay v1")
        // Once downloaded, the slot is in sync again (its base was kept).
        try FileManager.default.moveItem(at: cloud.remote.directory.appendingPathComponent(".Quay.skylinesave.icloud"), to: file)
        #expect(try SaveSync.sync(local: a, remote: cloud.remote, now: t0).actions.isEmpty)
    }

    @Test func autosavesStayOnTheDevice() throws {
        let cloud = Cloud()
        defer { cloud.cleanUp() }
        let a = cloud.device("a")
        try a.writeAutosave(save("Auto"))
        try a.write(save("Quick"), slot: SaveStore.quicksaveSlot)
        #expect(try SaveSync.sync(local: a, remote: cloud.remote, now: t0).actions == [.upload("quicksave")])
        #expect(cloud.remote.list().map(\.slot) == ["quicksave"])
        // The sync state file is not a save.
        #expect(a.list().map(\.slot).sorted() == ["autosave-1", "quicksave"])
    }

    @Test func fingerprintIsStable() {
        #expect(SaveSync.fingerprint(Data()) == 0xcbf2_9ce4_8422_2325)
        #expect(SaveSync.fingerprint(Data("skyline".utf8)) == SaveSync.fingerprint(Data("skyline".utf8)))
        #expect(SaveSync.fingerprint(Data("a".utf8)) != SaveSync.fingerprint(Data("b".utf8)))
    }
}
