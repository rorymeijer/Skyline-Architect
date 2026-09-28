import Foundation

/// Two-way sync of save files between a local folder and a shared folder, such as the app's
/// iCloud Drive container (Phase 18). Pure file logic, so it builds and is tested on Linux.
/// The app decides which folder is "remote". See SAVE_FORMAT.md → Sync.
///
/// Rules:
/// * a slot changed on one side only is copied to the other;
/// * a slot changed on both sides is a **conflict**: both versions are kept (the remote
///   version under a new "… conflict …" name on both sides); nothing is overwritten silently;
/// * a deletion is passed on only when the other side still holds exactly the version last
///   synced; otherwise the surviving version is restored to both sides;
/// * iCloud placeholders (not yet downloaded) are "pending" and left alone;
/// * autosaves are per device and never synced.
public enum SaveSync {
    /// What one side holds for a slot.
    public enum Entry: Hashable, Sendable {
        case file(UInt64)
        /// Known to exist but not downloaded yet (iCloud placeholder).
        case pending
    }

    public enum Action: Hashable, Sendable {
        case upload(String)
        case download(String)
        case deleteLocal(String)
        case deleteRemote(String)
        /// Both sides changed: the remote version is kept as `copy`, the local one uploaded.
        case conflict(String, copy: String)
        case pending(String)
    }

    public struct Report: Equatable, Sendable {
        public var actions: [Action] = []
        /// Slots in sync after this run (both sides hold the same version).
        public var synced: [String] = []
        public var conflicts: [String] { actions.compactMap { if case .conflict(_, let copy) = $0 { copy } else { nil } } }
        public var pending: [String] { actions.compactMap { if case .pending(let s) = $0 { s } else { nil } } }
    }

    /// The last synced version of every slot (per device, stored in the local folder).
    struct State: Codable, Equatable {
        var base: [String: UInt64] = [:]
    }

    static let stateFile = ".skyline-sync.json"

    // MARK: Planning (pure)

    /// Decides per slot, in slot order. `base` is the fingerprint both sides had after the
    /// last sync of this device.
    public static func plan(local: [String: Entry], remote: [String: Entry], base: [String: UInt64],
                            conflictName: (String) -> String) -> [Action] {
        var actions: [Action] = []
        for slot in Set(local.keys).union(remote.keys).sorted() {
            let l = local[slot], r = remote[slot], b = base[slot]
            if l == .pending || r == .pending { actions.append(.pending(slot)); continue }
            switch (l, r) {
            case let (.file(lv)?, .file(rv)?):
                if lv == rv { continue }
                if lv == b { actions.append(.download(slot)) }
                else if rv == b { actions.append(.upload(slot)) }
                else { actions.append(.conflict(slot, copy: conflictName(slot))) }
            case let (.file(lv)?, nil):
                // Deleted remotely: follow only if this device still has the synced version.
                actions.append(b == lv ? .deleteLocal(slot) : .upload(slot))
            case let (nil, .file(rv)?):
                actions.append(b == rv ? .deleteRemote(slot) : .download(slot))
            default:
                continue
            }
        }
        return actions
    }

    // MARK: Running

    /// Syncs `local` with `remote` and returns what happened. `now` names conflict copies.
    @discardableResult
    public static func sync(local: SaveStore, remote: SaveStore, now: Date) throws -> Report {
        let fm = FileManager.default
        try fm.createDirectory(at: local.directory, withIntermediateDirectories: true)
        try fm.createDirectory(at: remote.directory, withIntermediateDirectories: true)
        var state = loadState(local)
        let l = scan(local.directory), r = scan(remote.directory)
        var taken = Set(l.keys).union(r.keys)
        let actions = plan(local: l, remote: r, base: state.base) { slot in
            let name = uniqueName(conflictName(for: slot, at: now), taken: taken)
            taken.insert(name)
            return name
        }
        func copy(_ slot: String, from: SaveStore, to: SaveStore, as target: String? = nil) throws {
            let data = try Data(contentsOf: try from.url(for: slot))
            try data.write(to: try to.url(for: target ?? slot), options: .atomic)
        }
        for action in actions {
            switch action {
            case .upload(let s): try copy(s, from: local, to: remote)
            case .download(let s): try copy(s, from: remote, to: local)
            case .deleteLocal(let s): try local.delete(slot: s)
            case .deleteRemote(let s): try remote.delete(slot: s)
            case let .conflict(s, copyName):
                try copy(s, from: remote, to: local, as: copyName)
                try copy(s, from: remote, to: remote, as: copyName)
                try copy(s, from: local, to: remote)
            case .pending: break
            }
        }
        // The new base: every slot both sides now hold identically.
        let after = scan(local.directory), afterRemote = scan(remote.directory)
        var base: [String: UInt64] = [:]
        for (slot, entry) in after {
            if case .file(let v) = entry, afterRemote[slot] == entry { base[slot] = v }
        }
        // A pending slot keeps its old base, so the next run can still decide correctly.
        for slot in actions.compactMap({ if case .pending(let s) = $0 { s } else { nil } }) { base[slot] = state.base[slot] }
        state.base = base
        try saveState(state, local)
        return Report(actions: actions, synced: base.keys.sorted())
    }

    /// Slots with their fingerprints (autosaves excluded); iCloud placeholders
    /// (`.name.skylinesave.icloud`) are pending.
    public static func scan(_ directory: URL) -> [String: Entry] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var entries: [String: Entry] = [:]
        let ext = "." + SaveStore.fileExtension
        for url in files {
            let name = url.lastPathComponent
            let slot: String
            let entry: Entry
            if name.hasPrefix("."), name.hasSuffix(ext + ".icloud") {
                slot = String(name.dropFirst().dropLast((ext + ".icloud").count))
                entry = .pending
            } else if name.hasSuffix(ext), !name.hasPrefix(".") {
                slot = String(name.dropLast(ext.count))
                guard let data = try? Data(contentsOf: url) else { continue }
                entry = .file(fingerprint(data))
            } else { continue }
            if slot.hasPrefix(SaveStore.autosavePrefix) { continue }
            // A downloaded file wins over a stale placeholder of the same slot.
            if entries[slot] == nil || entry != .pending { entries[slot] = entry }
        }
        return entries
    }

    /// FNV-1a 64 over the file bytes: stable across platforms and runs.
    public static func fingerprint(_ data: Data) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in data {
            h ^= UInt64(byte)
            h = h &* 0x0000_0100_0000_01b3
        }
        return h
    }

    /// "Tower conflict 20260928-1405" (a valid slot name, at most 64 characters).
    static func conflictName(for slot: String, at date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd-HHmm"
        let suffix = " conflict " + f.string(from: date)
        return String(slot.prefix(64 - suffix.count - 3)) + suffix
    }

    static func uniqueName(_ name: String, taken: Set<String>) -> String {
        guard taken.contains(name) else { return name }
        var i = 2
        while taken.contains("\(name) \(i)") { i += 1 }
        return "\(name) \(i)"
    }

    static func loadState(_ store: SaveStore) -> State {
        let url = store.directory.appendingPathComponent(stateFile)
        return (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }

    static func saveState(_ state: State, _ store: SaveStore) throws {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        try e.encode(state).write(to: store.directory.appendingPathComponent(stateFile), options: .atomic)
    }
}
