import Foundation

/// Insertion-ordered collection of identifiable values with O(1) lookup by ID.
///
/// Swift `Dictionary` iteration order is randomized per process, which would break
/// simulation determinism and produce unstable save files. `EntityStore` iterates in
/// insertion order and encodes as a plain array.
public struct EntityStore<Value: Identifiable & Sendable>: Sendable
where Value.ID: Hashable & Sendable {
    public private(set) var values: [Value] = []
    private var indexByID: [Value.ID: Int] = [:]

    public init() {}

    public init(_ values: [Value]) {
        for v in values { insert(v) }
    }

    public var count: Int { values.count }
    public var isEmpty: Bool { values.isEmpty }

    public subscript(id: Value.ID) -> Value? {
        indexByID[id].map { values[$0] }
    }

    public func contains(_ id: Value.ID) -> Bool { indexByID[id] != nil }

    /// Inserts a new value. Inserting a duplicate ID is a programming error.
    public mutating func insert(_ value: Value) {
        precondition(indexByID[value.id] == nil, "Duplicate entity id \(value.id)")
        indexByID[value.id] = values.count
        values.append(value)
    }

    /// Mutates the value with `id` in place. Returns false if absent.
    @discardableResult
    public mutating func update(_ id: Value.ID, _ body: (inout Value) throws -> Void) rethrows -> Bool {
        guard let i = indexByID[id] else { return false }
        try body(&values[i])
        precondition(values[i].id == id, "Entity id must not change during update")
        return true
    }

    /// Removes the value with `id`, preserving the order of the remaining values.
    @discardableResult
    public mutating func remove(_ id: Value.ID) -> Value? {
        guard let i = indexByID.removeValue(forKey: id) else { return nil }
        let removed = values.remove(at: i)
        for j in i..<values.count { indexByID[values[j].id] = j }
        return removed
    }

    /// Removes every value matching `predicate` in one pass (order of the rest preserved).
    /// Returns how many were removed.
    @discardableResult
    public mutating func removeAll(where predicate: (Value) throws -> Bool) rethrows -> Int {
        let before = values.count
        try values.removeAll(where: predicate)
        guard values.count != before else { return 0 }
        indexByID.removeAll(keepingCapacity: true)
        for (j, v) in values.enumerated() { indexByID[v.id] = j }
        return before - values.count
    }
}

extension EntityStore: Sequence {
    public func makeIterator() -> IndexingIterator<[Value]> { values.makeIterator() }
}

extension EntityStore: Codable where Value: Codable {
    public init(from decoder: Decoder) throws {
        let decoded = try [Value](from: decoder)
        self.init()
        for v in decoded {
            guard indexByID[v.id] == nil else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Duplicate entity id \(v.id)"))
            }
            insert(v)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try values.encode(to: encoder)
    }
}

extension EntityStore: Equatable where Value: Equatable {
    public static func == (a: EntityStore, b: EntityStore) -> Bool { a.values == b.values }
}
