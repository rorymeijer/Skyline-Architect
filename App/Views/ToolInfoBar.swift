import SwiftUI
import SkylineCore
import SkylinePresentation

/// The picked build tool (0.30.3): its icon, name, size and price, above the build palette,
/// before anything is placed. The palette may show icons only, and some tools look alike.
struct ToolInfoBar: View {
    let summary: ToolSummary
    let symbol: String
    /// Why it cannot be placed yet ("unlocks at Class B"), if so.
    var locked: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.title).font(.ui(.subheadline).weight(.semibold))
                Text(summary.line).font(.ui(.caption).monospacedDigit()).foregroundStyle(.secondary)
                if let detail = summary.detail { Text(detail).font(.ui(.caption2)).foregroundStyle(.secondary) }
                if let locked { Text(locked).font(.ui(.caption2)).foregroundStyle(Color.yellow) }
            }
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.7)))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .combine)
    }
}
