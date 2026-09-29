import SwiftUI

/// Floating camera controls (bottom-right). Mirrors the View menu for touch users. Drawn
/// entirely in SwiftUI (no AppKit-backed controls) so it renders identically in the window
/// and in automated captures. Where the whole bar does not fit (F5, an iPhone), the panel
/// and overlay toggles move into a picker opened by one button.
struct ViewControls: View {
    let model: AppModel

    /// A panel or overlay that can be switched on and off.
    struct Toggle: Identifiable {
        let symbol: String
        let help: String
        let isOn: Bool
        let action: () -> Void
        var id: String { symbol }
        var name: String { help.components(separatedBy: " (").first ?? help }
    }

    var toggles: [Toggle] {
        var t: [Toggle] = [
            Toggle(symbol: "square.grid.3x3", help: "Architectural Grid (G, ⌥⌘G)", isOn: model.showGrid) { model.toggleGrid() },
            Toggle(symbol: "arrow.up.arrow.down", help: "Elevator Traffic (⌥⌘T)", isOn: model.showTraffic) { model.showTraffic.toggle() },
            Toggle(symbol: "slider.horizontal.3", help: "Elevator Banks (⌥⌘E)", isOn: model.showBanksPanel) { model.showBanksPanel.toggle() },
        ]
        if model.scenario != nil {
            t.append(Toggle(symbol: "flag.checkered", help: "Objectives (⌥⌘O)", isOn: model.showScenarioPanel) { model.showScenarioPanel.toggle() })
        }
        t += [
            Toggle(symbol: "globe.europe.africa", help: "Estate (⌥⌘K)", isOn: model.showEstatePanel) { model.toggleEstatePanel() },
            Toggle(symbol: "flame", help: "Incidents (⌥⌘I)", isOn: model.showIncidentsPanel) { model.showIncidentsPanel.toggle() },
            Toggle(symbol: "rosette", help: "Standing (⌥⌘P)", isOn: model.showProgressPanel) { model.showProgressPanel.toggle() },
            Toggle(symbol: "key", help: "Leasing (⌥⌘L)", isOn: model.showLeasingPanel) { model.showLeasingPanel.toggle() },
            Toggle(symbol: "banknote", help: "Economy (⌥⌘M)", isOn: model.showEconomyPanel) { model.showEconomyPanel.toggle() },
            Toggle(symbol: "wrench.and.screwdriver", help: "Facilities (⌥⌘F)", isOn: model.showFacilitiesPanel) { model.showFacilitiesPanel.toggle() },
            Toggle(symbol: "bolt.horizontal", help: "Services overlay (⌥⌘U)", isOn: model.showServices) { model.showServices.toggle() },
        ]
        return t
    }

    var body: some View {
        Group {
            if Device.isPhone {
                bar(narrow: true)                                   // leaves room for the palette
            } else {
                ViewThatFits(in: .horizontal) {
                    bar(narrow: false)
                    bar(narrow: true)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func bar(narrow: Bool) -> some View {
        HStack(spacing: 2) {
            ControlButton(symbol: "line.3.horizontal", help: "Main Menu (⇧⌘M)") { model.openMainMenu() }
            ControlButton(symbol: "square.and.arrow.down", help: "Save (⌘S)") { model.save() }
            separator
            ControlButton(symbol: "minus.magnifyingglass", help: "Zoom Out (⌘−)") { model.zoom(by: 1 / 1.5) }
            ControlButton(symbol: "plus.magnifyingglass", help: "Zoom In (⌘=)") { model.zoom(by: 1.5) }
            separator
            ControlButton(symbol: "map", help: "Site Overview (⌘1)") { model.apply(.overview) }
            if !narrow {
                ControlButton(symbol: "building.columns", help: "Foundation (⌘2)") { model.apply(.foundation) }
                ControlButton(symbol: "scope", help: "Detail Close-up (⌘3)") { model.apply(.detail) }
                ControlButton(symbol: "building.2", help: "Skyline (⌘4)") { model.apply(.skyline) }
            }
            separator
            if narrow {
                ControlButton(symbol: "square.grid.2x2", help: "Panels and overlays",
                              isOn: model.showPanelPicker || toggles.contains { $0.isOn }) { model.showPanelPicker.toggle() }
            } else {
                ForEach(toggles) { t in ControlButton(symbol: t.symbol, help: t.help, isOn: t.isOn, action: t.action) }
                separator
            }
            if model.tutorial != nil {
                ControlButton(symbol: "graduationcap", help: "Tutorial", isOn: model.showTutorialPanel) { model.showTutorialPanel.toggle() }
            }
            ControlButton(symbol: "book", help: "Manual (⌘?)", isOn: model.showManual) { model.openManual() }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
    }

    private var separator: some View {
        Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 18).padding(.horizontal, 4)
    }
}

/// The narrow view controls' panel picker (F5): every panel and overlay with its name, in two
/// columns; a tap switches it and keeps the picker open.
struct PanelPicker: View {
    let model: AppModel

    var body: some View {
        let toggles = ViewControls(model: model).toggles
        let rows = stride(from: 0, to: toggles.count, by: 2).map { Array(toggles[$0..<min($0 + 2, toggles.count)]) }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Panels and overlays").font(.ui(.headline))
                Spacer()
                CloseButton { model.showPanelPicker = false }
            }
            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 4) {
                ForEach(rows.indices, id: \.self) { r in
                    GridRow {
                        ForEach(rows[r]) { t in
                            Button(action: t.action) {
                                Label(t.name, systemImage: t.symbol)
                                    .font(.ui(.callout))
                                    .foregroundStyle(t.isOn ? Color.accentColor : Color.primary)
                                    .padding(.horizontal, 8).padding(.vertical, 5)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(t.isOn ? 0.18 : 0.08)))
                                    .focusRing(cornerRadius: 7)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(t.isOn ? "On" : "")
                        }
                    }
                }
            }
        }
        .padding(12)
        .scaledFrame(width: 380, alignment: .leading)
        .panelCard()
        .environment(\.colorScheme, .dark)
    }
}

private struct ControlButton: View {
    let symbol: String
    let help: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 32, height: 28)
                .foregroundStyle(isOn ? Color.accentColor : Color.white.opacity(0.9))
                .contentShape(Rectangle())
        }
        .buttonStyle(ControlButtonStyle())
        .help(help)
        // "Elevator Traffic (⌥⌘T)" → "Elevator Traffic"; toggles report their state.
        .accessibilityLabel(help.components(separatedBy: " (").first ?? help)
        .accessibilityValue(isOn ? "On" : "")
    }
}

private struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0)))
            .focusRing(cornerRadius: 7)
    }
}
