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
    /// drawn in steps smaller, down to three quarters (side panels: see `PanelStack`). Where it fits, nothing changes.
    func shrinkToFit() -> some View {
        ViewThatFits(in: .vertical) {
            self
            scaled(0.9)
            scaled(0.8)
            scaled(0.75)
        }
    }
}
