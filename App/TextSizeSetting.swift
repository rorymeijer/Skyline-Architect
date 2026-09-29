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

/// Text that follows the player's text size on every platform (F4). An iPad scales text
/// styles by Dynamic Type itself; a Mac does not, so there `Font.ui` sizes the Mac's text
/// styles by `macScale`, set from the player's choice.
enum UIText {
    static var macScale = 1.0

    /// The growth in effect: the Mac's factor, or the iPad's Dynamic Type.
    static func current(_ dynamicType: DynamicTypeSize) -> Double {
        #if os(macOS)
        macScale
        #else
        factor(dynamicType)
        #endif
    }

    /// Growth of text for a Dynamic Type size, relative to the standard (large) size.
    static func factor(_ size: DynamicTypeSize?) -> Double {
        switch size {
        case nil, .large?: 1
        case .xSmall?, .small?, .medium?: 0.94
        case .xLarge?: 1.12
        case .xxLarge?: 1.24
        case .xxxLarge?: 1.36
        default: 1.6                                             // accessibility sizes, capped for panels
        }
    }
}

extension Font {
    /// A text style that scales with the text size setting (use instead of `.caption` etc.).
    static func ui(_ style: Font.TextStyle) -> Font {
        #if os(macOS)
        let (size, weight): (CGFloat, Font.Weight) = switch style {
        case .largeTitle: (26, .regular)
        case .title: (22, .regular)
        case .title2: (17, .regular)
        case .title3: (15, .regular)
        case .headline: (13, .bold)
        case .subheadline: (11, .regular)
        case .callout: (12, .regular)
        case .footnote, .caption, .caption2: (10, .regular)
        default: (13, .regular)
        }
        return .system(size: size * UIText.macScale, weight: weight)
        #else
        return .system(style)
        #endif
    }
}

/// A fixed width that grows with the text (panels, columns), so larger text wraps less.
private struct ScaledFrame: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicType
    let width: CGFloat
    let alignment: Alignment

    func body(content: Content) -> some View {
        content.frame(width: width * UIText.current(dynamicType), alignment: alignment)
    }
}

extension View {
    func scaledFrame(width: CGFloat, alignment: Alignment = .center) -> some View {
        modifier(ScaledFrame(width: width, alignment: alignment))
    }
}
