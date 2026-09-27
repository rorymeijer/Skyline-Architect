# Development Status

_Last updated: 2026-09-27 (Phase 10)_

## Current phase
**Phase 10 — Utilities + maintenance: COMPLETE** (awaiting approval to continue with
Phase 11).

## Quality gates (Phase 10)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36345637290 |
| Automated tests pass | ✅ | 195 tests (Linux + macOS) incl. utility allocation (range, capacity, failure), wear/dirt → jobs, staff shifts and job completion, service elevators (staff only), services criterion capped by the worst utility, wages, reports, save v6→v7 + v7 fixture |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 8 captures in `Development/Screenshots/Phase-10/` |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | FACILITIES.md (new), SIMULATION, SAVE_FORMAT v7, MODDING, ARCHITECTURE, DECISIONS D-034/D-035, PERFORMANCE, CHANGELOG 0.10.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | janitor close-up missed (backlog already cleared by 07:00), fixed, recaptured |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–9 (merged: rorymeijer/Skyline-Architect#1 … #9); M1 “First Playable” reached in Phase 9.
- Phase 10 (FUNCTIONAL): utilities (electricity, water, climate, data) supplied by
  equipment rooms within a floor range, derived each time (never saved); condition and
  cleanliness per room; cleaning and repair jobs; janitors and technicians with shifts,
  wages and service elevators (`RouteMode`); failed equipment; services appraisal
  criterion (tenants leave badly served units); facilities panel (⌥⌘F), services
  overlay (⌥⌘U), utilities/upkeep in the unit inspector; save format 7.

## In progress
- Nothing. Waiting for approval to continue (Phase 11 — progression / reputation).

## Known bugs / unverified
- No human play test yet; iPad never launched.
- Utilities are abstract per-floor ranges (no pipes/cables to draw or route); no waste utility.
- Staff pick jobs by urgency only (no distance weighting); one job at a time.
- Economy balance is first-pass (D-032); staff wages are not yet tuned against rents.
- Tenants who move out vanish instantly; long tenant names only show when zoomed in.

## Technical debt
- `Utilities.allocate` runs per appraisal and per report (O(rooms × suppliers)); fine at
  demo scale, unmeasured for 100+ floors.
- Per-step O(rooms) checks (structure signature, elevator sync, facilities sync).
- Simulation on the main thread.

## Next tasks (Phase 11 — Progression / reputation)
1. Building rating / reputation derived from satisfaction, services and traffic.
2. Unlocks gated by rating (room types, tenant types, tower height).
3. Goals / milestones for the sandbox and a first scenario hook.
4. UI: rating display, unlock notifications; captures and docs.

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
