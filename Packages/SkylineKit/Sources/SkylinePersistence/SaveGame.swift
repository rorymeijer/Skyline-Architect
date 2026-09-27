import Foundation
import SkylineCore

/// Identifies a content pack a save depends on.
public struct ContentPackReference: Codable, Hashable, Sendable {
    public var id: String
    public var version: String

    public init(id: String, version: String) {
        self.id = id
        self.version = version
    }
}

/// Human-facing information about a save. Never read by the simulation.
public struct SaveMetadata: Codable, Hashable, Sendable {
    public var title: String
    public var savedAt: Date
    public var gameVersion: String

    public init(title: String, savedAt: Date, gameVersion: String) {
        self.title = title
        self.savedAt = savedAt
        self.gameVersion = gameVersion
    }
}

/// Everything persisted for a game: authoritative model state only — never rendering
/// objects, caches or derived data (SAVE_FORMAT.md).
public struct SaveGame: Codable, Sendable, Equatable {
    public var metadata: SaveMetadata
    public var contentPacks: [ContentPackReference]
    public var activePropertyID: PropertyID
    public var world: GameWorld

    public init(metadata: SaveMetadata, contentPacks: [ContentPackReference], activePropertyID: PropertyID, world: GameWorld) {
        self.metadata = metadata
        self.contentPacks = contentPacks
        self.activePropertyID = activePropertyID
        self.world = world
    }
}
