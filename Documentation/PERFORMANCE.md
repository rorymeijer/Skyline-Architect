# Performance

## Targets (eventual)

Hundreds of floors, thousands of rooms, thousands of people, dozens of elevators at
60 fps on Apple Silicon Macs, 60 fps on recent iPads (reduced render LOD allowed).

## Architecture choices for scale (Phase 1)

* **Tiled static rendering** — GPU cost bounded by screen area, not building size.
  Tile level follows zoom, so zoomed-out views of huge towers use few, low-res tiles.
* **Detail thresholds** — fine items (grain, rebar) are skipped in tiles below their
  `minDetail`; zoomed-out tiles rasterize fast.
* **Spatial index** — `DrawingIndex` buckets items so a tile only visits nearby items.
* **Background rasterization** with a per-frame application budget; stale jobs dropped.
* **Dynamic overlays rebuilt only on camera change**, in screen space, with
  density-adaptive grid strides (line count bounded by screen size, not world size).
* **HUD at 4 Hz**, never per frame.

## Diagnostics (developer HUD)

FPS · frame time · scene update time · visible/cached/pending tiles · average tile
raster time · SpriteKit node count · resident memory · zoom (pt/m) · LOD band ·
camera center · cursor cell. Screenshot capture writes the same values into
`capture-report.json`.

## Measurements

| Date | Build | Machine | Scenario | Result |
|------|-------|---------|----------|--------|
| 2026-09-26 | 0.1.0 (1) Debug | GitHub macos-15 runner, 1×, 60 Hz | site overview, 7.3 pt/m | 60 fps (display cap), scene update 0.10 ms, 9 tiles shown, 6.8 ms/tile raster (background), 95 nodes, 148 MB |
| 2026-09-26 | 0.1.0 (1) Debug | same | detail, 64 pt/m, tile L5 | 60 fps, 0.09 ms update, 9.1 ms/tile, 116 nodes, 180 MB |
| 2026-09-26 | 0.1.0 (1) Debug | same | skyline, 0.45 pt/m, tile L0 | 60 fps, 0.14 ms update, 24 tiles shown, 197 nodes, 205 MB |

| 2026-09-27 | 0.2.0 (1) Debug | GitHub macos-15 runner, 1×, 60 Hz | demo tower (37 rooms), 10.4 pt/m | 60 fps, scene update 0.14 ms, 15 tiles shown, 14.6 ms/tile, 129 nodes, 165 MB |
| 2026-09-27 | 0.2.0 (1) Debug | same | tower close-up, 64 pt/m | 52–60 fps during tile bursts, 0.11 ms update, 16.8 ms/tile |

Observations: raster time per tile roughly doubled with interiors (more items per tile) but
stays off the main thread; scene update stays well under 1 ms. Memory grows with the tile cache (budget 96 tiles × up to 1 MB); budget
should become memory-aware on iPad (Phase 19 or earlier if profiling shows pressure).

Profile before optimizing; record results here.
