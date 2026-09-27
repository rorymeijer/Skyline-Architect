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

| 2026-09-27 | 0.3.0 (1) Debug | GitHub macos-15 runner, 1×, 60 Hz | furnished tower, 36 pt/m | 60 fps, scene update 0.10 ms, 9 tiles shown, ~13 ms/tile avg, 188 nodes, 171 MB |
| 2026-09-27 | 0.3.0 (1) Debug | same | façade LOD, 3.2 pt/m | 60 fps, 0.10 ms update, 8 tiles shown, 95 nodes, 147 MB |

| 2026-09-27 | 0.4.0 (1) Debug | GitHub macos-15 runner, 1×, 60 Hz | 38 people, morning rush, 10.4 pt/m | 59 fps, scene update 0.26 ms, simulation 0.25 ms/frame, 14 people drawn |

| 2026-09-27 | 0.5.0 package, release (`swift test -c release`) | Linux cloud container | 200 floors, 10 stair segments (every trip above floor 20 transfers), 1 194 workers, one game day at 10× (360 steps of 240 ticks) | 68 ms for the whole day (0.19 ms per step, incl. signature check); 4 364 path queries, 1 978 cache hits, 1 graph build (209 portals, 416 links) |
| 2026-09-27 | same, debug | same | same | 0.60–0.69 s per day (1.7–1.9 ms per step) |

| 2026-09-27 | 0.6.0 package, release | Linux cloud container | 60 floors, 2 elevators + stairs over full height, 354 workers, 06:00–11:00 in 240-tick steps | 14 ms for 5 game hours; peak 21 waiting, cars full (13) at peak; all at work by 11:00 |
| 2026-09-27 | same | same | 200-floor stairs scale day (Phase 5 scenario, now with the elevator-aware engine) | 84 ms per day (was 68 ms) |

| 2026-09-27 | 0.7.0 package, release | Linux cloud container | 60-floor tower (bank of 2 + stairs), 354 workers, 06:00–11:00 | 20 ms for 5 game hours (call assignment included); peak 15 waiting |
| 2026-09-27 | same | same | demo-skytower (3 banks, 6 cars, 175 workers), morning per strategy | all strategies: avg waits 19–20 s; see ELEVATORS.md |

Observations (Phase 9): daily closing is O(tenants + rooms + people) once per game day;
lit rooms are computed per frame over the visible rooms of the property (demo tower: 37
rooms). Day/night adds one screen-sized multiply sprite and one additive sprite per lit
room.

Observations (Phase 8): the hourly market appraises every vacant unit of a type per
prospect (route plans, cached). Measured only on the demo tower (15 units, negligible);
large buildings with many vacancies are unmeasured — profile in Phase 19 if needed.

Observations (Phase 7): call assignment computes the building's banks (O(cars²)) and the
bank's queues (O(people)) per hall call; negligible at this scale.

Observations (Phase 6): car decisions scan the building's waiting people (O(people) per
car event); fine at this scale, index queues per landing if profiling shows it (Phase 19).

Observations (Phase 5): navigation cost is dominated by first-day misses; Dijkstra over a
few hundred portals is microseconds. The per-step structure signature is O(rooms of the
building) and included above. The in-app overlay is Debug-only and rebuilt per frame
while visible (not a release cost).

Observations (Phase 4): the event-driven simulation costs ~0.1–0.3 ms per frame for 38
people; people are drawn as pooled sprites with cached figure textures. Scale test with
thousands of people is scheduled with the navigation work (Phase 5) and Phase 19.

Observations (Phase 3): furniture adds items per tile but tiles stay off the main thread;
the façade LOD keeps far-zoom tiles cheap. Observations: raster time per tile roughly doubled with interiors (more items per tile) but
stays off the main thread; scene update stays well under 1 ms. Memory grows with the tile cache (budget 96 tiles × up to 1 MB); budget
should become memory-aware on iPad (Phase 19 or earlier if profiling shows pressure).

Profile before optimizing; record results here.
