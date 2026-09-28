# Development Status

_Last updated: 2026-09-28 (Phase 15)_

## Current phase
**Phase 15 — Multiple properties & cities: COMPLETE** (awaiting approval to continue with Phase 16).

## Quality gates (Phase 15)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36392926388 |
| Automated tests pass | ✅ | 250 tests (Linux + macOS); see the list below |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 8 captures in `Development/Screenshots/Phase-15/` (towers built with the developer blueprint tool, one loan taken by the script — labelled) |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | ESTATE.md (new), SIMULATION, SAVE_FORMAT v12, MODDING, ARCHITECTURE, DECISIONS D-040, CHANGELOG 0.15.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | Crown Yard too narrow for the demo tower, and the developer grant under-priced blueprints: both fixed and recaptured |
| Known issues recorded | ✅ | below |

The Phase 15 tests cover:

* **Offers:** the start plot is owned; the others are for sale with their city's market.
* **Buying:** adds city, property, building with the plot's foundation and a `land` transaction; refused atomically without the cash.
* **Buildability:** every plot for sale takes a floor, and the demo tower fits every plot of 32 m or more.
* **City prices:** Harrowgate construction ×1.25 and asking rent ×1.35.
* **City markets:** demo towers in two cities each lease their own units (15/15).
* **Legacy saves:** older properties are matched to their plot and get the city's market.
* **Saves:** v11→v12 migration, v11 frozen, and the v12 fixture with two cities.

## Completed
- Phases 0–14 (merged: rorymeijer/Skyline-Architect#1 … #14).
- Phase 15 (FUNCTIONAL):
  - **Cities:** Port Calder, Harrowgate and Saltmere, each with a market (rent, construction, demand), ground and skyline.
  - **Land:** plots for sale with a price and a ready foundation; buying land (`Estate.buy`).
  - **Economy:** construction costs and asking rents follow the city; a rental market per city.
  - **UI:** estate panel (⌥⌘K) with holdings, *Go* and *Buy*; the simulation runs the whole estate.
  - **Save format 12.**

## In progress
- Nothing. Waiting for approval to continue (Phase 16 — Scenarios).

## Known bugs / unverified
- No human play test yet; iPad never launched.
- Weather is shared by the whole estate (drawn from the first city's seed).
- Cash and loans are estate-wide; land cannot be sold; one building per plot.
- The overview's 24-hour figure counts only money booked to buildings (not loans, interest or land).
- City markets are first-pass balancing (Harrowgate earns most per tower; Saltmere's cheap land pays back slowly).
- Earlier notes still apply (fire rates, lighting costs, reputation floor, fast class B).

## Technical debt
- `FireSafety.protectedRooms` and utility allocation are recomputed often. Cache per structure/upkeep change if profiles show it.
- Only the active property has a scene; switching rebuilds it (fine at three properties).
- Simulation on the main thread.

## Next tasks (Phase 16 — Scenarios)
1. Scenario definitions as content: start (city, plot, cash, unlocks), objectives, win/lose conditions and a time limit.
2. Objective evaluation in the simulation (population, elevator waits, profit, class), deterministic and tested.
3. A scenario browser on the main menu and an objectives panel in game; a result screen.
4. Save format bump for the active scenario; captures and docs.

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
