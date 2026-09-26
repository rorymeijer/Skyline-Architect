# Changelog

All notable changes. Versions follow `MARKETING_VERSION` of the app.

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
