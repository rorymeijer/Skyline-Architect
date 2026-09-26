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
| (Phase 1 CI capture — see Development/Screenshots/Phase-01/README.md) | | | | |

Profile before optimizing; record results here.
