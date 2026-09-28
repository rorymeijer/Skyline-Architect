# Development Status

_Last updated: 2026-09-28 (Phase 13)_

## Current phase
**Phase 13 — Weather: COMPLETE** (awaiting approval to continue with Phase 14).

## Quality gates (Phase 13)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36384182661 |
| Automated tests pass | ✅ | 233 tests (Linux + macOS). They cover:<br>• generation: seasons cycle from summer; kinds only in their seasons; the forecast comes true; deterministic per seed; all kinds occur<br>• the world's weather follows the days, and older games start weather on their day<br>• storms keep prospects away; temperature scales the utilities bill (×1.48 at 35 °C, ×1.60 at −1 °C); storms wear and dirty the building<br>• look: transition after 06:00, snow cover rules, deterministic lightning, grade and lights<br>• roofs and street segments<br>• save v9→v10 and the v10 fixture |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 9 captures in `Development/Screenshots/Phase-13/` (weather in 02–07 set by the script, labelled) |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0, 60 fps |
| Documentation updated | ✅ | WEATHER.md (new), GRAPHICS, SIMULATION, SAVE_FORMAT v10, MODDING, ARCHITECTURE, DECISIONS D-038, CHANGELOG 0.13.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | Washed-out storm flash and invisible snow cover: fixed, recaptured |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–12 (merged: rorymeijer/Skyline-Architect#1 … #12).
- Phase 13 (FUNCTIONAL):
  - Seasons and seven weather kinds (content), drawn each morning with a forecast.
  - Effects on prospects, wear, dirt and heating/cooling.
  - Visuals: grade, fog, rain and snow, lightning, snow cover, wet paving; weather chip.
  - Save format 10.

## In progress
- Nothing. Waiting for approval to continue (Phase 14 — events and emergencies, including fire).

## Known bugs / unverified
- No human play test yet; iPad never launched.
- Weather changes once a day; day length ignores the season; no wind.
- Particles are screen-space programmer art, and snow cover is drawn exaggerated for readability.
- Balancing: lighting costs small, reputation floor near 50, fast class B (earlier phases).

## Technical debt
- Utility allocation runs in several places per refresh (see Phase 12).
- Simulation on the main thread.

## Next tasks (Phase 14 — Events & emergencies)
1. Event system as content: triggers (weather, wear, time, reputation) and outcomes (damage, cost, reputation). Deterministic.
2. Fire: ignition chance from wear and equipment; spread through rooms and floors; evacuation over stairs (shared navigation); damage and repair; fire safety rooms and staff.
3. Storm damage and power outages tied to the Phase 13 weather.
4. Notifications/alerts UI; captures; docs.

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
