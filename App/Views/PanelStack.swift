import SwiftUI

/// The side panels that can be open at once, top to bottom.
enum SidePanel: String, CaseIterable, Identifiable {
    case unit, scenario, estate, incidents, standing, economy, facilities, leasing, banks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unit: "Unit"
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
                UnitInspector(report: report, shaftOptions: model.shaftOptions, onResize: { _ = model.perform($0) }) { model.selectRoom(at: nil) }
            }
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
        ViewThatFits(in: .vertical) {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(open) { $0.view(model) }
            }
            tabbed(open)
        }
    }

    /// The panel in front: the one picked last if it is still open, else the first.
    private func tabbed(_ open: [SidePanel]) -> some View {
        let shown = front.flatMap { open.contains($0) ? $0 : nil } ?? open.first
        return VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(open) { panel in
                    Button { front = panel } label: {
                        Text(panel.title).font(.caption.weight(panel == shown ? .semibold : .regular))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(panel == shown ? 0.28 : 0.1)))
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
