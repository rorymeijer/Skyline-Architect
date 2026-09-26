import Foundation
import Testing
@testable import SkylineCore

@Suite struct DeterminismTests {
    @Test func seededRandomIsReproducible() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        for _ in 0..<1000 { #expect(a.next() == b.next()) }
    }

    /// Guards cross-platform stability: these values must never change, or every
    /// procedural asset and every saved simulation would change with them.
    @Test func seededRandomGoldenValues() {
        var r = SeededRandom(seed: 1)
        #expect(r.next() == 0x910A_2DEC_8902_5CC1)
        #expect(stableHash("base") == 0x9A7C_E19B_AA54_C278)
        #expect(stableHash("") == 0xcbf2_9ce4_8422_2325)
    }

    @Test func unitIsInRange() {
        var r = SeededRandom(seed: 7)
        for _ in 0..<10_000 {
            let u = r.unit()
            #expect(u >= 0 && u < 1)
        }
    }

    @Test func streamsDiffer() {
        var a = SeededRandom(seed: 9, stream: 1)
        var b = SeededRandom(seed: 9, stream: 2)
        #expect(a.next() != b.next())
    }

    @Test func entityStoreKeepsInsertionOrderAndRoundTrips() throws {
        struct Item: Identifiable, Codable, Equatable, Sendable { var id: Int; var name: String }
        var store = EntityStore<Item>()
        for i in [5, 1, 9, 3] { store.insert(Item(id: i, name: "n\(i)")) }
        store.remove(1)
        #expect(store.map(\.id) == [5, 9, 3])
        #expect(store[9]?.name == "n9")
        store.update(3) { $0.name = "changed" }
        let data = try JSONEncoder().encode(store)
        let decoded = try JSONDecoder().decode(EntityStore<Item>.self, from: data)
        #expect(decoded == store)
        #expect(decoded[3]?.name == "changed")
    }

    @Test func idAllocatorIsMonotonic() {
        enum Tag {}
        var alloc = IDAllocator()
        let a: EntityID<Tag> = alloc.make()
        let b: EntityID<Tag> = alloc.make()
        #expect(a < b)
        #expect(a.raw == 1)
    }
}
