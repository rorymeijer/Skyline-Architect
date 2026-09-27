# Changelog

All notable changes. Versions follow `MARKETING_VERSION` of the app.

## [0.6.0] — Phase 6: First functioning elevators

### Added
- **Elevator cars**, one per elevator shaft: capacity, speed and acceleration
  (trapezoidal motion), door and boarding times from `elevators.json`.
- **Queues and hall calls**: people walk to the landing, wait in order, board, ride and
  alight; **collective control** dispatch serves calls in the direction of travel.
- **Routing** chooses stairs or elevator by expected time (stairs for 1–2 storeys).
- **Rendering**: moving cabs with sliding doors and hoist rope; people queue at the
  landing doors and stand inside cabs. HUD rows for cars, riders, waiting and longest wait;
  elevator links in the navigation overlay.
- **Save format 3** (+ migration, golden fixture) with cars and waiting/riding people.
- `demo-highrise` blueprint (21 storeys, one full-height elevator) for captures and tests.

### Changed
- The event queue handles cars and people; re-planning after construction covers people
  waiting for or riding a removed elevator.

## [0.5.0] — Phase 5: Navigation / pathfinding

### Added
- **Navigation graph** per building: stair-shaft portals on every served floor, walk links
  along floors, storey links through shafts; deterministic Dijkstra. Routes may **transfer**
  between stairwells (walk across a floor to another shaft).
- **Route cache** keyed by exact trip ends; graph and cache are rebuilt only when floor
  plates or transport shafts change (structure signature). The cache never changes
  outcomes (tested against a cache-less run).
- **Re-planning after construction:** trips through removed stairs or floors continue from
  the traveller's current position; with no route left they leave and are marked unreachable.
- **Developer tools:** navigation overlay (⌥⌘N, Debug builds) with portals, links and live
  routes; HUD rows for path queries, cache hit rate, failures, graph size/builds, unreachable.
- Scale test: 200 floors, 1 194 people, one day at 10× in 68 ms (release).

### Changed
- `RoutePlanner` plans through the graph (replaces the Phase 4 single-stairwell planner).
- Event queue and Dijkstra share one `MinHeap`.

## [0.4.0] — Phase 4: Basic people simulation

### Added
- **Simulation clock and speeds:** 1 tick = 1 game second; pause / 1× / 2× / 4× / 10× run
  0 / 24 / 48 / 96 / 240 ticks per real second; results identical at every speed (tested).
- **People:** workers and residents with generated names, ages, schedules
  (`schedules.json`, `names.json`), homes/workplaces from room occupancy; event-driven
  engine with analytic trips (street → entrance → stairwell → room), unreachable detection.
- **Population sync** after construction and on load (Phase 8 tenants will replace it).
- **Rendering:** procedural person figures (4-frame walk cycle, skin/hair/clothing variety,
  business vs. casual), exact interpolation at fractional ticks, culling, render LOD
  (not drawn below 3.5 pt/m; still simulated).
- **UI:** clock, speed buttons, population pill; Space / 1–4 shortcuts; HUD rows for drawn
  and simulated people and simulation time per frame.
- **Save format 2** with v1→v2 migration and a v2 golden fixture with people mid-trip.
- `skyline-snapshot --time HH:MM` simulates before rendering and draws people.

## [0.3.0] — Phase 3: First furnished rooms

### Added
- **Data-driven furniture:** `materials.json` (60 materials), `furniture.json` (31 vector
  recipes: workstation desk, monitor, office chair, filing cabinet, meeting set, whiteboard,
  printer, doors, kitchen, kitchenette, fridge, double bed, nightstand lamp, sofa, TV unit,
  bathroom pod, wardrobe, floor lamp, reception desk, lobby sofa, directory, bench, fire
  extinguisher, plants, AHU, pump set, electrical panel, parked cars with colour variants …).
- **Interior layouts** (`interiors.json`) for offices, studio apartments, lobbies, corridors,
  mechanical rooms and parking; deterministic `LayoutResolver` (anchors, width conditions,
  repeat groups, collision avoidance, seeded variants). Mods can add furniture/layouts.
- **Exterior façade LOD:** curtain-wall façade below 6 px/m, furnished cutaway above,
  via per-item detail bands (`DrawItem.maxDetail`).
- `Documentation/ASSET_REQUIREMENTS.md`.

### Fixed
- Placeholder plant boxes no longer drawn in furnished mechanical rooms.

## [0.2.0] — Phase 2: Construction + saves

### Added
- **Construction model:** floor plates per building (setbacks), rooms and vertical shafts as
  one entity type, `BuildCommand`s validated by a data-driven `ConstructionEngine`
  (footprint, excavation, support/cantilever, width/height/level limits, overlap), costs and
  refunds, demolition of rooms and empty top floors; no floor limit (300-storey test).
- **Undo/redo** via inverse commands (⌘Z / ⇧⌘Z), session construction cost (not charged
  until the economy phase).
- **Content:** `rooms.json` (lobby, corridor, stairwell, elevator shaft, small office, studio
  apartment, mechanical room, parking level), `build-rules.json`, `blueprints.json`
  (demo tower); the build palette is generated from content.
- **Persistence module:** versioned save envelope, migration harness, integrity-checked
  loading (inconsistent saves are refused), atomic save store, quicksave (⌘S), Load Game
  sheet (⌘O), rotating autosaves every 2 minutes; golden format-1 fixture test.
- **Rendering:** layered composition (site + buildings), dirty-rect tile invalidation with
  stale tiles kept until replaced; storey shells, slabs, columns, end façades with glazing,
  roofs with parapets, basement retaining walls, per-appearance room finishes (lights,
  doors, skirting, stone panels, plant, parking markings), stairwells with flights and
  landings, hoistways with rails and landing doors; room labels.
- **Interaction:** build palette, drag placement with live green/red/amber ghost and a
  label (name · size · cost or the refusal reason), F/X/Esc keys, iPad tap/drag placement.
- **CI:** scripted capture of 8 construction/save/undo scenarios; latest captures are
  committed as JPEGs to development branches (`Development/Screenshots/_ci-latest`).

## [0.1.0] — Phase 1: Renderer, camera, architectural grid

### Added
- **Phase 0 bootstrap:** multiplatform Xcode project (macOS + iPadOS) with a local
  `SkylineKit` package, documentation set, decision log, roadmap, CI (Linux + macOS).
- **Core model:** `GameWorld` → `City` → `Property` (plot, soil strata) → `Building`
  (footprint, foundation) with validated references, typed IDs, insertion-ordered stores,
  JSON round-trip; architectural grid (1 m modules, 4 m floors, 8-module bays, no floor limit).
- **Content:** base content pack (`Port Calder`, `Quay Street Lot`, sandbox start) with
  validation of ids, references and format version; `NewGameFactory`.
- **Camera:** smooth zoom toward cursor/anchor (log-space, frame-rate independent),
  drag pan with inertia, trackpad pan/pinch, mouse wheel, keyboard (WASD/arrows, Q/E),
  zoom limits 0.35–96 pt/m, bounds clamping, presets (⌘1–⌘4, ⌘0).
- **LOD:** five detail bands with hysteresis; tile level follows zoom × backing scale;
  per-item detail thresholds hide fine grain when zoomed out.
- **Rendering:** drawing IR + spatial index; background CoreGraphics tile rasterization
  (512 px, 1 px bleed, LRU cache, fallback levels); world-anchored sky gradient.
- **Procedural art:** soil strata with undulating interfaces and per-material grain,
  paved grade, foundation section (diaphragm walls, raft with rebar, bored piles,
  basement back wall with pour lifts and tie holes, grade slab, starter bars),
  neighbouring buildings, distant skyline.
- **Architectural grid overlay:** density-adaptive module/bay/floor lines, grade line,
  dashed plot boundary, floor labels (G, 1…, B1…), hover cell highlight.
- **Developer HUD:** FPS, frame/update time, nodes, tiles, raster time, memory, zoom,
  LOD, camera, cursor cell (⌥⌘D).
- **Tools:** `skyline-snapshot` SVG design previews; Debug-only in-app screenshot
  capture (`--capture-screenshots`), run by CI.
