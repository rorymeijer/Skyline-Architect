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

## Phase 19 — large-scale profiling

**Tools.**

* `skyline-bench` (package, release build) generates a stress tower (`StressTower`) and
  times each stage: build, leasing, a simulated day, save encode/decode and composition.
  * The tower has zones of 20 storeys, each with a local bank of 2 cars, a sky lobby with
    its own express shuttle, and plant floors.
  * Run it with `swift run -c release skyline-bench --zones 10 --width 64 --days 2`.
* Profiles come from `valgrind --tool=callgrind` on that binary (Linux).
* In the app (Debug), *Build ▸ Developer: Load Stress Tower* loads the same tower, and the
  Phase 19 captures record the render diagnostics.

**Before and after** (Linux cloud container, release; 211 floors, 481 rooms, 950 people,
29 cars, 380 tenants; one game day in 240-tick steps):

| Stage | Before | After | Fix |
|-------|-------:|------:|-----|
| Simulated day (first day, cold caches) | 2 406 ms | 720 ms | all below |
| Daily closing step (06:00) | 1 058 ms | 100 ms | The tenant review ran a utility allocation per tenant; now one per building. |
| Hall-call assignment | 32 % of the day | < 1 % | Elevator banks were recomputed for every call; now cached per structure. |
| Neighbour noise in appraisals | 12 % (spec lookups) | small | Geometry is checked before the hashed spec lookup. |
| Hourly market + lighting meter | 2 allocations per building | 1 | One allocation shared per hour. |
| Second day (warm caches) | — | ≈ 320 ms | |

**400 floors** (19 zones, 1 084 rooms, 2 166 people, 56 cars, 893 tenants; release):

| Measure | Result |
|---------|--------|
| Two game days | 9.0 s → **4.5 s** after raising the route cache from 4 096 to 65 536 entries per building (cache hits 29 % → 72 %). |
| First daily closing (cold route cache) | 650 ms |
| Second daily closing | < 107 ms |
| Fixed cost of one `advance` call (the app calls it every frame) | **0.6 ms** |
| Save | 947 KB; encode 70 ms, decode and validate 72 ms |
| Composition of the drawing | 216 k items in 140 ms (off the frame loop; built on install and recomposed per dirty rect) |

**In the app** (Debug build, GitHub `macos-15` runner, 1024 × 681 pt, CI captures). The
render diagnostics now split the scene update by section (`sceneSections` in
`capture-report.json`), which is how the two render hot spots below were found.

| Fix | Before | After |
|-----|--------|-------|
| Weather section: roofs found each floor's upper plate by linear search (O(floors²) per frame, even without snow). Now built per level and only computed under snow; `Building.plate(at:)` indexes. | 400 floors, whole tower in view: scene update 12.7 ms (weather 11 ms), 32–36 fps | 1.3 ms, 52 fps |
| 4 Hz panel refresh: 4 utility allocations per building, plus 1 per frame while the services overlay was on. Now one per refresh, shared. | 211 floors: 36–42 fps | 52–57 fps |

Remaining costs in the app:

* The night view of 211 floors: 1 845 nodes (lit window panes) and a 4.6 ms "light" section. Fine at 57 fps; batch panes into tiles if towers grow further.
* People sprites: about 1 ms at 400 floors.
* Loading the 400-floor save: 0.76 s including the scene rebuild (Debug).

**What this means at 10× speed** (240 ticks per real second):

* A game day of the 211-floor tower costs about 0.2–0.3 % of one core.
* The daily closing is a single spike of about 100 ms (6 frames), once every 6 real minutes.
* Moving the simulation to a background actor would remove that spike. The profile shows it
  is not needed yet, so it stays planned (DECISIONS D-044).

**Still open** (measured, not fixed):

* The fixed per-call cost grows with rooms and people: the heap is rebuilt and the structure
  and car-sync signatures are checked on every call.
* The first day's move-in wave plans about 1 000 routes (40–50 ms steps).
* Utility allocation is O(rooms × plant) (about 5 ms on the 400-floor tower). It runs hourly
  and on panel refreshes.

Observations (Phase 12): the emission layer is static and adds at most 48 cached tiles,
rasterized only while it is dark (14,440 items in the drawing, spatially indexed). In the final
CI run (36380170316), all nine captures ran at 59.6–60.4 fps. An earlier run measured 52 fps
for the 22:15 skyline view while its emission tiles were still rendering. The hourly lighting meter is one utility allocation per building per game hour.
The 4 Hz app refresh adds one allocation for the power map.

Observations (Phase 11): the daily assessment is one utility allocation and one bank scan per
building per game day. The app's 4 Hz standing summary adds one more allocation per refresh,
next to the facilities summary; the full test suite still runs in about 3 s (debug, 209 tests).

Observations (Phase 10): utility allocation is O(rooms × equipment) per building and runs
once per appraisal (market), per panel refresh and per overlay frame; the full test suite
went from 1.8 s to 3.0 s (debug) mostly through appraisals. Cache per structure/upkeep
change if it shows up in profiles.

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

## F2 — 500 floors (0.26.0)

**Tower:** `skyline-bench --zones 25 --width 64 --days 2` (release, Linux cloud container):
526 floors, 1 201 rooms, 2 511 people, 74 cars, 950 tenants. The bench hires technicians
(floors ÷ 10) and janitors (floors ÷ 8) as a player would. Profiles are callgrind runs
collected over `SimulationEngine.advance` only.

| Measure | Before F2 | After F2 |
|---------|----------:|---------:|
| Two game days (240-tick steps) | 9.1 s | **3.6 s** |
| Worst step, day 1 | 400 ms (06:08) | **134 ms** (06:04) |
| Worst step, day 2 | 280 ms (12:56, lunch) | **79 ms** |
| Daily closing step, warm route cache | 826 ms | **65 ms** |
| Daily closing step, cold route cache (`--cold`) | — | 288 ms |
| Planning every unit's access route (`warmRouteCache`) | 870 ms | **241 ms** |
| Fixed cost of one `advance` call | 0.96 ms | 0.66–0.79 ms |
| Night, whole tower in view: light sprites | 1 411 panes | **328 strips** |

What changed, in order of effect:

| Fix | Profile share before |
|-----|---------------------:|
| Idle staff searched every room of the building, with a spec lookup per room, for the nearest staff room, every 15 minutes. Staff rooms are now looked up once per `advance` call and building (`StaffRoomDirectory`). | 33 % |
| Route search: express shuttles had a graph node per floor they pass. Cars now have nodes only at their stops, with one ride edge between stops. The search is A*, using a lower bound of the storeys left (at the cheapest cost per storey) plus the walk to the target. | 38 % |
| A breakdown rebuilt the navigation graph and dropped every cached route. Broken cars are now left out per query; routes around them are cached separately. | the 826 ms closing |
| The route cache is warmed when a world is installed in the app (on the main thread, since the engine is not thread-safe), so the first daily closing does not plan every unit's access route. | 288 ms → 65 ms closing |

The event count (156 141 over two days) did not change: routes and outcomes are the same.

**In the app**, zoomed far out (below 2 points per metre) at night, each storey of a lit room
is one strip at the panes' average brightness (0.75), instead of a sprite per pane.

**Still open** (measured, not fixed):

* The 4 Hz panel refresh costs about 9.5 ms at 526 floors (one shared utility allocation plus
  the facilities, lighting and progression summaries).
* The per-call fixed cost (structure signature and car sync checked on every call) is about
  0.7 ms.
* The first morning's move-in wave (06:00–06:12) plans about 10 000 new routes (steps of
  90–134 ms: three real seconds at 10× speed).

