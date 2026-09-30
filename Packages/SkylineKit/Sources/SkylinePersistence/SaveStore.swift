import Foundation
import SkylineCore

/// A save file on disk.
public struct SaveSlotInfo: Hashable, Sendable {
    public var slot: String
    public var url: URL
    public var metadata: SaveMetadata?
    public var isAutosave: Bool { slot.hasPrefix(SaveStore.autosavePrefix) }
}

public enum SaveStoreError: Error, Equatable, CustomStringConvertible {
    case invalidSlotName(String)
    case notFound(String)

    public var description: String {
        switch self {
        case .invalidSlotName(let s): "Invalid save name '\(s)'"
        case .notFound(let s): "No save named '\(s)'"
        }
    }
}

/// Local save files in one directory. Writes are atomic (temporary file + replace), so a
/// crash mid-write never destroys the previous save.
public struct SaveStore: Sendable {
    public static let fileExtension = "skylinesave"
    public static let autosavePrefix = "autosave-"
    public static let quicksaveSlot = "quicksave"

    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public func url(for slot: String) throws -> URL {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        guard !slot.isEmpty, slot.count <= 64, slot.unicodeScalars.allSatisfy(allowed.contains) else {
            throw SaveStoreError.invalidSlotName(slot)
        }
        return directory.appendingPathComponent(slot).appendingPathExtension(Self.fileExtension)
    }

    @discardableResult
    public func write(_ save: SaveGame, slot: String) throws -> URL {
        let url = try url(for: slot)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try SaveCodec.encode(save).write(to: url, options: .atomic)
        return url
    }

    public func load(slot: String, availablePacks: [ContentPackReference], isShaft: (String) -> Bool = { _ in false }) throws -> SaveGame {
        let url = try url(for: slot)
        guard FileManager.default.fileExists(atPath: url.path) else { throw SaveStoreError.notFound(slot) }
        return try SaveCodec.decode(Data(contentsOf: url), availablePacks: availablePacks, isShaft: isShaft)
    }

    /// Writes `autosave-1`, shifting older autosaves up and keeping at most `keep`.
    @discardableResult
    public func writeAutosave(_ save: SaveGame, keep: Int = 3) throws -> URL {
        precondition(keep >= 1)
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let oldest = try url(for: "\(Self.autosavePrefix)\(keep)")
        if fm.fileExists(atPath: oldest.path) { try fm.removeItem(at: oldest) }
        if keep > 1 {
            for i in stride(from: keep - 1, through: 1, by: -1) {
                let from = try url(for: "\(Self.autosavePrefix)\(i)")
                if fm.fileExists(atPath: from.path) { try fm.moveItem(at: from, to: try url(for: "\(Self.autosavePrefix)\(i + 1)")) }
            }
        }
        return try write(save, slot: "\(Self.autosavePrefix)1")
    }

    /// All saves, newest first (by metadata date; unreadable files last).
    public func list() -> [SaveSlotInfo] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let infos = files.filter { $0.pathExtension == Self.fileExtension }.map { url in
            SaveSlotInfo(slot: url.deletingPathExtension().lastPathComponent, url: url,
                         metadata: (try? Data(contentsOf: url)).flatMap(SaveCodec.peekMetadata))
        }
        return infos.sorted {
            switch ($0.metadata?.savedAt, $1.metadata?.savedAt) {
            case let (a?, b?): a == b ? $0.slot < $1.slot : a > b
            case (_?, nil): true
            case (nil, _?): false
            default: $0.slot < $1.slot
            }
        }
    }

    public func delete(slot: String) throws {
        try FileManager.default.removeItem(at: try url(for: slot))
    }
}
