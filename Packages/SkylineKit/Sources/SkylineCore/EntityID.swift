import Foundation

/// Compact, typed, deterministic entity identifier. `Tag` is a phantom type so a
/// `BuildingID` can never be passed where a `PropertyID` is expected.
public struct EntityID<Tag>: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let raw: UInt32

    public init(raw: UInt32) { self.raw = raw }

    public init(from decoder: Decoder) throws {
        raw = try decoder.singleValueContainer().decode(UInt32.self)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(raw)
    }

    public static func < (a: EntityID, b: EntityID) -> Bool { a.raw < b.raw }

    public var description: String { "#\(raw)" }
}

/// Allocates IDs from a monotonically increasing counter stored in the world, so IDs are
/// deterministic, never reused, and survive save/load.
public struct IDAllocator: Codable, Sendable, Hashable {
    public private(set) var next: UInt32

    public init(next: UInt32 = 1) { self.next = next }

    public mutating func make<Tag>(_: Tag.Type = Tag.self) -> EntityID<Tag> {
        precondition(next < .max, "Entity ID space exhausted")
        defer { next += 1 }
        return EntityID(raw: next)
    }
}
