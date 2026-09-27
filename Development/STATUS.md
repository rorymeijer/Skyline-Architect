# Development Status

_Last updated: 2026-09-27_

## Current phase
**Phase 2 — Construction + saves: COMPLETE** (awaiting approval to start Phase 3).

## Current milestone
M1 “First Playable” (end of Phase 9) — Phases 1–2 of 9 done.

## Quality gates (Phase 2)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36306205755 (`74289b0`), no warnings except Xcode's AppIntents notice |
| Automated tests pass | ✅ | 92 tests (Linux + macOS): construction rules, undo round trips, integrity, saves, migrations, golden fixture, placement, composition |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 8 captures in `Development/Screenshots/Phase-02/` incl. save→load round trip (`worldIdentical=true`) and undo |
| Obvious runtime errors fixed | ✅ | all captures settle ≈1 s, exit 0 |
| Documentation updated | ✅ | ARCHITECTURE, SAVE_FORMAT, MODDING, DECISIONS D-013…D-016, CHANGELOG |
| Screenshots produced & inspected | ✅ | 5 issues found and fixed (see screenshot README) |
| Known issues recorded | ✅ | below |

## Completed
- Phase 0 + Phase 1 (merged in rorymeijer/Skyline-Architect#1).
- Phase 2 (FUNCTIONAL): floor plates, rooms/shafts, data-driven construction rules and costs,
  demolition, inverse-command undo/redo, content rooms/rules/blueprints, persistence module
  (versioned saves, migrations, integrity checks, atomic store, quicksave, load sheet,
  autosave), layered composition with dirty-rect tile invalidation, building/room art,
  placement planner with live preview, build palette, room labels, iPad placement gestures.

## In progress
- Nothing. Waiting for Phase 3 approval.

## Known bugs / unverified
- Interactive input (mouse/trackpad placement feel, natural-scroll direction, pinch) not yet
  exercised by a human; logic is unit-tested and captures drive the same APIs.
- iPad build compiles but has never been launched.
- Session construction cost is informational; money is not charged until Phase 9.
- Undo history is cleared by New Game / Load (by design) and not persisted in saves.

## Technical debt
- `ConstructionEngine` overlap checks scan all rooms of a building (O(rooms)); fine for
  hundreds, add an occupancy index before thousands (Phase 19 or when profiling says so).
- `SiteComposer.recompose` rebuilds every building on the property after each command;
  per-building caching when properties hold several towers.
- Distant skyline has no parallax.
- CI commits JPEG captures to `Development/Screenshots/_ci-latest/` on every push to a
  `claude/**` branch (~1 MB each; chosen with the user because artifact storage is blocked
  from restricted sessions). Consider pruning history before a 1.0 release.

## Next tasks (Phase 3 — First furnished rooms)
1. Furniture recipes per room appearance (office desks/chairs/computers/meeting tables,
   apartment bed/sofa/kitchen/bath, lobby reception) as data-driven layouts.
2. Exterior façade treatment + LOD: façade when zoomed out, cutaway interiors when zoomed in.
3. `ASSET_REQUIREMENTS.md` for art procedural generation cannot reach.
4. Screenshot presets for furnished interiors; Phase-03 screenshots.

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
