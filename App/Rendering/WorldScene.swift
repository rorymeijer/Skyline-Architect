import Foundation
import QuartzCore
import SpriteKit
import SkylineCore
import SkylinePresentation
import SkylineSimulation

/// Renders one property. The scene is the viewport (size = view size, anchor bottom-left,
/// scene coordinates = view points); `worldRoot` carries the camera transform
/// (DECISIONS D-004). Holds no game state: everything drawn comes from the composition,
/// which is derived from the authoritative model.
final class WorldScene: SKScene {
    private(set) var composition: SiteComposition
    private(set) var controller: CameraController
    private let palette: ArtPalette
    private let worldRoot = SKNode()
    private let tileLayer: TileLayer
    /// Night lights of the site, added over the graded scene (Phase 12).
    private let emissionLayer: TileLayer
    /// Street lamp glow: static, on all night while city windows go out.
    private let lampLayer: TileLayer
    private let gridOverlay: GridOverlayNode
    private let roomLabelLayer = RoomLabelLayer()
    private let placementOverlay: PlacementOverlayNode
    private let lodPolicy = DetailLevelPolicy()
    private(set) var detailLevel: DetailLevel = .floors

    /// Display density of the hosting view (set by the platform view).
    var backingScale: CGFloat = 2 { didSet { if backingScale != oldValue { cameraDirty = true } } }
    var showGrid = true { didSet { gridOverlay.isHidden = !showGrid; overlayDirty = true } }
    /// Cursor position in scene (= view) points, or nil when outside the view.
    var hoverPoint: CGPoint? { didSet { overlayDirty = true } }
    /// Receives diagnostics at ~4 Hz (main thread).
    var onDiagnostics: ((RenderDiagnostics) -> Void)?
    /// Called once when the scene is first presented with a real size.
    var onReady: (() -> Void)?
    /// Called at the start of every frame with the real time step (drives the simulation).
    var onFrame: ((Double) -> Void)?
    /// Visible people for the current view (from the model; the scene only draws them).
    var peopleProvider: ((Rect, Double) -> [PersonSprite])?
    private let agentLayer = AgentLayer()
    var carProvider: ((Rect, Double) -> [CarSprite])?
    private let elevatorLayer = ElevatorLayer()

    // Construction interaction. The scene only tracks pointer state; rules and previews
    // come from the model through these closures (no game logic in the renderer).
    /// The active construction tool (nil = camera only).
    var activeTool: ConstructionTool? { didSet { placementAnchor = nil; heldEnd = nil; overlayDirty = true } }
    /// Touch (0.30): a placement is held once the finger lifts, instead of being built. Its end
    /// moves with a tap, a new drag or the ± buttons; Place builds it (`confirmHeldPlacement`).
    /// Two fingers still pan, so the far end of a long room can be reached first.
    var holdsPlacement = false
    /// The held placement's end cell (nil = nothing held).
    private(set) var heldEnd: GridCell?
    /// Told whenever the held placement's preview changes (nil when nothing is held).
    var onHeldPreview: ((PlacementPreview?) -> Void)?
    private var reportedHeld: PlacementPreview?
    var previewProvider: ((ConstructionTool, GridCell, GridCell) -> PlacementPreview?)?
    /// The build catalog, for where a tap moves a held placement (0.30.2).
    var catalogProvider: (() -> BuildCatalog?)?
    var roomLabelProvider: ((Rect, Double) -> [RoomLabel])?
    /// Developer navigation overlay data (nil = hidden). Asked every frame while set.
    var navigationProvider: (() -> NavigationOverlay?)?
    private let navigationOverlay = NavigationOverlayNode()
    /// Elevator traffic overlay data (nil = hidden). Asked every frame.
    var trafficProvider: (() -> ElevatorTraffic?)?
    private let trafficOverlay = TrafficOverlayNode()
    /// Click without a tool (a room inspector request); nil cell = empty space.
    var onSelect: ((GridCell?) -> Void)?
    /// World rectangle of the selected room, outlined on screen.
    var selectionRect: Rect? { didSet { overlayDirty = true } }
    private let selectionOutline = SKShapeNode()
    /// Daylight (0…1) and lit rooms for the visible area; nil = always day.
    /// Grade, darkness and lit rooms for the visible rect at a zoom (Phase 12).
    /// `activity`: share of the city's windows still lit (`DayNight.cityActivity`).
    var lightingProvider: ((Rect, Double) -> (grade: Grade, darkness: Double, emission: Double, activity: Double, rooms: [LitRoom]))?
    private let dayNight = DayNightLayer()
    /// Weather look and roofs for snow (Phase 13).
    var weatherProvider: ((Rect) -> (look: WeatherLook, roofs: [Rect], street: [ClosedRange<Double>]))?
    private let weather = WeatherLayer()
    /// Clouds in view (Phase 20), world meters.
    var cloudProvider: ((Rect) -> [CloudPuff])?
    private let clouds = CloudLayer()
    /// Burning rooms and fire engines (Phase 14).
    var fireProvider: (() -> (flames: [FlameMark], engines: [Vec2], scorched: [ScorchMark]))?
    private let fire = FireLayer()
    /// Services overlay marks (nil = hidden). Asked every frame.
    var servicesProvider: (() -> [ServiceMark]?)?
    private let servicesOverlay = ServicesOverlayNode()
    var onCommit: ((BuildCommand) -> Void)?
    private var placementAnchor: GridCell?
    /// Camera placement to use when first presented (nil = site overview).
    var initialPlacement: (center: Vec2, zoom: Double)?
    /// Current preview (for diagnostics and captures).
    private(set) var currentPreview: PlacementPreview?

    private var cameraDirty = true
    private var overlayDirty = true
    private var didPlaceInitialCamera = false
    private var lastUpdateTime: TimeInterval?

    // Diagnostics accumulators.
    private var statFrames = 0
    private var statElapsed = 0.0
    private var statUpdateSeconds = 0.0
    private var statSections: [String: Double] = [:]
    private var lastDiagnostics = RenderDiagnostics()

    init(composition: SiteComposition, palette: ArtPalette = .standard) {
        self.composition = composition
        self.palette = palette
        let initial = Camera2D(center: composition.siteRect.center, zoom: 8, viewportSize: Vec2(1440, 900),
                               limits: .standard(bounds: composition.cameraBounds, bottomInset: Self.bottomInterfaceInset))
        controller = CameraController(camera: initial)
        tileLayer = TileLayer(composition: composition)
        emissionLayer = TileLayer(composition: composition, budget: 48, blendMode: .add, clearsOccluders: true) { [$0.emission] }
        lampLayer = TileLayer(composition: composition, budget: 16, blendMode: .add) { [$0.lamps] }
        gridOverlay = GridOverlayNode(palette: palette)
        placementOverlay = PlacementOverlayNode(palette: palette)
        super.init(size: CGSize(width: 1440, height: 900))
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = composition.sky.zenith.skColor
        buildNodes()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildNodes() {
        addChild(worldRoot)

        // Sky: a stretched 1-D gradient anchored at grade (world space).
        let midX = composition.siteRect.center.x
        if let image = DrawingRasterizer.verticalGradientImage(composition.sky) {
            let texture = SKTexture(cgImage: image)
            texture.filteringMode = .linear
            let sky = SKSpriteNode(texture: texture)
            sky.anchorPoint = CGPoint(x: 0.5, y: 0)
            sky.position = CGPoint(x: midX, y: 0)
            sky.size = CGSize(width: 40_000, height: composition.sky.top)
            sky.zPosition = -10
            worldRoot.addChild(sky)
        }
        // Clouds drift between the sky and the skyline (Phase 20).
        clouds.node.zPosition = -9
        worldRoot.addChild(clouds.node)
        // Solid rock below the composed ground section (visible only at extreme zoom-out).
        let deep = SKSpriteNode(color: palette.soil(.bedrock).shaded(0.55).skColor, size: CGSize(width: 40_000, height: 20_000))
        deep.anchorPoint = CGPoint(x: 0.5, y: 1)
        deep.position = CGPoint(x: midX, y: composition.siteRect.minY)
        deep.zPosition = -5
        worldRoot.addChild(deep)

        worldRoot.addChild(tileLayer.node)
        dayNight.tint.zPosition = 8
        addChild(dayNight.tint)
        dayNight.lights.zPosition = 9
        worldRoot.addChild(dayNight.lights)
        weather.ground.zPosition = 3.5
        worldRoot.addChild(weather.ground)
        fire.node.zPosition = 9.2
        worldRoot.addChild(fire.node)
        weather.fog.zPosition = 9.5
        addChild(weather.fog)
        weather.rain.zPosition = 9.6
        addChild(weather.rain)
        weather.snow.zPosition = 9.6
        addChild(weather.snow)
        weather.flash.zPosition = 9.7
        addChild(weather.flash)
        emissionLayer.node.zPosition = 9
        emissionLayer.node.isHidden = true
        worldRoot.addChild(emissionLayer.node)
        lampLayer.node.zPosition = 9
        lampLayer.node.isHidden = true
        worldRoot.addChild(lampLayer.node)
        elevatorLayer.node.zPosition = 4
        worldRoot.addChild(elevatorLayer.node)
        agentLayer.node.zPosition = 5
        worldRoot.addChild(agentLayer.node)
        gridOverlay.zPosition = 10
        addChild(gridOverlay)
        navigationOverlay.zPosition = 12
        addChild(navigationOverlay)
        trafficOverlay.zPosition = 12.5
        addChild(trafficOverlay)
        servicesOverlay.zPosition = 10.5
        addChild(servicesOverlay)
        selectionOutline.zPosition = 11
        selectionOutline.strokeColor = SKColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1)
        selectionOutline.fillColor = SKColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 0.10)
        selectionOutline.lineWidth = 2
        addChild(selectionOutline)
        roomLabelLayer.zPosition = 13
        addChild(roomLabelLayer)
        placementOverlay.zPosition = 14
        addChild(placementOverlay)
    }

    /// Replaces the whole composition when the site itself changed (a deeper or wider
    /// foundation: the ground section and camera bounds follow). Every tile re-renders.
    func replaceComposition(_ c: SiteComposition) {
        composition = c
        tileLayer.replace(composition: c, dirty: nil)
        emissionLayer.replace(composition: c, dirty: nil)
        lampLayer.replace(composition: c, dirty: nil)
        controller.setLimits(.standard(bounds: c.cameraBounds, bottomInset: Self.bottomInterfaceInset))
        cameraDirty = true
        overlayDirty = true
    }

    /// Redraws labels and overlays on the next frame (a setting they show changed).
    func invalidateOverlays() { overlayDirty = true }

    /// Replaces the composition after construction; only tiles in `dirty` re-render.
    func updateComposition(_ c: SiteComposition, dirty: Rect?) {
        composition = c
        tileLayer.replace(composition: c, dirty: dirty)
        emissionLayer.replace(composition: c, dirty: dirty)   // building silhouettes moved
        overlayDirty = true
    }

    // MARK: Placement (pointer state only)

    private func cell(at point: CGPoint) -> GridCell {
        composition.grid.cell(at: controller.camera.screenToWorld(Vec2(point)))
    }

    func beginPlacement(at point: CGPoint) {
        guard activeTool != nil else { return }
        let here = cell(at: point)
        // Touch: a drag that starts at the held placement's end moves that end; any other
        // drag starts a new placement.
        if let end = heldEnd, abs(end.column - here.column) <= 1, abs(end.floor - here.floor) <= 1 {
            heldEnd = nil
        } else {
            heldEnd = nil
            placementAnchor = here
        }
        hoverPoint = point
    }

    func updatePlacement(at point: CGPoint) {
        hoverPoint = point
    }

    /// Commits the preview under the pointer if it is valid (touch: holds it instead).
    func endPlacement(at point: CGPoint) {
        guard let tool = activeTool, let anchor = placementAnchor else { return }
        if holdsPlacement {
            heldEnd = cell(at: point)
            hoverPoint = nil
            return
        }
        hoverPoint = point
        let preview = previewProvider?(tool, anchor, cell(at: point))
        placementAnchor = nil
        overlayDirty = true
        if let command = preview?.command, preview?.isValid == true { onCommit?(command) }
    }

    /// A click or tap without a tool: select what is under it.
    func select(at point: CGPoint) {
        onSelect?(cell(at: point))
    }

    func cancelPlacement() {
        placementAnchor = nil
        heldEnd = nil
        overlayDirty = true
    }

    /// A tap with a tool on touch (0.30): the first holds a placement of the smallest size
    /// there; later taps move its end to the tapped cell, or, on another floor, move the
    /// whole room or floor there (0.30.2).
    func holdPlacement(at point: CGPoint) {
        guard let tool = activeTool else { return }
        let here = cell(at: point)
        if let anchor = placementAnchor, let end = heldEnd, let catalog = catalogProvider?() {
            let next = PlacementPlanner.tapped(here, anchor: anchor, end: end, tool: tool, catalog: catalog)
            placementAnchor = next.anchor
            heldEnd = next.end
        } else {
            placementAnchor = here
            heldEnd = here
        }
        hoverPoint = nil
        overlayDirty = true
    }

    /// The held placement's anchor and end (nil = nothing held).
    var heldCells: (anchor: GridCell, end: GridCell)? {
        guard let placementAnchor, let heldEnd else { return nil }
        return (placementAnchor, heldEnd)
    }

    /// Moves the held placement's end (the ± buttons), or holds one at exact cells (captures).
    func holdPlacement(anchor: GridCell? = nil, end: GridCell) {
        guard activeTool != nil else { return }
        if let anchor { placementAnchor = anchor }
        guard placementAnchor != nil else { return }
        heldEnd = end
        hoverPoint = nil
        overlayDirty = true
    }

    /// Builds the held placement if it is valid; it stays held (to adjust) when not.
    @discardableResult
    func confirmHeldPlacement() -> Bool {
        guard let tool = activeTool, let held = heldCells,
              let preview = previewProvider?(tool, held.anchor, held.end), let command = preview.command, preview.isValid else { return false }
        placementAnchor = nil
        heldEnd = nil
        overlayDirty = true
        onCommit?(command)
        return true
    }

    /// Places the pointer and drag anchor on exact cells (automated captures).
    func setPlacementCells(anchor: GridCell, current: GridCell) {
        placementAnchor = anchor
        let world = composition.grid.rect(columns: ColumnSpan(start: current.column, count: 1),
                                          floors: FloorSpan(lowest: current.floor, highest: current.floor)).center
        hoverPoint = controller.camera.worldToScreen(world).cgPoint
    }


    // MARK: Camera API (used by input views, menu commands, capture)

    func withController(_ body: (inout CameraController) -> Void) {
        body(&controller)
        cameraDirty = true
    }

    /// Height of the build bar, status line and banners along the bottom (`RootView`): the
    /// camera may look this far below the ground so the street never has to hide behind them.
    static let bottomInterfaceInset = 150.0

    func apply(preset: CameraPreset) {
        let p = preset.placement(for: composition, viewport: controller.camera.viewportSize, bottomInset: Self.bottomInterfaceInset)
        withController { $0.jump(center: p.center, zoom: p.zoom) }
    }

    /// True when the camera is at rest and every wanted tile is displayed.
    var isSettled: Bool {
        !controller.isAnimating && tileLayer.isComplete && tileLayer.pendingCount == 0
            && (emissionLayer.node.isHidden || (emissionLayer.isComplete && emissionLayer.pendingCount == 0))
            && (lampLayer.node.isHidden || (lampLayer.isComplete && lampLayer.pendingCount == 0))
    }

    var currentDiagnostics: RenderDiagnostics { lastDiagnostics }

    // MARK: SKScene

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        placeInitialCameraIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 1, size.height > 1 else { return }
        controller.setViewportSize(Vec2(size))
        placeInitialCameraIfNeeded()
        cameraDirty = true
    }

    /// Frames the site once the scene is in a view with a real size, then signals ready.
    private func placeInitialCameraIfNeeded() {
        guard !didPlaceInitialCamera, view != nil, size.width > 1, size.height > 1 else { return }
        didPlaceInitialCamera = true
        controller.setViewportSize(Vec2(size))
        if let p = initialPlacement {
            withController { $0.jump(center: p.center, zoom: p.zoom) }
        } else {
            apply(preset: .overview)
        }
        DispatchQueue.main.async { [weak self] in self?.onReady?() }
    }

    override func update(_ currentTime: TimeInterval) {
        let frameStart = CACurrentMediaTime()
        let dt = lastUpdateTime.map { min(max(currentTime - $0, 0), 0.1) } ?? 0
        lastUpdateTime = currentTime
        var mark = frameStart
        func lap(_ section: String) {
            let now = CACurrentMediaTime()
            statSections[section, default: 0] += now - mark
            mark = now
        }

        onFrame?(dt)
        lap("sim")
        if controller.update(dt: dt) { cameraDirty = true }
        let camera = controller.camera
        if cameraDirty {
            worldRoot.setScale(CGFloat(camera.zoom))
            let offset = camera.viewportSize / 2 - camera.center * camera.zoom
            worldRoot.position = offset.cgPoint
            detailLevel = lodPolicy.level(forZoom: camera.zoom, current: detailLevel)
            overlayDirty = true
        }
        tileLayer.update(visible: camera.visibleRect, zoom: camera.zoom, backingScale: Double(backingScale))
        lap("tiles")
        elevatorLayer.update(carProvider?(camera.visibleRect, camera.zoom) ?? [])
        lap("cars")
        let lighting = lightingProvider?(camera.visibleRect, camera.zoom)
            ?? (grade: Grade.day, darkness: 0, emission: 0, activity: 1, rooms: [])
        if lighting.emission > 0.02 {
            emissionLayer.update(visible: camera.visibleRect, zoom: camera.zoom, backingScale: Double(backingScale))
            lampLayer.update(visible: camera.visibleRect, zoom: camera.zoom, backingScale: Double(backingScale))
        }
        dayNight.update(grade: lighting.grade, darkness: lighting.emission, cityActivity: lighting.activity, rooms: lighting.rooms,
                        viewport: size, emission: emissionLayer.node, lamps: lampLayer.node)
        lap("light")
        let sky = weatherProvider?(camera.visibleRect) ?? (look: WeatherLook.clear, roofs: [], street: [])
        weather.update(look: sky.look, darkness: lighting.darkness, viewport: size, zoom: camera.zoom, roofs: sky.roofs, street: sky.street)
        clouds.update(cloudProvider?(camera.visibleRect) ?? [], darkness: lighting.darkness)
        lap("weather")
        let burning = fireProvider?() ?? (flames: [], engines: [], scorched: [])
        fire.update(flames: burning.flames, engines: burning.engines, scorched: burning.scorched)
        lap("fire")
        agentLayer.update(peopleProvider?(camera.visibleRect, camera.zoom) ?? [])
        lap("people")
        navigationOverlay.update(overlay: navigationProvider?(), camera: camera)
        trafficOverlay.update(traffic: trafficProvider?(), camera: camera)
        servicesOverlay.update(marks: servicesProvider?(), camera: camera)

        if overlayDirty {
            if showGrid {
                let overlay = ArchitecturalGrid.build(grid: composition.grid, plot: composition.plot,
                                                      visible: camera.visibleRect, zoom: camera.zoom)
                gridOverlay.update(overlay: overlay, camera: camera, backingScale: backingScale,
                                   frontageMinX: composition.frontageRect.minX,
                                   hoverRect: activeTool == nil ? hoverCell().map { $0.rect } : nil)
            }
            roomLabelLayer.update(labels: roomLabelProvider?(camera.visibleRect, camera.zoom) ?? [], camera: camera)
            if let r = selectionRect {
                let a = camera.worldToScreen(Vec2(r.minX, r.minY)), b = camera.worldToScreen(Vec2(r.maxX, r.maxY))
                selectionOutline.path = CGPath(rect: CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y), transform: nil)
                selectionOutline.isHidden = false
            } else {
                selectionOutline.isHidden = true
            }
            updatePreview(camera: camera)
        }
        cameraDirty = false
        overlayDirty = false
        lap("overlays")

        recordStats(dt: dt, updateSeconds: CACurrentMediaTime() - frameStart)
    }

    private func updatePreview(camera: Camera2D) {
        defer { reportHeld() }
        guard let tool = activeTool else {
            currentPreview = nil
            placementOverlay.update(preview: nil, camera: camera, cursor: nil)
            return
        }
        // A held placement (touch) stays on its cells while the camera moves.
        if let held = heldCells {
            currentPreview = previewProvider?(tool, held.anchor, held.end)
            let end = held.end
            let center = composition.grid.rect(columns: ColumnSpan(start: end.column, count: 1), floors: FloorSpan(lowest: end.floor, highest: end.floor)).center
            placementOverlay.update(preview: currentPreview, camera: camera, cursor: camera.worldToScreen(center).cgPoint)
            return
        }
        guard let hoverPoint else {
            currentPreview = nil
            placementOverlay.update(preview: nil, camera: camera, cursor: nil)
            return
        }
        let current = cell(at: hoverPoint)
        currentPreview = previewProvider?(tool, placementAnchor ?? current, current)
        placementOverlay.update(preview: currentPreview, camera: camera, cursor: hoverPoint)
    }

    private func reportHeld() {
        let held = heldEnd == nil ? nil : currentPreview
        guard held != reportedHeld else { return }
        reportedHeld = held
        onHeldPreview?(held)
    }

    /// Grid cell under the cursor if it lies in the buildable frontage.
    func hoverCell() -> (cell: GridCell, rect: Rect)? {
        guard let hoverPoint else { return nil }
        let world = controller.camera.screenToWorld(Vec2(hoverPoint))
        let grid = composition.grid
        let cell = grid.cell(at: world)
        guard composition.plot.frontage.contains(cell.column), cell.floor >= -composition.plot.maxBasementFloors else { return nil }
        return (cell, grid.rect(columns: ColumnSpan(start: cell.column, count: 1), floors: FloorSpan(lowest: cell.floor, highest: cell.floor)))
    }

    private func recordStats(dt: Double, updateSeconds: Double) {
        statFrames += 1
        statElapsed += dt
        statUpdateSeconds += updateSeconds
        guard statElapsed >= 0.25 else { return }
        let camera = controller.camera
        var d = RenderDiagnostics()
        d.fps = Double(statFrames) / statElapsed
        d.frameTimeMs = statElapsed / Double(statFrames) * 1000
        d.sceneUpdateMs = statUpdateSeconds / Double(statFrames) * 1000
        d.sceneSections = statSections.mapValues { ($0 / Double(statFrames) * 10_000).rounded() / 10 }
        d.nodeCount = countNodes(self)
        d.tileLevel = tileLayer.lastPlan.level
        d.tilesVisible = tileLayer.visibleCount
        d.tilesCached = tileLayer.cachedCount
        d.tilesPending = tileLayer.pendingCount
        d.tilesRasterized = tileLayer.rasterizedCount
        d.agentsRendered = agentLayer.renderedCount
        d.tileRasterMs = tileLayer.averageRasterMs
        d.memoryMB = residentMemoryMB()
        d.zoom = camera.zoom
        d.detailLevel = detailLevel.description
        d.centerX = camera.center.x
        d.centerY = camera.center.y
        d.viewportWidth = camera.viewportSize.x
        d.viewportHeight = camera.viewportSize.y
        d.backingScale = Double(backingScale)
        if let hoverPoint {
            let w = camera.screenToWorld(Vec2(hoverPoint))
            d.cursorWorld = String(format: "%.2f m, %.2f m", w.x, w.y)
            d.cursorCell = hoverCell().map { "\($0.cell)" } ?? "outside plot"
        }
        lastDiagnostics = d
        onDiagnostics?(d)
        statFrames = 0
        statElapsed = 0
        statUpdateSeconds = 0
        statSections = [:]
    }

    private func countNodes(_ node: SKNode) -> Int {
        node.children.reduce(1) { $0 + countNodes($1) }
    }
}
