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

    public init(id: String, name: String, version: String, formatVersion: Int, files: [String: String]) {
        self.id = id
        self.name = name
        self.version = version
        self.formatVersion = formatVersion
        self.files = files
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
}
