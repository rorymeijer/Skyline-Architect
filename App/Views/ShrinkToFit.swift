import SwiftUI

/// Lays its one subview out as if it had `1 / scale` times the room, and takes up `scale`
/// times the subview's size; `scaled(_:)` then draws it that much smaller. Unlike a bare
/// `scaleEffect`, the smaller size is what the parent sees, so `ViewThatFits` can pick it.
private struct ScaledLayout: Layout {
    let scale: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let inner = ProposedViewSize(width: proposal.width.map { $0 / scale }, height: proposal.height.map { $0 / scale })
        let size = subviews.first?.sizeThatFits(inner) ?? .zero
        // Never more than offered: a view laid out a little taller than it measured (seen on
        // the iPhone) then runs a few points past its frame instead of growing the screen.
        return CGSize(width: size.width * scale, height: min(size.height * scale, proposal.height ?? .infinity))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.minY), anchor: .top,
                              proposal: ProposedViewSize(width: bounds.width / scale, height: bounds.height / scale))
    }
}

extension View {
    /// The view at `scale` (0…1) of its size, as a real layout size; taps still land where
    /// the controls are drawn.
    func scaled(_ scale: CGFloat) -> some View {
        ScaledLayout(scale: scale) { self }.scaleEffect(scale, anchor: .top)
    }

    /// Where the view is taller than the room it gets (an iPhone in landscape, 0.29.2), it is
    /// drawn in steps smaller, down to three quarters, and scrolls where even that is too tall
    /// (side panels: see `PanelStack`). Where it fits, nothing changes.
    func shrinkToFit() -> some View {
        ViewThatFits(in: .vertical) {
            self
            scaled(0.9)
            scaled(0.8)
            scaled(0.75).scrolling()
        }
    }

    /// The last step of a `ViewThatFits` ladder (0.29.4): the view keeps its width and scrolls
    /// vertically, so however long its content (a long briefing, many mods, a larger text
    /// size), nothing is cut off at the top or bottom of the screen.
    func scrolling() -> some View {
        ScrollingFallback(content: self)
    }
}

/// A vertical scroll view exactly as wide as its content. A bare `ScrollView` has a tiny ideal
/// width, so `fixedSize` would collapse it (seen in 0.29.4 CI: the card vanished); here the
/// content's own width is measured and given to the scroll view.
private struct ScrollingFallback<Content: View>: View {
    let content: Content
    @State private var width: CGFloat?

    var body: some View {
        ScrollView(.vertical) {
            content
                .fixedSize(horizontal: true, vertical: false)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: width)
    }
}
