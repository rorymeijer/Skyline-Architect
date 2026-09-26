# Architecture

Status: Phase 1 complete (2026-09-26). This document describes what exists and the intended evolution.
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
│ SkylinePresentation          │  │ (PLANNED) SkylineSimulation        │
│ camera · LOD · culling ·     │  │ clock · agents · elevators ·       │
│ drawing IR · procedural art ·│  │ economy — owns mutation of world   │
│ scene composition · tiles    │  └────────┬──────────────────────────┘
└───────────────┬──────────────┘           │
                │                          │
┌───────────────┴──────────────────────────┴─────────────────────────┐
│ SkylineContent: JSON definitions, validation, new-game factory      │
├─────────────────────────────────────────────────────────────────────┤
│ SkylineCore: authoritative model (world→city→property→building),    │
│ grid, geometry, IDs, deterministic RNG                              │
└─────────────────────────────────────────────────────────────────────┘
```

Rules (enforced by module dependencies, not only by convention):

* `SkylineCore`, `SkylineContent`, `SkylinePresentation` import only Foundation.
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
| `ArtPalette` + `*Art` recipes | procedural, seeded, deterministic art (terrain, foundation, backdrop) |
| `SiteComposer` | model → layered `SiteComposition` |
| `ArchitecturalGrid` | visible-range grid lines/labels with density-adaptive strides |

## 5. Rendering (App/Rendering) — FUNCTIONAL (Phase 1)

* `WorldScene` (SKScene) — the scene *is the viewport* (size = view size, points).
  A `worldRoot` node carries the camera transform (scale = points/meter, position from
  camera center). We do not use SKCameraNode: owning the transform keeps screen-space
  overlays and in-app screenshot capture trivial.
* Static art is rasterized into textures by tile (quadtree levels, 512 px tiles, 1 px
  bleed against seams) on a background queue via `DrawingRasterizer` (CoreGraphics), then
  shown as `SKSpriteNode`s. Tile level follows zoom × backing scale, so detail increases
  as you zoom in and huge buildings cost few textures when zoomed out. Items below the
  tile's detail threshold (speckles, rebar) are skipped automatically.
* Dynamic overlays (grid, labels, hover cell) are rebuilt in screen space only when the
  camera changes.
* Sky is a screen-space gradient sprite.
* `RenderDiagnostics` is published to the SwiftUI HUD at 4 Hz, never per frame.

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

## 8. Persistence — PLANNED (Phase 2)

Model types are `Codable` already; a versioned save envelope arrives with construction.
See SAVE_FORMAT.md.

## 9. Diagnostics & capture

* Developer HUD (FPS, frame time, update time, tiles, raster time, nodes, memory, zoom,
  LOD, cursor cell). Visible by default in Debug builds, toggle ⌥⌘D.
* Screenshot capture mode: `--capture-screenshots <dir>` drives deterministic camera
  presets, waits for tiles to finish, writes PNGs (+ `capture-report.json`), exits.
  Used by CI. Debug-only code path (`#if DEBUG`).
