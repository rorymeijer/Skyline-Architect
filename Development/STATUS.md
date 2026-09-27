# Development Status

_Last updated: 2026-09-27 (Phase 7)_

## Current phase
**Phase 7 — Advanced elevator queues & dispatch: COMPLETE** (awaiting approval to start Phase 8).

## Current milestone
M1 “First Playable” (end of Phase 9) — Phases 1–7 of 9 done.

## Quality gates (Phase 7)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36339081561 |
| Automated tests pass | ✅ | 163 tests (Linux + macOS) incl. bank detection, strategy adoption, all three strategies serve the sky tower, sky-lobby transfer, zoning zones, destination grouping in a peak, patience/abandonment, statistics, traffic data, save v3→v4 + v4 fixture |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 7 captures in `Development/Screenshots/Phase-07/` |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | ELEVATORS (Phase 7 + measurements), SIMULATION, SAVE_FORMAT v4, MODDING, ARCHITECTURE, DECISIONS D-027/D-028, PERFORMANCE, CHANGELOG 0.7.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | label overlap, clipping, badge clutter and framing fixed, recaptured |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–6 (merged: rorymeijer/Skyline-Architect#1 … #6).
- Phase 7 (FUNCTIONAL): derived elevator banks; call assignment at the landing by strategy
  (collective ETA, zoning, destination grouping); express shafts stopping at their ends,
  sky lobby room type and `demo-skytower`; patience with stairs fallback and abandonment
  counts; per-car statistics; traffic overlay (⌥⌘T) and Elevator Banks panel (⌥⌘E) with
  strategy choice; save format 4.

## In progress
- Nothing. Waiting for Phase 8 approval.

## Known bugs / unverified
- Interactive input (panel buttons, ⌥⌘T/⌥⌘E) not exercised by a human; iPad never launched.
- Strategies differ little at current traffic levels (measured, ELEVATORS.md); destination
  dispatch only slightly reduces stops in a sharp peak.
- Assignments are never revised; calls during motion wait for the next stop.
- Riders drawn in front of car doors; queues can overlap a stopped cab (cutaway convention).
- Service/freight cars deferred to Phase 10 (need staff).

## Technical debt
- Call assignment recomputes banks and scans people per call; car decisions scan waiting
  people (fine at 175–354 people; index per landing if profiling shows it, Phase 19).
- Structure signature and elevator sync check every step (O(rooms)).
- `PopulationSync` is a stand-in for Phase 8 tenants; simulation on the main thread.

## Next tasks (Phase 8 — Tenants + schedules)
1. Tenant model: households and businesses renting units (replacing PopulationSync).
2. Choice model: rent, accessibility (measured elevator waits), noise, amenities; vacancy.
3. Richer schedules and daily traffic patterns (lunch, visitors); up/down peaks per tenant type.
4. Tenant info in the UI (unit inspector), save format bump.

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
