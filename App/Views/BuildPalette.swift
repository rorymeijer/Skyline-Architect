import SwiftUI
import SkylineCore
import SkylinePresentation

/// Construction tool palette (bottom center). Tools come from content: every room
/// definition in the catalog gets a button, grouped by category.
struct BuildPalette: View {
    let model: AppModel

    var body: some View {
        // Mods can add any number of room types: when the labelled tools do not fit the
        // window, the palette shows icons only (names stay in the tooltips). Pure SwiftUI, so
        // captures render it exactly as the window does.
        ViewThatFits(in: .horizontal) {
            tools(compact: false)
            tools(compact: true)
            grouped                                                 // F5: a phone's width
        }
        .environment(\.colorScheme, .dark)
    }

    /// The narrowest palette (F5, an iPhone): one button per category; the picked
    /// category's tools open in a row above.
    private var grouped: some View {
        let groups = groupedSpecs
        let open = groups.first { $0.id == model.paletteCategory }
        return VStack(spacing: 6) {
            if let open {
                HStack(spacing: 2) { ForEach(open.specs, id: \.id) { specButton($0) } }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.12)))
            }
            HStack(spacing: 2) {
                floorButton
                foundationButton
                divider
                ForEach(groups) { group in
                    let holdsTool = group.specs.contains { model.activeTool == .room($0.id) }
                    ToolButton(symbol: Self.symbol(for: group.specs.first?.appearance ?? ""), title: Self.categoryName(group.id),
                               help: "\(Self.categoryName(group.id)): \(group.specs.map(\.name).joined(separator: ", "))",
                               isOn: open?.id == group.id || holdsTool) {
                        model.paletteCategory = open?.id == group.id ? nil : group.id
                    }
                }
                divider
                demolishButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.12)))
        }
    }

    /// A category's name on its button (content ids; a mod's own category shows capitalised).
    static func categoryName(_ id: String) -> String {
        switch id {
        case "circulation": "Circulation"
        case "office": "Offices"
        case "residential": "Homes"
        case "infrastructure": "Plant"
        case "amenity": "Amenities"
        default: id.prefix(1).uppercased() + id.dropFirst()
        }
    }

    private func tools(compact: Bool) -> some View {
        HStack(spacing: 2) {
            floorButton
            foundationButton
            divider
            ForEach(groupedSpecs) { group in
                groupView(group)
            }
            demolishButton
        }
        .environment(\.compactPalette, compact)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.12)))
    }

    private var floorButton: some View {
        let isOn: Bool = model.activeTool == ConstructionTool.floor
        return ToolButton(symbol: "square.stack.3d.up", title: "Floor",
                          help: "Build or extend floors — drag across columns (F)", isOn: isOn) {
            model.handleToolKey("floor")
        }
    }

    /// Opens the foundation panel (0.21): not a placement tool, the panel's buttons act.
    private var foundationButton: some View {
        ToolButton(symbol: "building.columns", title: "Foundation", help: "Widen or deepen the foundation, lengthen the piles",
                   isOn: model.showFoundationPanel) {
            model.toggleFoundationPanel()
        }
    }

    private var demolishButton: some View {
        let isOn: Bool = model.activeTool == ConstructionTool.demolish
        return ToolButton(symbol: "hammer", title: "Demolish", help: "Remove a room, or an empty floor (X)",
                          isOn: isOn, tint: Color.orange) {
            model.handleToolKey("demolish")
        }
    }

    private func groupView(_ group: Group) -> some View {
        HStack(spacing: 2) {
            ForEach(group.specs, id: \.id) { spec in
                specButton(spec)
            }
            divider
        }
    }

    private func specButton(_ spec: RoomSpec) -> some View {
        let tool = ConstructionTool.room(spec.id)
        let isOn: Bool = model.activeTool == tool
        let locked = model.lockReason(of: spec.id)
        return ToolButton(symbol: Self.symbol(for: spec.appearance), title: Self.shortName(spec.name),
                          help: locked.map { "\(spec.name) — \($0)" } ?? helpText(spec), isOn: isOn, locked: locked != nil) {
            model.select(tool: isOn ? nil : tool)
        }
    }

    private struct Group: Identifiable {
        let id: String
        let specs: [RoomSpec]
    }

    /// Specs grouped by category, in content order.
    private var groupedSpecs: [Group] {
        guard let catalog = model.catalog else { return [] }
        var order: [String] = []
        var groups: [String: [RoomSpec]] = [:]
        for spec in catalog.specs {
            if groups[spec.category] == nil { order.append(spec.category) }
            groups[spec.category, default: []].append(spec)
        }
        return order.map { Group(id: $0, specs: groups[$0] ?? []) }
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1, height: 34).padding(.horizontal, 3)
    }

    private func helpText(_ spec: RoomSpec) -> String {
        let width = spec.minWidth == spec.maxWidth ? "\(spec.minWidth) m" : "\(spec.minWidth)–\(spec.maxWidth) m"
        let how = spec.kind == .shaft ? "drag vertically across floors" : "drag to set the width"
        return "\(spec.name): \(width), \(Money.format(spec.costPerModule)) per m² module — \(how)"
    }

    static func shortName(_ name: String) -> String {
        name.replacingOccurrences(of: "Small ", with: "").replacingOccurrences(of: "Studio ", with: "")
            .replacingOccurrences(of: " Room", with: "").replacingOccurrences(of: " Level", with: "")
            .replacingOccurrences(of: " Shaft", with: "")
    }

    /// Presentation choice: an icon per appearance key (content stays icon-agnostic).
    static func symbol(for appearance: String) -> String {
        switch appearance {
        case "lobby": "door.left.hand.open"
        case "corridor": "arrow.left.and.right"
        case "stairs": "stairs"
        case "elevatorShaft": "arrow.up.arrow.down.square"
        case "expressElevatorShaft": "arrow.up.arrow.down.circle"
        case "office": "briefcase"
        case "apartment": "bed.double"
        case "mechanical": "gearshape.2"
        case "electrical": "bolt"
        case "telecom": "antenna.radiowaves.left.and.right"
        case "parking": "car"
        case "fireControl": "drop.triangle"
        case "shop": "bag"
        case "restaurant": "fork.knife"
        case "fitness": "dumbbell"
        case "cinema": "film"
        case "theater": "theatermasks"
        case "skyBar": "wineglass"
        case "waste": "trash"
        case "staffRoom": "person.2"
        default: "square.dashed"
        }
    }
}

private struct CompactPaletteKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Icon-only tool buttons (the palette is wider than the window).
    fileprivate var compactPalette: Bool {
        get { self[CompactPaletteKey.self] }
        set { self[CompactPaletteKey.self] = newValue }
    }
}

private struct ToolButton: View {
    @Environment(\.compactPalette) private var compact
    let symbol: String
    let title: String
    let help: String
    var isOn: Bool
    var tint: Color = .accentColor
    /// Not yet available in this game (standard game, Phase 11): dimmed with a lock.
    var locked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                if !compact { Text(title).font(.system(size: 9, weight: .medium)).lineLimit(1) }
            }
            .frame(width: compact ? 36 : 58, height: 40)
            .foregroundStyle(isOn ? Color.white : Color.white.opacity(locked ? 0.35 : 0.85))
            .background(RoundedRectangle(cornerRadius: 8).fill(isOn ? tint.opacity(0.85) : Color.clear))
            .overlay(alignment: .topTrailing) {
                if locked { Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(Color.yellow.opacity(0.9)).padding(3) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(locked)
        .help(help)
        // The compact palette shows icons only: VoiceOver still needs the name (Phase 20).
        .accessibilityLabel(title)
        .accessibilityHint(help)
        .accessibilityValue(locked ? "Locked" : isOn ? "Selected" : "")
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1).focusRing(cornerRadius: 8)
    }
}

/// Session status: cash, save state, active-tool hint.
struct StatusPill: View {
    let model: AppModel
    /// Beside an iPhone's view controls (F5): cash and standing only.
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            Label(Money.format(model.economy.cash), systemImage: "banknote")
                .foregroundStyle(model.economy.cash < 0 ? Color.red : Color.primary)
                .help("Cash. Construction is paid immediately; rent and costs settle daily at 06:00 (⌥⌘M).")
            Label("\(model.progression.className) · \(Int(model.progression.reputation.rounded()))", systemImage: "rosette")
                .help("Building class and reputation (⌥⌘P).")
            if !compact, let save = model.lastSaveDescription {
                Text(save).foregroundStyle(.secondary)
            }
            if !compact, model.activeTool != nil {
                #if os(iOS)
                Text("Tap or drag to place · two fingers pan").foregroundStyle(.secondary)
                #else
                Text("Esc to stop building").foregroundStyle(.secondary)
                #endif
            }
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .environment(\.colorScheme, .dark)
    }
}
