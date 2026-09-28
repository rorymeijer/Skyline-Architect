# Development Status

_Last updated: 2026-09-27 (Phase 11)_

## Current phase
**Phase 11 — Progression / reputation: COMPLETE** (awaiting approval to continue with
Phase 12).

## Quality gates (Phase 11)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36347268108 |
| Automated tests pass | ✅ | 210 tests (Linux + macOS), including: unlock modes; locked rooms and height refused until the class allows them; sandbox allows everything; premium tenants wait for the class; reputation formula; move-out penalty; demand multiplier; promotion needs every requirement; classes never drop; an empty tower earns class B by playing; a power cut costs reputation but not the class; summary; content validation; save v7→v8 + v8 fixture |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 8 captures in `Development/Screenshots/Phase-11/` |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | PROGRESSION.md (new), SIMULATION, SAVE_FORMAT v8, MODDING, ARCHITECTURE, DECISIONS D-036, PERFORMANCE, CHANGELOG 0.11.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | banner overlap and a reputation-fall step that did not fall: fixed, recaptured |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–10 (merged: rorymeijer/Skyline-Architect#1 … #10). M1 “First Playable” was reached in Phase 9.
- Phase 11 (FUNCTIONAL):
  - Reputation per building, assessed each morning; it drives demand.
  - Building classes C/B/A/Prime with population, reputation and room requirements. Promotions only; classes never drop.
  - Standard game: room types, height and premium tenant types unlock by class. The sandbox keeps everything unlocked.
  - UI: Standing panel (⌥⌘P), promotion banner, locked build tools, class in the status pill, New Game / New Sandbox.
  - Save format 8.

## In progress
- Nothing. Waiting for approval to continue (Phase 12 — full day/night + lighting).

## Known bugs / unverified
- No human play test yet; iPad never launched.
- Balancing, first pass:
  - An emptied building settles near reputation 50 (neutral satisfaction without tenants; the move-out penalty lasts one day).
  - The demo tower reaches class B on day 3.
  - Class A/Prime thresholds are not yet played through (only unit-tested for gating).
- Raising the rent level barely moves the reputation of existing tenants (they keep their rent; only asking rents change).
- The standing is tracked for the first building of the property only in the UI.

## Technical debt
- Assessment and summary each run a utility allocation: once per day in the simulation, and at 4 Hz in the UI.
- Per-step O(rooms) checks (structure signature, elevator sync, facilities sync). Simulation on the main thread.

## Next tasks (Phase 12 — Full day/night + lighting)
1. Window emission on façades at far zoom; light sources as data (room lighting profiles).
2. Lighting energy use feeding the electricity utility and the ledger.
3. Street and sky lighting through dusk and night; per-room schedules for lights.
4. Captures across a full day; docs.

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
