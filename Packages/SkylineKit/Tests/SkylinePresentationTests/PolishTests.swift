import Foundation
import Testing
import SkylineCore
@testable import SkylinePresentation

/// Phase 20: clouds and the app icon.
@Suite struct PolishTests {
    @Test func cloudsAreDeterministicAndFollowCover() {
        let a = CloudView.clouds(seed: 7301, time: 3600, cover: 0.2, centerX: 30)
        #expect(a == CloudView.clouds(seed: 7301, time: 3600, cover: 0.2, centerX: 30))
        #expect(a != CloudView.clouds(seed: 4411, time: 3600, cover: 0.2, centerX: 30))
        let overcast = CloudView.clouds(seed: 7301, time: 3600, cover: 1, centerX: 30)
        #expect(a.count == 10 && overcast.count == 30)
        #expect(overcast.map(\.opacity).max()! > a.map(\.opacity).max()!)
        #expect(a.allSatisfy { $0.center.y >= 180 && $0.center.y < 820 && $0.size.x > 0 })
    }

    /// Clouds drift with game time (paused game, still sky) and wrap around the field.
    @Test func cloudsDriftWithGameTime() {
        let now = CloudView.clouds(seed: 1, time: 0, cover: 0.5, centerX: 0)
        let later = CloudView.clouds(seed: 1, time: 60, cover: 0.5, centerX: 0)
        for (a, b) in zip(now, later) {
            let dx = b.center.x - a.center.x
            #expect(dx > 0 && dx < 60 * CloudView.wind * 1.5 || dx < -2000)   // moved east, or wrapped
            #expect(a.center.y == b.center.y)
        }
        let view = Rect(minX: -200, minY: 0, maxX: 200, maxY: 1000)
        #expect(CloudView.clouds(seed: 1, time: 0, cover: 0.5, centerX: 0, visible: view).allSatisfy {
            abs($0.center.x) < 200 + $0.size.x / 2
        })
    }

    @Test func iconIsDrawnInsideItsCanvas() {
        for rounded in [true, false] {
            let d = IconArt.drawing(rounded: rounded)
            #expect(d.items.count > 60)
            #expect(d.items.allSatisfy { IconArt.canvas.contains($0.shape.bounds) })
        }
        let svg = SVGRenderer.render(drawing: IconArt.drawing(rounded: true), view: IconArt.canvas, pixels: 1024)
        #expect(svg.hasPrefix("<svg") && svg.contains("width=\"1024\"") && svg.contains("linearGradient"))
        #expect(svg == SVGRenderer.render(drawing: IconArt.drawing(rounded: true), view: IconArt.canvas, pixels: 1024))
    }
}
