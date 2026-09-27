import Foundation

/// Session undo/redo built on inverse commands (not world snapshots), so it keeps working
/// once the world also contains simulation state.
///
/// Since Phase 9 the history also settles money: performing a command posts its plan cost
/// (construction expense, or demolition refund) to the ledger; undo posts the exact
/// reversal of what was charged; redo charges again. A command costing more than the
/// available cash is refused before anything changes.
public struct ConstructionHistory: Sendable {
    /// An undoable step: the command that reverts it and what performing it cost.
    public struct Entry: Hashable, Sendable {
        public var command: BuildCommand
        /// Ledger amount posted when the step was performed (negative = paid).
        public var charged: Int
        public var detail: String
    }

    public private(set) var undoStack: [Entry] = []
    public private(set) var redoStack: [Entry] = []
    public var limit: Int

    public init(limit: Int = 200) { self.limit = limit }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    /// Applies a player command, charges it and records its inverse. Clears the redo stack.
    @discardableResult
    public mutating func perform(_ command: BuildCommand, engine: ConstructionEngine, world: inout GameWorld) throws -> AppliedConstruction {
        let (applied, charged, detail) = try applyAndCharge(command, engine: engine, world: &world)
        undoStack.append(Entry(command: applied.inverse, charged: charged, detail: detail))
        if undoStack.count > limit { undoStack.removeFirst(undoStack.count - limit) }
        redoStack.removeAll()
        return applied
    }

    @discardableResult
    public mutating func undo(engine: ConstructionEngine, world: inout GameWorld) throws -> AppliedConstruction? {
        guard let entry = undoStack.popLast() else { return nil }
        let applied = try engine.apply(entry.command, to: &world)
        if entry.charged != 0 {
            world.ledger.post(Transaction(tick: world.clock.tick, amount: -entry.charged, category: entry.charged < 0 ? .construction : .demolition,
                                          detail: "Undo: " + entry.detail, building: applied.plan.buildingID))
        }
        redoStack.append(Entry(command: applied.inverse, charged: entry.charged, detail: entry.detail))
        return applied
    }

    @discardableResult
    public mutating func redo(engine: ConstructionEngine, world: inout GameWorld) throws -> AppliedConstruction? {
        guard let entry = redoStack.last else { return nil }
        let (applied, charged, detail) = try applyAndCharge(entry.command, engine: engine, world: &world, detail: entry.detail,
                                                            amount: entry.charged)
        redoStack.removeLast()
        undoStack.append(Entry(command: applied.inverse, charged: charged, detail: detail))
        return applied
    }

    public mutating func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Validates, checks funds, applies and posts. `amount` overrides the plan cost (redo of
    /// an undone step charges exactly what the original did).
    private func applyAndCharge(_ command: BuildCommand, engine: ConstructionEngine, world: inout GameWorld,
                                detail: String? = nil, amount: Int? = nil) throws -> (AppliedConstruction, Int, String) {
        let plan = try engine.validate(command, in: world).get()
        let charged = amount ?? -plan.cost
        if charged < 0, world.ledger.cash + charged < 0 {
            throw LedgerError.insufficientFunds(needed: -charged, available: world.ledger.cash)
        }
        let applied = try engine.apply(command, to: &world)
        let text = detail ?? Self.describe(command, plan: plan)
        if charged != 0 {
            world.ledger.post(Transaction(tick: world.clock.tick, amount: charged, category: charged < 0 ? .construction : .demolition,
                                          detail: text, building: plan.buildingID, room: applied.createdRoom))
        }
        return (applied, charged, text)
    }

    static func describe(_ command: BuildCommand, plan: ConstructionPlan) -> String {
        let where_ = plan.floors.lowest == plan.floors.highest ? "floor \(plan.floors.lowest)"
            : "floors \(plan.floors.lowest)–\(plan.floors.highest)"
        switch command {
        case let .placeRoom(_, definition, columns, _): return "\(command.actionName) \(definition) (\(columns.count) m), \(where_)"
        default: return "\(command.actionName), \(where_)"
        }
    }
}
