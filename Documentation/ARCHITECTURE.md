# Architecture

Status: Phase 15 (2026-09-28). This document describes what exists and the intended evolution.
Items are marked **FUNCTIONAL** (exists, tested), **SCAFFOLDED** (exists, incomplete) or
**PLANNED** (design only).

## 1. Layering

```
┌────────────────────────────────────────────────────────────────────┐
│ App target (Apple only)                            App/            │
│  SwiftUI UI · SpriteKit renderer · input · platform glue · capture │
└───────────────▲──────────────────────────▲─────────────────────────┘
                │ reads                    │ reads (snapshots)
┌───────────────┴──────────────┐  ┌────────┴──────────────────────────┐
│ SkylinePresentation          │  │ SkylineSimulation (Phase 4–5)      │
│ camera · LOD · culling ·     │  │ clock · people · schedules · nav   │
│ drawing IR · procedural art ·│  │ graph — owns mutation of people    │
│ scene composition · tiles    │  └────────┬──────────────────────────┘
└───────────────┬──────────────┘           │
                │                          │
┌───────────────┴──────────────────────────┴─────────────────────────┐
│ SkylineContent: JSON definitions, validation, new-game factory      │
│   (depends on Presentation for visual definition types, D-017)      │
│ SkylinePersistence: versioned saves, migrations, save store          │
│ SkylineSimulation: clock, schedules, population, navigation, engine  │
├─────────────────────────────────────────────────────────────────────┤
│ SkylineCore: authoritative model (world→city→property→building),    │
│ grid, geometry, IDs, deterministic RNG                              │
└─────────────────────────────────────────────────────────────────────┘
```

Rules (enforced by module dependencies, not only by convention):

* `SkylineCore`, `SkylineContent`, `SkylinePresentation`, `SkylinePersistence` import only Foundation.
  They build and are tested on Linux and macOS. No SpriteKit/SwiftUI/CoreGraphics.
* The app target depends on the package; the package never depends on the app.
* SpriteKit nodes are *views* of model state. They are disposable and never saved.
* SwiftUI views display state and forward intents; they do not contain game rules.

### Why a separate Presentation module?

Everything that decides *what* to draw (camera math, LOD thresholds, which tiles are
needed, the procedural geometry of soil strata, piles or furniture) is pure computation
and belongs in testable code. The SpriteKit layer only decides *how* to put that on the
GPU: rasterize a drawing into a texture, position a sprite. This keeps the untestable
platform layer thin and lets the headless `skyline-snapshot` tool render the same
compositions to SVG for design review in CI or on Linux (see DECISIONS D-003).

## 2. Game model (SkylineCore) — FUNCTIONAL (Phase 1 subset)

```
GameWorld
 ├─ grid: GridSpec                  shared architectural grid (module width, floor height)
 ├─ cities:     EntityStore<CityID, City>
 ├─ properties: EntityStore<PropertyID, Property>   (Property.cityID → City)
 │    └─ plot: Plot                  buildable frontage, basement limit, soil strata
 └─ buildings:  EntityStore<BuildingID, Building>   (Building.propertyID → Property)
      └─ foundation: Foundation      basement depth, piles
```

* Flat, ID-keyed stores with back references instead of deep nesting: mutations stay
  simple, lookups are O(1), and new entity kinds (floors, rooms, agents) slot in without
  rewriting the hierarchy. The logical hierarchy World→City→Property→Building→Floor→Room
  is preserved through the references.
* `EntityStore` keeps insertion order ⇒ deterministic iteration and stable save output.
* IDs are typed (`EntityID<Tag>`, 32-bit) and allocated from a counter in the world:
  compact, deterministic, never reused.
* Each property has its own local coordinate space (meters, x right, y up, y = 0 is
  grade). A property is rendered as its own scene. Cities/properties never share
  coordinates, so an empire of many towers never requires a giant coordinate space.
* No hard floor limit: floors are signed `Int` (0 = ground, negative = basement).
  Practical limits come from rules (plot basement depth) and performance.

Units: meters (`Double`). Placement grid: `GridSpec.standard` = 1 m modules, 4 m floors,
8-module structural bays.

### Construction (SkylineCore/Construction) — FUNCTIONAL (Phase 2)

```
player input ─▶ PlacementPlanner (Presentation) ─▶ BuildCommand
                                                    │ validate (preview, cost, reason)
                                                    ▼
                         ConstructionEngine(BuildCatalog) ──apply──▶ GameWorld
                                                    │ inverse command
                                                    ▼
                                         ConstructionHistory (undo/redo)
```

* `Building.floors`: one contiguous `FloorPlate` per level (setbacks = narrower plates).
* `GameWorld.rooms`: rooms *and* shafts as one entity type (`Room`) occupying columns ×
  floors; what they are comes from `RoomSpec` in content.
* Rules: ground/basement plates inside the footprint (basements need excavation), upper
  plates supported by the plate below within a cantilever allowance, rooms on built plates
  without overlap, width/height/level limits from the spec. Demolition: rooms any time,
  floors only when empty and carrying nothing.
* Walls, partitions, doors and façades are **derived** from plates and rooms by the art —
  not separately placed entities (DECISIONS D-014).
* Undo is inverse commands, not snapshots (D-013).

## 3. Content (SkylineContent) — FUNCTIONAL (Phase 1 subset)

A *content pack* is a folder with `pack.json` plus definition files (`cities.json`,
`plots.json`, `starts.json`). The base game ships its own pack as a package resource
(`Sources/SkylineContent/Resources/Base`). The loader validates duplicates and
dangling references and reports file + id context. Mods (Phase 17) will be additional
packs merged by id — the engine never executes mod code. See MODDING.md.

`NewGameFactory` turns a `StartDefinition` into a `GameWorld`.

## 4. Presentation (SkylinePresentation) — FUNCTIONAL

| Component | Role |
|-----------|------|
| `Camera2D` | center (m), zoom (points per meter), viewport; screen↔world; clamping |
| `CameraController` | input intents → camera: smooth zoom toward anchor, drag pan, inertia, keyboard pan; frame-rate independent |
| `DetailLevel` / `DetailLevelPolicy` | zoom → LOD band with hysteresis |
| `Drawing` (IR) | resolution-independent vector primitives with paints and per-item minimum-detail thresholds |
| `DrawingIndex` | spatial bucket index: which items intersect a region |
| `TilePyramid` / `TileSetPlanner` | which raster tiles (level, x, y) are needed for a view; LRU bookkeeping |
| `ArtPalette` + `*Art` recipes | procedural, seeded, deterministic art (terrain, foundation, backdrop, building, rooms, exterior façade) |
| `ArtCatalog`, `FurnitureDefinition`, `InteriorLayout`, `LayoutResolver` | data-driven furniture and interiors (Phase 3) |
| `SiteComposer` | model → layered `SiteComposition` |
| `ArchitecturalGrid` | visible-range grid lines/labels with density-adaptive strides |

## 5. Rendering (App/Rendering) — FUNCTIONAL (Phase 1)

* `WorldScene` (SKScene) — the scene *is the viewport* (size = view size, points).
  A `worldRoot` node carries the camera transform (scale = points/meter, position from
  camera center). We do not use SKCameraNode: owning the transform keeps screen-space
  overlays and in-app screenshot capture trivial.
* The composition has two layers: `site` (composed once) and `buildings` (recomposed after
  each construction command). The command's plan yields a dirty rect; only tiles in it
  are re-rendered, and stale tiles stay visible until replaced (D-015).
* Static art is rasterized into textures by tile (quadtree levels, 512 px tiles, 1 px
  bleed against seams) on a background queue via `DrawingRasterizer` (CoreGraphics), then
  shown as `SKSpriteNode`s. Tile level follows zoom × backing scale, so detail increases
  as you zoom in and huge buildings cost few textures when zoomed out. Items below the
  tile's detail threshold (speckles, rebar) are skipped automatically.
* Dynamic overlays (grid, labels, hover cell) are rebuilt in screen space only when the
  camera changes.
* Sky is a screen-space gradient sprite.
* `RenderDiagnostics` is published to the SwiftUI HUD at 4 Hz, never per frame.

## 5b. Simulation & navigation (SkylineSimulation) — FUNCTIONAL (Phases 4–10)

`SimulationEngine` (value type) advances the world event by event; `NavigationService`
(a shared, internally locked cache owned by the engine) holds per-building
`NavigationGraph`s and cached routes, invalidated by a structure signature. Neither the
cache nor the graph is saved: both are derived and never change outcomes (SIMULATION.md,
DECISIONS D-023/D-024). Construction → `PopulationSync` → `replanAfterConstruction` (which
also keeps one `ElevatorCar` per elevator shaft). Cars and people share one event queue
(D-025); the app draws cars with `ElevatorView` → `ElevatorLayer`. Banks are derived from
adjacency (D-027); `ElevatorTraffic` feeds the traffic overlay and the bank panel. Tenants
and the rental market (`Leasing`, an hourly event in the same queue) are described in
TENANTS.md; `UnitReport` / `LeasingSummary` feed the inspector and leasing panel. Money
(ECONOMY.md): the `Ledger` lives in Core; construction is settled by `ConstructionHistory`
(D-031), daily closing runs with the 06:00 market step, `EconomySummary` feeds the panel.
Facilities (FACILITIES.md): utilities derived per building, `Upkeep` beside rooms (D-034),
staff are people with jobs routed in `staff` mode (D-035).
Progression (PROGRESSION.md): `Standing` per building and `BuildingClass` definitions live in
Core so `ConstructionEngine` can enforce unlocks; assessment, promotion and demand are in
Simulation (`Progression`, daily after the tenant reviews); classes never drop (D-036).
Lighting (LIGHTING.md): `Lighting.level` in Core feeds both the simulation's hourly energy
meter and Presentation's `DayNight`; static night lights are the composition's `emission`
layer, drawn by the app as an additive tile layer with building silhouettes cleared (D-037).
Weather (WEATHER.md): kinds, rules and the saved `WeatherState` live in Core; the simulation
advances it at the closing and applies content multipliers; Presentation derives the look
(`WeatherView`), the app draws it (`WeatherLayer`) (D-038).
Emergencies (EMERGENCIES.md): `IncidentState` (log, fires in progress) lives in Core; fires
are stepped as their own event target in the simulation queue; evacuation reuses trips with
`stairsOnly` routing and a single hook in the person event loop; Presentation derives flames,
soot and fire engines (`FireView`), the app draws them (`FireLayer`) (D-039).
Estate (ESTATE.md): cities carry their market in the save; construction scales costs by the
building's city, the rental market runs per city; buying land and legacy matching live in
Content (`Estate`), which knows plots; the app shows one property at a time while the whole
estate simulates (D-040).
Scenarios (SCENARIOS.md): `ScenarioState` (copied objectives, deadline, streak, result) lives
in Core; the simulation measures the estate-wide metrics and decides the result at the daily
closing (`Scenarios`); Content defines scenarios, validates them, starts them and summarises
them for the UI (`ScenarioBrief`, `ScenarioSummary`); the app only shows them (D-041).
Mods (MODDING.md): `ContentPack` reads a pack folder (decoding only), `overlay` lays packs
over each other by id, and `ContentLibrary.build` validates the merged result. `ModLoader`
discovers mod folders, applies the enabled ones in order and validates each step, reporting
`PackStatus` per pack. The app keeps the enabled list as a setting and rebuilds its engines
from the new library (D-042).
Save sync (SAVE_FORMAT.md → Sync): `SaveSync` in Persistence syncs two folders by
fingerprint against a per-device base (pure file logic, Linux-tested); the app only chooses
the shared folder (iCloud container) and when to sync (D-043).
Scale (PERFORMANCE.md → Phase 19): derived state is cached where profiles showed it —
elevator banks live with the navigation graph in `NavigationService` (dropped by the same
structure signature), and a market hour or daily review shares one utility allocation per
building. `StressTower` and `skyline-bench` generate and time large towers (D-044).

## 6. Concurrency model

* All model mutation happens on the main actor in Phase 1 (there is no simulation yet).
* Tile rasterization runs on a background serial queue using immutable, `Sendable`
  compositions; results are applied on the main thread. Jobs are dropped if no longer
  wanted.
* PLANNED (Phase 4+): the simulation runs in fixed ticks owned by a single
  `SimulationHost` actor/queue; the renderer reads immutable snapshots published per
  tick and interpolates. Determinism > parallelism: parallel work only for pure
  functions (pathfinding queries, statistics) whose results are merged in a fixed order.
  See SIMULATION.md.

## 7. Input

`CameraController` is platform-neutral; platform views translate events into intents:

* macOS (`GameSKView`, NSView-based SKView): trackpad two-finger scroll = pan (with
  system momentum), pinch = zoom at cursor, mouse wheel = smooth zoom at cursor,
  left/right/middle drag = pan with inertia, WASD/arrows = pan, Q/E/+/− = zoom,
  hover = grid cell readout. Menu commands for zoom/reset/grid/HUD.
* iPadOS: pan gesture (inertia), pinch at centroid, pointer hover.

## 8. Persistence — FUNCTIONAL (Phase 2)

`SkylinePersistence`: `SaveCodec` (versioned envelope, migrations, integrity-checked
decoding) and `SaveStore` (atomic files, quicksave, rotating autosaves). The app saves
with ⌘S, loads via File ▸ Load Game…, autosaves every 2 minutes when changed.
See SAVE_FORMAT.md.

## 9. Diagnostics & capture

* Developer HUD (FPS, frame time, update time, tiles, raster time, nodes, memory, zoom,
  LOD, cursor cell). Visible by default in Debug builds, toggle ⌥⌘D.
* Screenshot capture mode: `--capture-screenshots <dir>` drives deterministic camera
  presets, waits for tiles to finish, writes PNGs (+ `capture-report.json`), exits.
  Used by CI. Debug-only code path (`#if DEBUG`).
