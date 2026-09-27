import SwiftUI
import SkylineCore
import SkylinePresentation

/// Construction tool palette (bottom center). Tools come from content: every room
/// definition in the catalog gets a button, grouped by category.
struct BuildPalette: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 2) {
            floorButton
            divider
            ForEach(groupedSpecs) { group in
                groupView(group)
            }
            demolishButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.12)))
        .environment(\.colorScheme, .dark)
    }

    private var floorButton: some View {
        let isOn: Bool = model.activeTool == ConstructionTool.floor
        return ToolButton(symbol: "square.stack.3d.up", title: "Floor",
                          help: "Build or extend floors — drag across columns (F)", isOn: isOn) {
            model.handleToolKey("floor")
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
        return ToolButton(symbol: Self.symbol(for: spec.appearance), title: Self.shortName(spec.name),
                          help: helpText(spec), isOn: isOn) {
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
        case "office": "briefcase"
        case "apartment": "bed.double"
        case "mechanical": "gearshape.2"
        case "parking": "car"
        default: "square.dashed"
        }
    }
}

private struct ToolButton: View {
    let symbol: String
    let title: String
    let help: String
    var isOn: Bool
    var tint: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                Text(title).font(.system(size: 9, weight: .medium)).lineLimit(1)
            }
            .frame(width: 58, height: 40)
            .foregroundStyle(isOn ? Color.white : Color.white.opacity(0.85))
            .background(RoundedRectangle(cornerRadius: 8).fill(isOn ? tint.opacity(0.85) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .help(help)
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Session status: cash, save state, active-tool hint.
struct StatusPill: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Label(Money.format(model.economy.cash), systemImage: "banknote")
                .foregroundStyle(model.economy.cash < 0 ? Color.red : Color.primary)
                .help("Cash. Construction is paid immediately; rent and costs settle daily at 06:00 (⌥⌘M).")
            if let save = model.lastSaveDescription {
                Text(save).foregroundStyle(.secondary)
            }
            if model.activeTool != nil {
                Text("Esc to stop building").foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.black.opacity(0.55)))
        .environment(\.colorScheme, .dark)
    }
}

/// Sheet listing local saves (newest first).
struct LoadGameSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Load Game").font(.title2.bold())
            let saves = model.availableSaves()
            if saves.isEmpty {
                Text("No saves yet. Use File ▸ Save (⌘S).").foregroundStyle(.secondary)
            } else {
                List(saves, id: \.slot) { info in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(info.metadata?.title ?? info.slot).font(.headline)
                            Text("\(info.slot) · \(info.metadata.map { $0.savedAt.formatted(date: .abbreviated, time: .shortened) } ?? "unreadable")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Load") {
                            if model.load(slot: info.slot) { dismiss() }
                        }
                    }
                }
                .frame(minHeight: 200)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}
