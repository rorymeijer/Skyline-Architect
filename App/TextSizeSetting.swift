import SwiftUI

/// The player's text size for panels and menus (F4), kept in the user defaults.
enum TextSizeSetting {
    static let defaultsKey = "SkylineArchitect.textSize"

    /// The choices offered: the system size (nil), then three steps larger.
    static let choices: [(name: String, size: DynamicTypeSize?)] = [
        ("Standard", nil), ("Large", .xLarge), ("Larger", .xxLarge), ("Largest", .xxxLarge),
    ]

    static func name(_ size: DynamicTypeSize?) -> String { choices.first { $0.size == size }?.name ?? "Standard" }

    static func key(_ size: DynamicTypeSize) -> String {
        switch size {
        case .xLarge: "xLarge"
        case .xxLarge: "xxLarge"
        case .xxxLarge: "xxxLarge"
        default: "system"
        }
    }

    static func load() -> DynamicTypeSize? {
        switch UserDefaults.standard.string(forKey: defaultsKey) {
        case "xLarge": .xLarge
        case "xxLarge": .xxLarge
        case "xxxLarge": .xxxLarge
        default: nil
        }
    }

    /// The next choice (the main menu's button cycles through them).
    static func next(after size: DynamicTypeSize?) -> DynamicTypeSize? {
        let i = choices.firstIndex { $0.size == size } ?? 0
        return choices[(i + 1) % choices.count].size
    }
}

extension View {
    /// Applies the player's text size when one is set; otherwise the system's.
    @ViewBuilder
    func textSize(_ size: DynamicTypeSize?) -> some View {
        if let size { dynamicTypeSize(size) } else { self }
    }
}
