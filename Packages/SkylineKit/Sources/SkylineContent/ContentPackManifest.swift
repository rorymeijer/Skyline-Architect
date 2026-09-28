import Foundation

/// `pack.json` — identifies a content pack and lists its definition files.
public struct ContentPackManifest: Codable, Sendable, Hashable {
    /// The content format this engine build understands.
    public static let supportedFormatVersion = 1

    public var id: String
    public var name: String
    public var version: String
    public var formatVersion: Int
    /// Definition kind → file name relative to the pack folder.
    public var files: [String: String]
    /// One line for the mod manager (Phase 17).
    public var description: String?
    public var author: String?
    /// Packs (other than base) that must be loaded before this one.
    public var requires: [String]?
    /// Hash of the pack's files, computed when the pack is read (never part of `pack.json`).
    /// Saves record it to notice a pack that changed without a new version.
    public var contentHash: String?

    enum CodingKeys: String, CodingKey {
        case id, name, version, formatVersion, files, description, author, requires
    }

    public init(id: String, name: String, version: String, formatVersion: Int, files: [String: String],
                description: String? = nil, author: String? = nil, requires: [String]? = nil) {
        self.id = id
        self.name = name
        self.version = version
        self.formatVersion = formatVersion
        self.files = files
        self.description = description
        self.author = author
        self.requires = requires
    }
}

public enum BaseContent {
    /// URL of the bundled base pack folder.
    public static var packURL: URL {
        guard let url = Bundle.module.url(forResource: "Base", withExtension: nil) else {
            fatalError("Base content pack missing from SkylineContent bundle")
        }
        return url
    }

    /// Example mods shipped with the game (Phase 17); the mod manager can install them.
    public static var examplesURL: URL {
        guard let url = Bundle.module.url(forResource: "Examples", withExtension: nil) else {
            fatalError("Example mods missing from SkylineContent bundle")
        }
        return url
    }
}
