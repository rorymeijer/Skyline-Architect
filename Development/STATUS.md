# Development Status

_Last updated: 2026-09-26_

## Current phase
**Phase 1 — Renderer, camera, architectural grid: COMPLETE** (awaiting approval to start Phase 2).

## Current milestone
M1 “First Playable” (end of Phase 9) — not started.

## Quality gates (Phase 1)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run #5 (`6981841`), no warnings except Xcode's AppIntents notice |
| Automated tests pass | ✅ | 55 tests, Linux + macOS (`Scripts/test-package.sh`) |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built but not launched | capture run on macos-15 |
| Feature demonstrable | ✅ | 5 screenshots, `Development/Screenshots/Phase-01/` |
| Obvious runtime errors fixed | ✅ | capture settles in ~1 s per preset, exit 0 |
| Documentation updated | ✅ | ARCHITECTURE, GRAPHICS, DECISIONS, CHANGELOG, PERFORMANCE |
| Screenshots produced & inspected | ✅ | two issues found and fixed (see screenshot README) |
| Known issues recorded | ✅ | below |

## Completed
- Phase 0: docs, Xcode project, `SkylineKit` package, CI (Linux + macOS + iPad build + capture).
- Phase 1 (FUNCTIONAL): world model (world/city/property/plot/building/foundation), content
  pack loading, camera (zoom-to-anchor, inertia, trackpad/mouse/keyboard, iPad gestures,
  limits, presets), LOD bands, drawing IR, tiled background rasterization, procedural art
  (terrain, foundation, neighbours, skyline), architectural grid overlay with hover cell,
  developer HUD, View menu shortcuts, screenshot director, `skyline-snapshot` previews.

## In progress
- Nothing. Waiting for Phase 2 approval.

## Known bugs / unverified
- Interactive input has not been exercised by a human: scroll/pan direction under natural
  scrolling, inertia feel, pinch sensitivity may need tuning (logic is unit-tested).
- iPad build compiles but has never been launched in a simulator/device.
- Retina (2×) rendering not captured; CI display is 1×.
- Developer HUD can cover floor labels at the left edge (Debug only).

## Technical debt
- Distant skyline has no parallax (reads a bit close at mid zoom).
- Tile cache invalidation for changing content does not exist yet (static site only) — needed
  in Phase 2 (dirty-rect invalidation when construction changes the composition).
- `WorldScene` recomposes nothing at runtime; `AppModel` builds the composition once.
- CI screenshot window is 1024 × 681 (runner display size).

## Next tasks (Phase 2 — Construction + saves)
1. Command-based construction model (floors/slabs, walls, room shells, stairs/elevator shafts)
   with data-driven build rules and validation; demolition; session undo.
2. Construction tools in the UI (macOS: click-drag placement with hover preview; iPad: contextual).
3. Composition invalidation → tile dirty regions.
4. Versioned local save/load + autosave skeleton + migration tests (SAVE_FORMAT.md).
5. Screenshot presets for construction; Phase-02 screenshots.

## Environment
- Cloud sessions run in a Linux container without Xcode. To build/test the package there,
  install Swift from the official Docker image layers (download.swift.org is blocked):
  pull `library/swift:6.1-noble` layers via the Docker registry API, extract the toolchain
  layer into `/opt/swift`, apt-install its runtime deps (binutils libc6-dev
  libcurl4-openssl-dev libedit2 libgcc-13-dev libpython3-dev libsqlite3-0 libstdc++-13-dev
  libxml2-dev libncurses-dev libz3-dev pkg-config tzdata zlib1g-dev) and use
  `PATH=/opt/swift/usr/bin:$PATH`. `apt-get install librsvg2-bin` for SVG previews.
- The app target is verified by macOS CI (`.github/workflows/ci.yml`, runs on every push to
  `claude/**`); screenshots are uploaded as the `phase-screenshots` artifact.

## Local verification (on a Mac)
```sh
Scripts/test-package.sh
Scripts/build-app.sh && Scripts/capture-screenshots.sh /tmp/skyline-shots
open SkylineArchitect.xcodeproj   # run the SkylineArchitect scheme on "My Mac"
```
