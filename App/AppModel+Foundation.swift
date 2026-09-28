import Foundation
import SkylineCore
import SkylinePresentation

/// The foundation panel's data (0.21): today's groundwork and the four ways to grow it.
struct FoundationSummary: Equatable {
    var building: String
    var widthMeters: Int
    var basements: Int
    var maxBasements: Int
    var pileDepth: Int
    /// Storeys the piles carry (nil = no limit) and storeys built.
    var carries: Int?
    var built: Int
    var options: [ConstructionOption]
}

extension AppModel {
    // MARK: Foundation (0.21)

    func toggleFoundationPanel() {
        showFoundationPanel.toggle()
        refreshFoundation()
    }

    /// Wider by one pile bay (the pile spacing) on either side, one basement level deeper, or
    /// piles 5 m longer: the `extendFoundation` commands, validated and priced here.
    func refreshFoundation() {
        guard showFoundationPanel, let world, let engine, let property = activePropertyID,
              let b = world.buildings(on: property).first, let plot = world.properties[property]?.plot else {
            if foundation != nil { foundation = nil }
            return
        }
        let f = b.foundation, bay = max(f.pileSpacing, 1)
        func grown(left: Int = 0, right: Int = 0, basements: Int = 0, piles: Double = 0) -> BuildCommand {
            var next = f
            next.basementFloors += basements
            next.pileDepth += piles
            return .extendFoundation(building: b.id, footprint: ColumnSpan(start: b.footprint.start - left, count: b.footprint.count + left + right),
                                     foundation: next)
        }
        // Widen by a bay, or by what is left of the plot on that side.
        let roomLeft = b.footprint.start - plot.frontage.start, roomRight = plot.frontage.end - b.footprint.end
        let steps: [(String, String, String, BuildCommand)] = [
            ("left", "Widen Left", "arrow.left.to.line", grown(left: max(min(bay, roomLeft), 1))),
            ("right", "Widen Right", "arrow.right.to.line", grown(right: max(min(bay, roomRight), 1))),
            ("deeper", "Dig a Basement Level", "arrow.down.to.line", grown(basements: 1)),
            ("piles", "Piles +5 m", "arrow.down.circle", grown(piles: 5)),
        ]
        let options = steps.map { key, title, symbol, command -> ConstructionOption in
            switch engine.validate(command, in: world) {
            case .success(let plan):
                guard plan.cost <= world.ledger.cash else {
                    return ConstructionOption(id: key, title: title, symbol: symbol, command: nil, detail: "Not enough money (\(Money.format(plan.cost)))")
                }
                return ConstructionOption(id: key, title: title, symbol: symbol, command: command, detail: Money.format(plan.cost))
            case .failure(let error):
                return ConstructionOption(id: key, title: title, symbol: symbol, command: nil, detail: "\(error)")
            }
        }
        let summary = FoundationSummary(
            building: b.name, widthMeters: Int((Double(b.footprint.count) * world.grid.moduleWidth).rounded()),
            basements: f.basementFloors, maxBasements: plot.maxBasementFloors, pileDepth: Int(f.pileDepth.rounded()),
            carries: engine.catalog.rules.highestLevel(for: f).map { $0 + 1 },
            built: b.floors.filter { $0.level >= 0 }.count, options: options)
        if summary != foundation { foundation = summary }
    }
}
