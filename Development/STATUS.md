# Development Status

_Last updated: 2026-09-27 (Phase 6)_

## Current phase
**Phase 6 — First functioning elevators: COMPLETE** (awaiting approval to start Phase 7).

## Current milestone
M1 “First Playable” (end of Phase 9) — Phases 1–6 of 9 done.

## Quality gates (Phase 6)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36337293798 |
| Automated tests pass | ✅ | 150 tests (Linux + macOS) incl. motion profile, stairs-vs-elevator choice, morning rush (capacity, waits, arrivals), full day, shaft removal with riders, 60-floor and 21-floor runs, elevator view, save v2→v3 migration and v3 fixture |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 7 captures in `Development/Screenshots/Phase-06/` |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | ELEVATORS (implemented section), SIMULATION, SAVE_FORMAT v3, MODDING, ARCHITECTURE, DECISIONS D-025/D-026, PERFORMANCE, CHANGELOG 0.6.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | queue placement and demo scale issues found, fixed, recaptured |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–5 (merged: rorymeijer/Skyline-Architect#1 … #5).
- Phase 6 (FUNCTIONAL): elevator cars (one per shaft) with analytic trapezoidal motion,
  doors and boarding times from `elevators.json`; queues as waiting people; collective
  control; elevator nodes/edges in navigation (stairs for short trips); re-planning when a
  shaft is removed; cab/rope rendering, queues at landing doors, riders in cabs; HUD
  elevator rows; save format 3 with migration and fixture; `demo-highrise` blueprint.

## In progress
- Nothing. Waiting for Phase 7 approval.

## Known bugs / unverified
- Interactive input not yet exercised by a human; iPad never launched.
- Calls placed while a car moves are only considered at its next stop (no re-targeting).
- Route choice uses a constant expected wait; people never give up on a long queue.
- Riders are drawn in front of the (semi-transparent) car doors; queues can overlap the
  cab when it stops (cutaway convention).
- Walking ignores interior partitions; stairs have unlimited capacity.

## Technical debt
- Car decisions scan all waiting people of the world (O(people) per car event).
- Structure signature and elevator sync check run every simulation step (O(rooms)).
- Route cache cleared wholesale at 4 096 entries per building.
- `PopulationSync` is a stand-in for Phase 8 tenants; simulation runs on the main thread.

## Next tasks (Phase 7 — Advanced elevator queues & dispatch)
1. Banks: several shafts sharing hall calls; a bank dispatcher assigning calls to cars.
2. Strategy interface with collective, zoning/up-peak and destination dispatch.
3. Express/local shafts and sky-lobby transfers; service cars.
4. Statistics per bank (avg/max wait, passengers/hour, abandonment) and a traffic overlay.
5. Patience: waiting people may switch to stairs (deterministic).

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
