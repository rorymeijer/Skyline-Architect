# Changelog

All notable changes. Versions follow `MARKETING_VERSION` of the app.

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
