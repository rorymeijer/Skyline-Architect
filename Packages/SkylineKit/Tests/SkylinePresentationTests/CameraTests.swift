import Testing
import SkylineCore
@testable import SkylinePresentation

@Suite struct CameraTests {
    let bounds = Rect(minX: -40, minY: -60, maxX: 88, maxY: 3000)
    func makeCamera(zoom: Double = 10) -> Camera2D {
        Camera2D(center: Vec2(24, 10), zoom: zoom, viewportSize: Vec2(1440, 900), limits: .standard(bounds: bounds))
    }

    @Test func screenWorldRoundTrip() {
        let cam = makeCamera()
        for s in [Vec2(0, 0), Vec2(720, 450), Vec2(1439, 3)] {
            let back = cam.worldToScreen(cam.screenToWorld(s))
            #expect(abs(back.x - s.x) < 1e-9 && abs(back.y - s.y) < 1e-9)
        }
        #expect(cam.worldToScreen(cam.center) == Vec2(720, 450))
    }

    @Test func zoomKeepsAnchorFixed() {
        var cam = makeCamera(zoom: 10)
        let anchor = Vec2(1000, 300)
        let worldBefore = cam.screenToWorld(anchor)
        cam.setZoom(14, anchoredAt: anchor)
        let worldAfter = cam.screenToWorld(anchor)
        #expect(abs(worldAfter.x - worldBefore.x) < 1e-9)
        #expect(abs(worldAfter.y - worldBefore.y) < 1e-9)
    }

    @Test func zoomIsClampedToLimits() {
        var cam = makeCamera()
        cam.setZoom(10_000, anchoredAt: Vec2(0, 0))
        #expect(cam.zoom == cam.limits.maxZoom)
        cam.setZoom(0.0001, anchoredAt: Vec2(0, 0))
        #expect(cam.zoom == cam.limits.minZoom)
    }

    @Test func viewStaysInsideBoundsWhenSmallerThanBounds() {
        var cam = makeCamera(zoom: 20)
        cam.pan(byScreenDelta: Vec2(1_000_000, 0))  // try to drag far to the right
        #expect(cam.visibleRect.minX >= bounds.minX - 1e-9)
        cam.pan(byScreenDelta: Vec2(0, 1_000_000))
        #expect(cam.visibleRect.minY >= bounds.minY - 1e-9)
    }

    @Test func centersAxisWhenViewLargerThanBounds() {
        let cam = makeCamera(zoom: 1)  // 1440 m wide view, 128 m wide bounds
        #expect(cam.center.x == (bounds.minX + bounds.maxX) / 2)
    }

    @Test func panMovesContentWithTheDrag() {
        var cam = makeCamera(zoom: 20)  // view (72 m) narrower than bounds (128 m)
        let p = Vec2(24, 10)
        let before = cam.worldToScreen(p)
        cam.pan(byScreenDelta: Vec2(50, -20))
        let after = cam.worldToScreen(p)
        #expect(abs(after.x - before.x - 50) < 1e-9 && abs(after.y - before.y + 20) < 1e-9)
    }

    @Test func frameFitsRect() {
        var cam = makeCamera()
        let r = Rect(minX: 0, minY: -20, maxX: 48, maxY: 2)
        cam.frame(r, padding: 0)
        #expect(cam.visibleRect.contains(r.insetBy(dx: 0.001, dy: 0.001)))
    }
}

@Suite struct CameraControllerTests {
    func makeController() -> CameraController {
        CameraController(camera: Camera2D(center: Vec2(24, 100), zoom: 10, viewportSize: Vec2(1440, 900),
                                          limits: .standard(bounds: Rect(minX: -1000, minY: -60, maxX: 1000, maxY: 3000))))
    }

    @Test func animatedZoomConvergesAndKeepsAnchor() {
        var c = makeController()
        let anchor = Vec2(300, 700)
        let world = c.camera.screenToWorld(anchor)
        c.zoom(by: 2, at: anchor, animated: true)
        for _ in 0..<240 { c.update(dt: 1.0 / 60) }
        #expect(abs(c.camera.zoom - 20) < 1e-6)
        let w2 = c.camera.screenToWorld(anchor)
        #expect(abs(w2.x - world.x) < 1e-6 && abs(w2.y - world.y) < 1e-6)
        #expect(!c.isAnimating)
    }

    /// Frame-rate independence: the same wall time yields (nearly) the same zoom.
    @Test func zoomAnimationIsFrameRateIndependent() {
        var a = makeController(), b = makeController()
        a.zoom(by: 3, at: Vec2(720, 450), animated: true)
        b.zoom(by: 3, at: Vec2(720, 450), animated: true)
        for _ in 0..<30 { a.update(dt: 1.0 / 60) }   // 0.5 s at 60 fps
        for _ in 0..<60 { b.update(dt: 1.0 / 120) }  // 0.5 s at 120 fps
        #expect(abs(a.camera.zoom - b.camera.zoom) / a.camera.zoom < 1e-9)
    }

    @Test func dragReleaseProducesDecayingInertia() {
        var c = makeController()
        c.beginDrag(at: 0)
        for i in 1...6 { c.drag(by: Vec2(10, 0), at: Double(i) / 60) }
        c.endDrag(at: 6.0 / 60)
        let x0 = c.camera.center.x
        c.update(dt: 1.0 / 60)
        let x1 = c.camera.center.x
        #expect(x1 < x0)  // content keeps moving right ⇒ center moves left
        for _ in 0..<600 { c.update(dt: 1.0 / 60) }
        #expect(!c.isAnimating)
    }

    @Test func pausedDragBeforeReleaseHasNoInertia() {
        var c = makeController()
        c.beginDrag(at: 0)
        c.drag(by: Vec2(40, 0), at: 0.01)
        c.drag(by: Vec2(40, 0), at: 0.02)
        c.endDrag(at: 1.0)  // held still for a second before releasing
        let before = c.camera
        c.update(dt: 1.0 / 60)
        #expect(c.camera == before)
    }

    @Test func keyboardPanMovesView() {
        var c = makeController()
        c.keyboardPan = Vec2(1, 0)  // "move view right"
        let x0 = c.camera.center.x
        c.update(dt: 0.1)
        #expect(c.camera.center.x > x0)
    }
}

@Suite struct DetailLevelTests {
    @Test func initialLevelFromZoom() {
        let p = DetailLevelPolicy()
        #expect(p.level(forZoom: 0.5, current: nil) == .skyline)
        #expect(p.level(forZoom: 10, current: nil) == .floors)
        #expect(p.level(forZoom: 96, current: nil) == .interior)
    }

    @Test func hysteresisPreventsFlicker() {
        let p = DetailLevelPolicy(hysteresis: 0.1)
        // Just above the floors threshold (5): staying at massing until 5.5.
        #expect(p.level(forZoom: 5.2, current: .massing) == .massing)
        #expect(p.level(forZoom: 5.6, current: .massing) == .floors)
        // Just below the threshold: staying at floors until below 4.5.
        #expect(p.level(forZoom: 4.8, current: .floors) == .floors)
        #expect(p.level(forZoom: 4.4, current: .floors) == .massing)
        // Large jumps skip bands.
        #expect(p.level(forZoom: 80, current: .skyline) == .interior)
    }
}
