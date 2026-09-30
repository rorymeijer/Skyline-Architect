import SwiftUI

/// The side panels that can be open at once, top to bottom.
enum SidePanel: String, CaseIterable, Identifiable {
    case unit, foundation, scenario, estate, incidents, standing, economy, facilities, leasing, banks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unit: "Unit"
        case .foundation: "Foundation"
        case .scenario: "Objectives"
        case .estate: "Estate"
        case .incidents: "Incidents"
        case .standing: "Standing"
        case .economy: "Economy"
        case .facilities: "Facilities"
        case .leasing: "Leasing"
        case .banks: "Elevators"
        }
    }

    @MainActor func isOpen(_ model: AppModel) -> Bool {
        switch self {
        case .unit: model.unitReport != nil
        case .foundation: model.showFoundationPanel && model.foundation != nil
        case .scenario: model.showScenarioPanel
        case .estate: model.showEstatePanel
        case .incidents: model.showIncidentsPanel
        case .standing: model.showProgressPanel
        case .economy: model.showEconomyPanel
        case .facilities: model.showFacilitiesPanel
        case .leasing: model.showLeasingPanel
        case .banks: model.showBanksPanel
        }
    }

    @MainActor @ViewBuilder func view(_ model: AppModel) -> some View {
        switch self {
        case .unit:
            if let report = model.unitReport {
                UnitInspector(report: report, shaftOptions: model.shaftOptions, onResize: { _ = model.perform($0) },
                              stops: model.elevatorStops, onStop: { model.setStop($0, served: $1) },
                              onTenure: { model.offerSelectedUnit(forSale: $0) },
                              onUnitRent: { model.adjustUnitRent(by: $0) }) { model.selectRoom(at: nil) }
            }
        case .foundation: FoundationPanel(model: model)
        case .scenario: ScenarioPanel(model: model)
        case .estate: EstatePanel(model: model)
        case .incidents: IncidentsPanel(model: model)
        case .standing: ProgressPanel(model: model)
        case .economy: EconomyPanel(model: model)
        case .facilities: FacilitiesPanel(model: model)
        case .leasing: LeasingPanel(summary: model.leasing) { model.showLeasingPanel = false }
        case .banks: ElevatorBanksPanel(model: model)
        }
    }
}

/// The open side panels on the right. When they do not all fit the window's height, one
/// is shown in full and the others become tabs above it (click one to bring it forward);
/// closing a panel works as before, from its own close button.
struct PanelStack: View {
    let model: AppModel
    @State private var front: SidePanel?

    var body: some View {
        let open = SidePanel.allCases.filter { $0.isOpen(model) }
        // Where even one panel is too tall (an iPhone, 0.29.2), it is drawn smaller; one panel
        // alone never gets a tab row.
        if open.count == 1 {
            ViewThatFits(in: .vertical) {
                all(open)
                all(open).scaled(0.9)
                all(open).scaled(0.8)
                all(open).scaled(0.7)
                all(open).scaled(0.65)
            }
        } else {
            ViewThatFits(in: .vertical) {
                all(open)
                all(open).scaled(0.9)
                all(open).scaled(0.8)
                tabbed(open)
                tabbed(open).scaled(0.9)
                tabbed(open).scaled(0.8)
                tabbed(open).scaled(0.7)
                tabbed(open).scaled(0.65)
            }
        }
    }

    private func all(_ open: [SidePanel]) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(open) { $0.view(model) }
        }
    }

    /// The panel in front: the one picked last if it is still open, else the first.
    private func tabbed(_ open: [SidePanel]) -> some View {
        let shown = front.flatMap { open.contains($0) ? $0 : nil } ?? open.first
        return VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(open) { panel in
                    Button { front = panel } label: {
                        Text(panel.title).font(.ui(.caption).weight(panel == shown ? .semibold : .regular))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(panel == shown ? 0.28 : 0.1)))
                            .focusRing(cornerRadius: 10)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(panel == shown ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .environment(\.colorScheme, .dark)
            if let shown { shown.view(model) }
        }
    }
}
