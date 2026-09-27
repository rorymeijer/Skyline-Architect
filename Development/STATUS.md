# Development Status

_Last updated: 2026-09-27 (Phase 3)_

## Current phase
**Phase 3 — First furnished rooms: COMPLETE** (awaiting approval to start Phase 4).

## Current milestone
M1 “First Playable” (end of Phase 9) — Phases 1–3 of 9 done.

## Quality gates (Phase 3)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36327134414 (`dc4dfb3`) |
| Automated tests pass | ✅ | 104 tests (Linux + macOS), incl. layout resolver, art catalog validation, detail bands, façade/cutaway LOD |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 8 captures in `Development/Screenshots/Phase-03/` |
| Obvious runtime errors fixed | ✅ | all captures settle, exit 0 |
| Documentation updated | ✅ | GRAPHICS, MODDING, ARCHITECTURE, DECISIONS D-017/D-018, ASSET_REQUIREMENTS, CHANGELOG |
| Screenshots produced & inspected | ✅ | 2 issues found and fixed |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–2 (merged in rorymeijer/Skyline-Architect#1 and rorymeijer/Skyline-Architect#2).
- Phase 3 (FUNCTIONAL, programmer art): data-driven materials/furniture/interiors, layout
  resolver, furnished offices/apartments/lobbies/corridors/mechanical/parking, exterior
  façade LOD, asset requirements document.

## In progress
- Nothing. Waiting for Phase 4 approval.

## Known bugs / unverified
- Interactive input not yet exercised by a human; iPad build never launched.
- Construction cost informational until Phase 9; undo history cleared by New Game / Load.

## Technical debt
- `ConstructionEngine` overlap checks and `SiteComposer.recompose` are O(rooms) / whole
  property per command — fine now, index/caching when profiling shows need.
- Furniture recipes are flat vector art; close-up sprites per ASSET_REQUIREMENTS.md later.
- Distant skyline has no parallax.
- CI commits ~1 MB of JPEG captures per development-branch run (`_ci-latest`).

## Next tasks (Phase 4 — Basic people simulation)
1. `SimulationHost` with fixed-tick clock; pause / 1× / 2× / 4× / 10× by tick count
   (never scaling dt); determinism test comparing state hashes across speeds.
2. People: identity, simple schedule skeleton, spawn at the lobby, walk along floors, enter
   and leave rooms (stairs only — elevators arrive in Phase 6).
3. Render snapshots + interpolation; agent sprites with walk animation (programmer art),
   agent render LOD; HUD: sim time, speed, agent counts, tick time.
4. Save format v2 with a migration (people + clock) and a kept v1 fixture.

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
