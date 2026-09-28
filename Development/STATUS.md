# Development Status

_Last updated: 2026-09-28 (Phase 16)_

## Current phase
**Phase 16 — Scenarios: COMPLETE** (awaiting approval to continue with Phase 17).

## Quality gates (Phase 16)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36398839340 |
| Automated tests pass | ✅ | 262 tests (Linux + macOS); see the list below |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 8 captures in `Development/Screenshots/Phase-16/` (towers built with the developer blueprint tool; leasing and results are the simulation's own) |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | SCENARIOS.md (new), ESTATE (budget fix), SIMULATION, SAVE_FORMAT v13, MODDING, ARCHITECTURE, DECISIONS D-041, CHANGELOG 0.16.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | Found an empty Harrowgate tower (Phase 15 budget bug, fixed and tested) and UI issues (browser height, badge overlap, number grouping, menu subtitle): fixed and recaptured |
| Known issues recorded | ✅ | below |

The Phase 16 tests cover:

* **Content:** every scenario starts with its objectives, deadline, cash and city; invalid scenarios are rejected.
* **Winning:** Opening Day is won with the demo tower (day 3), and the result is decided once.
* **Losing:** the deadline closing ("Time ran out") and bankruptcy.
* **Streaks:** objectives must hold for `holdDays` closings in a row; a miss resets the streak.
* **Metrics:** population, units, cash, daily profit (construction excluded), class, wait, properties; upper-limit objectives.
* **Determinism:** a scenario run is batch-independent.
* **UI data:** browser briefs and live summaries.
* **Leasing:** scenario towers in Saltmere and Harrowgate find tenants on their own markets.
* **Saves:** v12 frozen and the v13 fixture with a scenario in progress.

## Completed
- Phases 0–15 (merged: rorymeijer/Skyline-Architect#1 … #15).
- Phase 16 (FUNCTIONAL):
  - **Scenarios as content:** five scenarios in `scenarios.json`, each with a start, cash, days, objectives and a hold streak.
  - **Objectives:** measured over the estate and decided at the daily closing; win, or lose by bankruptcy or the deadline; free play afterwards.
  - **UI:** scenario browser, objectives panel (⌥⌘O) and result screen.
  - **Save format 13.**
  - **Fix:** tenant budgets follow the city's rent level (Harrowgate towers never leased).

## In progress
- Nothing. Waiting for approval to continue (Phase 17 — Modding / content system).

## Known bugs / unverified
- No human play test yet; iPad never launched.
- Only Opening Day is verified winnable (by test). The other scenario targets are first-pass balancing and have not been played through.
- Objectives are estate-wide; there are no per-building goals, scores or scripted events.
- The live panel can show an objective as met during the day that the next closing misses.
- Earlier notes still apply: shared weather, estate-wide cash, fire rates, lighting costs.

## Technical debt
- `FireSafety.protectedRooms` and utility allocation are recomputed often (the scenario panel adds a 4 Hz wait measurement). Cache per structure/upkeep change if profiles show it.
- Reloading restores the saved camera even when a caller moves it right after (seen in the capture script).
- Simulation on the main thread.

## Next tasks (Phase 17 — Modding / content system)
1. Pack discovery (a user mods folder) and merge/override rules over the base pack.
2. Validation reporting per pack (which file, which entry) without taking the base game down.
3. A mod manager UI (enable, disable, order) and saves recording their packs.
4. Captures and docs.

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
