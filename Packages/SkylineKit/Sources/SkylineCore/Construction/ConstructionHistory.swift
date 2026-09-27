import Foundation

/// Session undo/redo built on inverse commands (not world snapshots), so it keeps working
/// once the world also contains simulation state.
public struct ConstructionHistory: Sendable {
    public private(set) var undoStack: [BuildCommand] = []
    public private(set) var redoStack: [BuildCommand] = []
    public var limit: Int

    public init(limit: Int = 200) { self.limit = limit }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Applies a player command and records its inverse. Clears the redo stack.
    @discardableResult
    public mutating func perform(_ command: BuildCommand, engine: ConstructionEngine, world: inout GameWorld) throws -> AppliedConstruction {
        let applied = try engine.apply(command, to: &world)
        undoStack.append(applied.inverse)
        if undoStack.count > limit { undoStack.removeFirst(undoStack.count - limit) }
        redoStack.removeAll()
        return applied
    }

    @discardableResult
    public mutating func undo(engine: ConstructionEngine, world: inout GameWorld) throws -> AppliedConstruction? {
        guard let inverse = undoStack.popLast() else { return nil }
        let applied = try engine.apply(inverse, to: &world)
        redoStack.append(applied.inverse)
        return applied
    }

    @discardableResult
    public mutating func redo(engine: ConstructionEngine, world: inout GameWorld) throws -> AppliedConstruction? {
        guard let command = redoStack.popLast() else { return nil }
        let applied = try engine.apply(command, to: &world)
        undoStack.append(applied.inverse)
        return applied
    }

    public mutating func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
