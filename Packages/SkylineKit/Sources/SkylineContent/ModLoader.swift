import Foundation

/// A pack as the mod manager shows it (Phase 17).
public struct PackStatus: Equatable, Sendable, Identifiable {
    public enum State: Equatable, Sendable {
        case active
        case disabled
        /// Not loaded: why (invalid JSON, a broken reference, a missing requirement, …).
        case failed(String)
    }

    public var id: String
    public var name: String
    public var version: String
    public var description: String
    public var author: String?
    /// Folder name inside the mods directory ("" for the base pack).
    public var folder: String
    public var state: State
    public var changes = ContentPack.Changes()
}

/// Finds mods, lays the enabled ones over the base pack in order and validates each step
/// (Phase 17). A mod that fails is skipped and reported; the base game never depends on a
/// mod loading. Mods are data only: nothing in a pack is ever executed (rule 15).
public enum ModLoader {
    /// Sub-folders of `directory` that contain a `pack.json`, sorted by folder name.
    public static func discover(in directory: URL) -> [URL] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return entries.filter { fm.fileExists(atPath: $0.appendingPathComponent("pack.json").path) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public struct Result: Sendable {
        public var library: ContentLibrary
        /// Base first, then enabled mods in load order, then disabled ones.
        public var packs: [PackStatus]
    }

    /// Loads the base pack and the mods whose ids are in `enabled`, in that order. Throws only
    /// when the base pack itself is invalid.
    public static func load(base: URL = BaseContent.packURL, mods: [URL], enabled: [String]) throws -> Result {
        let basePack = try ContentPack.read(at: base)
        var library = try ContentLibrary.build(basePack)
        var merged = basePack
        var manifests = [basePack.manifest]
        var statuses = [status(of: basePack.manifest, folder: "", state: .active)]

        var read: [(folder: String, pack: ReadOutcome)] = []
        for url in mods {
            do { read.append((url.lastPathComponent, .success(try ContentPack.read(at: url)))) } catch {
                read.append((url.lastPathComponent, .failure(String(describing: error))))
            }
        }
        var handled = Set<String>()
        for id in enabled {
            guard let entry = read.first(where: { $0.pack.id(folder: $0.folder) == id && !handled.contains($0.folder) }) else { continue }
            handled.insert(entry.folder)
            let pack: ContentPack
            switch entry.pack {
            case .failure(let why):
                statuses.append(PackStatus(id: id, name: entry.folder, version: "?", description: "", folder: entry.folder, state: .failed(why)))
                continue
            case .success(let p): pack = p
            }
            let m = pack.manifest
            if manifests.contains(where: { $0.id == m.id }) {
                statuses.append(status(of: m, folder: entry.folder, state: .failed("Another pack already uses the id '\(m.id)'")))
                continue
            }
            if let missing = (m.requires ?? []).first(where: { req in !manifests.contains { $0.id == req } }) {
                statuses.append(status(of: m, folder: entry.folder, state: .failed("Requires '\(missing)', which is not loaded before it")))
                continue
            }
            var trial = merged
            let changes = trial.overlay(pack)
            do {
                library = try ContentLibrary.build(trial, packs: manifests + [m])
                merged = trial
                manifests.append(m)
                var s = status(of: m, folder: entry.folder, state: .active)
                s.changes = changes
                statuses.append(s)
            } catch var error as ContentError {
                // The merged content passed without this mod, so the problem is this mod's.
                error.pack = m.id
                statuses.append(status(of: m, folder: entry.folder, state: .failed(error.description)))
            } catch {
                statuses.append(status(of: m, folder: entry.folder, state: .failed(String(describing: error))))
            }
        }
        for entry in read where !handled.contains(entry.folder) {
            switch entry.pack {
            case .success(let p): statuses.append(status(of: p.manifest, folder: entry.folder, state: .disabled))
            case .failure(let why):
                statuses.append(PackStatus(id: entry.folder, name: entry.folder, version: "?", description: "", folder: entry.folder, state: .failed(why)))
            }
        }
        return Result(library: library, packs: statuses)
    }

    private static func status(of m: ContentPackManifest, folder: String, state: PackStatus.State) -> PackStatus {
        PackStatus(id: m.id, name: m.name, version: m.version, description: m.description ?? "", author: m.author, folder: folder, state: state)
    }

    /// A mod folder as read: its pack, or why it could not be read.
    enum ReadOutcome: Sendable {
        case success(ContentPack)
        case failure(String)

        /// The pack id, or the folder name for a pack that could not be read.
        func id(folder: String) -> String {
            if case .success(let p) = self { return p.manifest.id }
            return folder
        }
    }
}
