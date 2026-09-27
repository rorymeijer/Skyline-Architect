# Development Status

_Last updated: 2026-09-27 (Phase 4)_

## Current phase
**Phase 4 — Basic people simulation: COMPLETE** (awaiting approval to start Phase 5).

## Current milestone
M1 “First Playable” (end of Phase 9) — Phases 1–4 of 9 done.

## Quality gates (Phase 4)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36328915766 (`35bab60`) |
| Automated tests pass | ✅ | 124 tests (Linux + macOS) incl. daily rhythm, stairs usage, unreachable floors, determinism across batch sizes, save v1→v2 migration, v2 golden fixture |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 7 captures in `Development/Screenshots/Phase-04/` |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | SIMULATION (rewritten), SAVE_FORMAT v2, ARCHITECTURE, DECISIONS D-019…D-022, CHANGELOG |
| Screenshots produced & inspected | ✅ | 1 capture-script issue found and fixed |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–3 (merged: rorymeijer/Skyline-Architect#1, #2, #3).
- Phase 4 (FUNCTIONAL): `SkylineSimulation` module — fixed-tick clock, speeds as ticks per
  second, event-driven engine with analytic trips, schedules and names from content,
  population sync from room occupancy, street→entrance→stairwell routes with unreachable
  detection; person figures with walk cycle, render LOD and culling; speed/clock/population
  UI; save format 2 with migration.

## In progress
- Nothing. Waiting for Phase 5 approval.

## Known bugs / unverified
- Interactive input and live speed changes not yet exercised by a human; iPad never launched.
- People already mid-trip when construction changes finish their old trip (possibly through a
  removed floor) — re-planning arrives with Phase 5 route invalidation.
- People stand in rooms; no sitting/lying animation.

## Technical debt
- `RoutePlanner` is a Phase 4 stand-in (single stairwell); replaced by the Phase 5 navigation graph.
- `PopulationSync` is a stand-in for Phase 8 tenants.
- Simulation runs on the main thread (fine at this scale; background host in Phase 19).
- Earlier items: O(rooms) construction checks, no skyline parallax, CI JPEG commits.

## Next tasks (Phase 5 — Navigation / pathfinding)
1. Navigation graph: per-floor walk segments (plates, room doors) + vertical transport edges
   (stairwells now; elevator banks in Phase 6) with transfers between shafts.
2. Hierarchical search (floor graph + transport graph), route cache keyed by building
   revision, invalidation on construction, re-planning of people mid-trip.
3. Path debug overlay (developer mode) and pathfinding metrics in the HUD.
4. Tests: multi-stairwell transfers, unreachable detection, cache invalidation, determinism.

## Environment
- Cloud sessions run in a Linux container without Xcode. To build/test the package there,
  install Swift from the official Docker image layers (download.swift.org is blocked):
  pull `library/swift:6.1-noble` layers via the Docker registry API, extract the toolchain
  layer into `/opt/swift`, apt-install its runtime deps (binutils libc6-dev
  libcurl4-openssl-dev libedit2 libgcc-13-dev libpython3-dev libsqlite3-0 libstdc++-13-dev
  libxml2-dev libncurses-dev libz3-dev pkg-config tzdata zlib1g-dev) and use
  `PATH=/opt/swift/usr/bin:$PATH`. `apt-get install librsvg2-bin` for SVG previews.
- If package tests crash with a segfault after model layout changes, it is a stale
  incremental build on Linux: `rm -rf Packages/SkylineKit/.build` and rebuild.
- GitHub artifact/log blob storage (`productionresultssa*.blob.core.windows.net`) is blocked
  by this environment's network policy. CI therefore commits the latest captures to
  `Development/Screenshots/_ci-latest/` — `git pull` after a CI run to inspect them.
- The app target is verified by macOS CI (`.github/workflows/ci.yml`, runs on every push to
  `claude/**`); screenshots are uploaded as the `phase-screenshots` artifact.

## Local verification (on a Mac)
```sh
Scripts/test-package.sh
Scripts/build-app.sh && Scripts/capture-screenshots.sh /tmp/skyline-shots
open SkylineArchitect.xcodeproj   # run the SkylineArchitect scheme on "My Mac"
```
