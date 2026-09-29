import Foundation
import SkylineCore

/// A guided step of a tutorial scenario (F3): what to do, and the world state that shows it
/// is done. Steps are guidance, not rules: they are read from content (not saved) and are
/// measured on the current world, so a step is done while its conditions hold.
public struct TutorialStep: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// What to do and where to find it (one or two sentences).
    public var text: String
    /// All must hold for the step to be done.
    public var done: [TutorialCondition]
    /// Manual chapter to read more (`Manual/*.md` id).
    public var chapter: String?

    public init(id: String, title: String, text: String, done: [TutorialCondition], chapter: String? = nil) {
        self.id = id
        self.title = title
        self.text = text
        self.done = done
        self.chapter = chapter
    }
}

/// One measurable condition of a tutorial step, over the whole estate.
public struct TutorialCondition: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        /// At least `count` rooms whose definition is one of `rooms`.
        case rooms
        /// At least `count` built floor levels (basements included).
        case floors
        /// At least `count` tenants.
        case tenants
        /// At least `count` tenant members (residents and workers).
        case population
        /// At least `count` janitors and technicians.
        case staff
        /// The scenario has reached its day `count` (1 = the first day).
        case scenarioDay
    }

    public var kind: Kind
    public var count: Int
    public var rooms: [String]?

    public init(kind: Kind, count: Int, rooms: [String]? = nil) {
        self.kind = kind
        self.count = count
        self.rooms = rooms
    }

    /// The measured value and whether it meets `count`.
    public func progress(in world: GameWorld) -> (value: Int, met: Bool) {
        let value: Int
        switch kind {
        case .rooms:
            let ids = Set(rooms ?? [])
            value = world.rooms.values.reduce(0) { $0 + (ids.contains($1.definitionID) ? 1 : 0) }
        case .floors:
            value = world.buildings.values.reduce(0) { $0 + ($1.builtLevels?.count ?? 0) }
        case .tenants:
            value = world.tenants.count
        case .population:
            value = world.people.values.reduce(0) { $0 + ($1.role == .resident || $1.role == .worker ? 1 : 0) }
        case .staff:
            value = world.people.values.reduce(0) { $0 + ($1.role.isStaff ? 1 : 0) }
        case .scenarioDay:
            let start = world.scenario?.startDay ?? 0
            value = Int(SimClock.day(world.clock.tick) - start) + 1
        }
        return (value, value >= count)
    }
}

/// Where a tutorial stands: which steps are done now, and the first one still to do.
public struct TutorialProgress: Equatable, Sendable {
    public var done: [Bool]

    public init(steps: [TutorialStep], world: GameWorld) {
        done = steps.map { step in step.done.allSatisfy { $0.progress(in: world).met } }
    }

    /// Index of the step to work on (nil = all done).
    public var current: Int? { done.firstIndex(of: false) }
    public var completed: Int { done.filter { $0 }.count }
    public var isFinished: Bool { !done.contains(false) }
}

extension ContentLibrary {
    /// The tutorial steps of the scenario a world is playing (empty when it has none).
    public func tutorialSteps(for world: GameWorld) -> [TutorialStep] {
        world.scenario.flatMap { scenario($0.id)?.tutorial } ?? []
    }

    /// Validation of a scenario's tutorial steps (empty if valid).
    func tutorialProblems(_ steps: [TutorialStep]) -> [String] {
        var p: [String] = []
        var ids = Set<String>()
        let roomIDs = Set(orderedRooms.map(\.id))
        for (i, step) in steps.enumerated() {
            let name = "tutorial step \(i + 1) '\(step.id)'"
            if !ids.insert(step.id).inserted { p.append("\(name): duplicate id") }
            if step.title.isEmpty || step.text.isEmpty { p.append("\(name): needs a title and text") }
            if step.done.isEmpty { p.append("\(name): needs at least one condition") }
            for c in step.done {
                if c.count < 1 { p.append("\(name): count must be ≥ 1") }
                if c.kind == .rooms {
                    let rooms = c.rooms ?? []
                    if rooms.isEmpty { p.append("\(name): a rooms condition needs room ids") }
                    if let bad = rooms.first(where: { !roomIDs.contains($0) }) { p.append("\(name): unknown room '\(bad)'") }
                } else if c.rooms != nil {
                    p.append("\(name): only a rooms condition takes room ids")
                }
            }
        }
        return p
    }
}
