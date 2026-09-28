# Development Status

_Last updated: 2026-09-28 (Phase 19)_

## Current phase
**Phase 19 — Large-scale performance: COMPLETE** (awaiting approval to continue with Phase 20).

## Quality gates (Phase 19)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36423606533 |
| Automated tests pass | ✅ | 279 tests (Linux + macOS), including 4 new scale tests |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 7 captures in `Development/Screenshots/Phase-19/` (stress towers from the developer tool — labelled); `skyline-bench` numbers in PERFORMANCE.md |
| Profiled before optimising (rule 8) | ✅ | callgrind on `skyline-bench`; the app's per-section scene timing |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | PERFORMANCE.md (Phase 19 section), DECISIONS D-044, CHANGELOG 0.19.0, SIMULATION (route cache), ARCHITECTURE, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | Four CI rounds: panel refresh and weather roofs fixed (32–42 → 47–57 fps); camera placement of rebuilt scenes fixed |
| Known issues recorded | ✅ | below |

**Results.**

* **Simulation** (release, 211 floors / 950 people): 2.4 s → 0.72 s per game day; the daily
  closing went from 1 058 ms to 100 ms.
* **400 floors / 2 166 people:** two days take 9.0 s → 4.5 s.
* **App** (Debug, CI): the stress towers render at 47–57 fps, with a scene update of 0.3–1.3 ms
  (5 ms at night).

## Completed
- Phases 0–18 (merged: rorymeijer/Skyline-Architect#1 … #18).
- Phase 19:
  - **Tooling:** the `StressTower` generator and the `skyline-bench` CLI; a developer tool to load the stress tower; per-section scene timing.
  - **Simulation fixes:**
    - one utility allocation per market hour and per daily review;
    - elevator banks cached per structure;
    - the route cache raised to 65 536;
    - cheaper noise and allocation lookups.
  - **App fixes:** one allocation per 4 Hz refresh (panels and services overlay); roofs in O(n) and only under snow; indexed plate lookup.

## In progress
- Nothing. Waiting for approval to continue (Phase 20 — Visual polish).

## Known bugs / unverified
- The daily closing is still a single 100 ms spike on a 211-floor tower (650 ms on the first day of a 400-floor tower with a cold route cache). The simulation stays on the main thread (D-044).
- Night view of huge towers: 1 845 window-pane nodes (a 4.6 ms "light" section per frame).
- The fixed cost per `advance` call is 0.5–0.6 ms at 400 floors: the heap is rebuilt and the signatures checked every call.
- Measured on CI VMs and a Linux container only, never on a real Mac or iPad; iPad never launched.
- Earlier notes still apply: iCloud unverified, scenario balance beyond Opening Day, mods cannot remove entries.

## Technical debt
- Utility allocation is still a full recomputation (about 4 ms at 400 floors). Make it incremental if hourly or refresh costs show up.
- Window panes are separate nodes; batch them into emission tiles for very tall towers.
- The move-in wave on the first day plans about 1 000 routes in a few steps.

## Next tasks (Phase 20 — Visual polish)
1. An art pass on the most visible elements (façade, lobbies, people, elevators) within the procedural pipeline.
2. Animation and particles where they help readability (doors, crowds, weather).
3. UI polish: consistent panels, iconography, keyboard navigation, accessibility (VoiceOver labels, Dynamic Type where it applies, contrast).
4. Captures, docs and a final review of the whole game.

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
