import Foundation

/// Binary min-heap with a caller-defined strict ordering. Used for the event queue and for
/// Dijkstra; callers break ties explicitly (by id or index) so pop order is deterministic.
struct MinHeap<Element> {
    private var items: [Element] = []
    private let less: (Element, Element) -> Bool

    init(by less: @escaping (Element, Element) -> Bool) {
        self.less = less
    }

    var isEmpty: Bool { items.isEmpty }

    mutating func push(_ item: Element) {
        items.append(item)
        var i = items.count - 1
        while i > 0 {
            let parent = (i - 1) / 2
            guard less(items[i], items[parent]) else { break }
            items.swapAt(i, parent)
            i = parent
        }
    }

    mutating func popMin() -> Element? {
        guard !items.isEmpty else { return nil }
        items.swapAt(0, items.count - 1)
        let min = items.removeLast()
        var i = 0
        while true {
            let l = 2 * i + 1, r = l + 1
            var smallest = i
            if l < items.count, less(items[l], items[smallest]) { smallest = l }
            if r < items.count, less(items[r], items[smallest]) { smallest = r }
            if smallest == i { break }
            items.swapAt(i, smallest)
            i = smallest
        }
        return min
    }
}
