# Development Status

_Last updated: 2026-09-27 (Phase 5)_

## Current phase
**Phase 5 — Navigation / pathfinding: COMPLETE** (awaiting approval to start Phase 6).

## Current milestone
M1 “First Playable” (end of Phase 9) — Phases 1–5 of 9 done.

## Quality gates (Phase 5)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36332717554 |
| Automated tests pass | ✅ | 136 tests (Linux + macOS) incl. transfers, unreachable, cache hits/invalidation, cache-independence of outcomes, re-planning (replaced / removed stairwell, automatic in `advance`), overlay, 200-floor scale day |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 6 captures in `Development/Screenshots/Phase-05/` |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | SIMULATION (Navigation), ARCHITECTURE, DECISIONS D-023/D-024, PERFORMANCE, CHANGELOG 0.5.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | framing/badge issues found and fixed, recaptured |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–4 (merged: rorymeijer/Skyline-Architect#1, #2, #3, #4).
- Phase 5 (FUNCTIONAL): `NavigationGraph` (stair portals per served floor, walk links along
  floors, transfers), deterministic Dijkstra, `NavigationService` with exact-key route cache
  and structure-signature invalidation, metrics; re-planning of invalidated trips after
  construction (app commit + automatic in `advance`); Debug navigation overlay (⌥⌘N) and
  HUD metrics. Scale: 200 floors / 1 194 people, one day at 10× in 68 ms (release).

## In progress
- Nothing. Waiting for Phase 6 approval.

## Known bugs / unverified
- Interactive input (incl. ⌥⌘N) not yet exercised by a human; iPad never launched.
- Walking ignores interior partitions and shaft walls on a floor (derived walls, D-014/D-023).
- Stairs have unlimited capacity (no congestion) — queues arrive with elevators (Phase 6–7).
- Stranded people go "outside" instantly when no route remains (no walking animation for it).
- People stand in rooms; no sitting/lying animation.

## Technical debt
- Structure signature is recomputed every simulation step (O(rooms of the building));
  replace with a construction revision counter if profiling shows cost (Phase 19).
- Route cache is cleared wholesale at 4 096 entries per building (simple, deterministic).
- `PopulationSync` is a stand-in for Phase 8 tenants.
- Simulation runs on the main thread (fine at this scale; background host in Phase 19).
- Earlier items: O(rooms) construction checks, no skyline parallax, CI JPEG commits.

## Next tasks (Phase 6 — First functioning elevators)
1. Elevator model: cars per shaft, served floors, capacity, speed/acceleration, doors and
   boarding time; state saved (save format 3 + migration + fixture).
2. Hall calls, floor queues, collective-control dispatch; waiting as events.
3. Navigation: elevator edge kind with expected-wait cost; people choose stairs vs. elevator.
4. Rendering: moving cars, doors, people waiting/boarding/riding/leaving; HUD wait metrics.
5. Tests: dispatch correctness, capacity, determinism across speeds, save round trip.

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
