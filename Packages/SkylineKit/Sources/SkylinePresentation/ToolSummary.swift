import Foundation
import SkylineCore

/// What the picked build tool is and what it costs (0.30.3), shown above the build palette
/// before anything is placed: the palette may show icons only, and several tools look alike.
/// Prices are at the property's local construction price level. Pure data.
public struct ToolSummary: Equatable, Sendable {
    /// "Service Elevator".
    public var title: String
    /// Size and price, e.g. "3 m wide · 2+ floors · from $22,800".
    public var line: String
    /// More about it, e.g. "Service elevator (staff only, 8 persons, 1.6 m/s)"; nil = nothing.
    public var detail: String?

    /// `detail` comes from the caller (an elevator's description lives in the simulation rules).
    public static func make(tool: ConstructionTool, world: GameWorld, propertyID: PropertyID, catalog: BuildCatalog,
                            detail: String? = nil) -> ToolSummary? {
        let factor = world.buildings(on: propertyID).first.flatMap { world.city(of: $0.id)?.economy.construction } ?? 1
        let meters = { (modules: Int) in Int((Double(modules) * world.grid.moduleWidth).rounded()) }
        func price(_ cost: Int) -> String { Money.format(Int((Double(cost) * factor).rounded())) }
        let unit = meters(1) == 1 ? "metre" : "\(meters(1)) m"
        switch tool {
        case .floor:
            let rules = catalog.rules
            return ToolSummary(title: "Floor",
                               line: "\(price(rules.slabCostPerModule)) per \(unit) · basement \(price(rules.basementSlabCostPerModule)) per \(unit)",
                               detail: "Drag across the columns; each floor rests on the one below.")
        case .demolish:
            let refund = Int((catalog.rules.demolitionRefund * 100).rounded())
            return ToolSummary(title: "Demolish", line: "Refunds \(refund) % of the construction cost",
                               detail: "Pick a room, or an empty floor.")
        case .room(let id):
            guard let spec = catalog.spec(id) else { return nil }
            let width = spec.minWidth == spec.maxWidth ? "\(meters(spec.minWidth)) m wide"
                : "\(meters(spec.minWidth))–\(meters(spec.maxWidth)) m wide"
            var parts = [width]
            if spec.kind == .shaft {
                parts.append("\(spec.minFloors)+ floors")
                parts.append("from \(price(spec.costPerModule * spec.minWidth * spec.minFloors))")
                parts.append("\(price(spec.costPerModule * spec.minWidth)) per floor")
            } else {
                parts.append("from \(price(spec.costPerModule * spec.minWidth * spec.minFloors))")
                if spec.minWidth != spec.maxWidth { parts.append("\(price(spec.costPerModule)) per \(unit)") }
            }
            return ToolSummary(title: spec.name, line: parts.joined(separator: " · "), detail: detail)
        }
    }
}
