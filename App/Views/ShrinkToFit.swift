import SwiftUI

/// Lays its one subview out as if it had `1 / scale` times the room, and takes up `scale`
/// times the subview's size; `scaled(_:)` then draws it that much smaller. Unlike a bare
/// `scaleEffect`, the smaller size is what the parent sees, so `ViewThatFits` can pick it.
private struct ScaledLayout: Layout {
    let scale: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let inner = ProposedViewSize(width: proposal.width.map { $0 / scale }, height: proposal.height.map { $0 / scale })
        let size = subviews.first?.sizeThatFits(inner) ?? .zero
        // A few points more than offered count as offered: a view laid out a little taller than
        // it measured (seen on the iPhone) then runs past its frame instead of growing the
        // screen. A view really too tall keeps its height, so `fitsScreen` can scroll it (0.29.4).
        let height = size.height * scale
        if let offered = proposal.height, height > offered, height <= offered + 12 {
            return CGSize(width: size.width * scale, height: offered)
        }
        return CGSize(width: size.width * scale, height: height)
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
    /// (0.29.4; side panels: see `PanelStack`). Where it fits, nothing changes.
    func shrinkToFit() -> some View {
        ViewThatFits(in: .vertical) {
            self
            scaled(0.9)
            scaled(0.8)
            scaled(0.75)
        }
        .fitsScreen()
    }

    /// For a full-screen card or a `ViewThatFits` ladder of them (0.29.4): centred on the
    /// screen, and scrolling where even its smallest form is taller than the screen, so nothing
    /// is cut off (a long briefing, many mods, a larger text size). See `ScreenFit`.
    func fitsScreen() -> some View {
        ScreenFit(content: self)
    }
}

/// Centres its content on the screen and puts it in a scroll view only when it is taller than
/// the screen. The scroll view sits outside any `ViewThatFits` ladder (inside one it gets its
/// tiny ideal height and vanishes), and only when needed: the capture tool draws the chrome
/// with `ImageRenderer`, which leaves scroll views blank, so screens that fit stay capturable.
private struct ScreenFit<Content: View>: View {
    let content: Content
    @State private var tooTall = false

    var body: some View {
        GeometryReader { geo in
            let inner = ProposedHeight(height: geo.size.height) { content }
                .onGeometryChange(for: Bool.self) { $0.size.height > geo.size.height + 1 } action: { tooTall = $0 }
            if tooTall {
                ScrollView(.vertical) { inner.frame(maxWidth: .infinity) }
                    .scrollBounceBehavior(.basedOnSize)
            } else {
                inner.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// Offers its subview `height` (the screen's) even inside a scroll view, which offers no height,
/// so a `ViewThatFits` inside still picks the step that fits; it takes the subview's real size,
/// which is taller than `height` only when no step fits, and then the scroll view scrolls.
private struct ProposedHeight: Layout {
    let height: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(ProposedViewSize(width: proposal.width, height: height)) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: CGPoint(x: bounds.midX, y: bounds.minY), anchor: .top,
                              proposal: ProposedViewSize(width: bounds.width, height: height))
    }
}
