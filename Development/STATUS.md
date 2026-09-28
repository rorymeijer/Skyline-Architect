# Development Status

_Last updated: 2026-09-28 (Phase 12)_

## Current phase
**Phase 12 — Full day/night + lighting: COMPLETE** (awaiting approval to continue with
Phase 13).

## Quality gates (Phase 12)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36380170316 |
| Automated tests pass | ✅ | 221 tests (Linux + macOS). They cover:<br>• lighting levels, quiet hours and staggering<br>• content lights every room and no shaft<br>• load follows the day; the closing bills the meter<br>• no power, no light; metering is batch-independent<br>• coloured lit rooms, panes when zoomed out, grade<br>• emission layer deterministic; buildings occlude city lights<br>• save v8→v9 and the v9 fixture |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 9 captures in `Development/Screenshots/Phase-12/` |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0, 60 fps |
| Documentation updated | ✅ | LIGHTING.md (new), GRAPHICS, SIMULATION, SAVE_FORMAT v9, MODDING, ARCHITECTURE, DECISIONS D-037, PERFORMANCE, CHANGELOG 0.12.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | City lights shining through the tower and a crowded bill capture: fixed, recaptured |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–11 (merged: rorymeijer/Skyline-Architect#1 … #11).
- Phase 12 (FUNCTIONAL):
  - Lighting model per room type (content), shared by the simulation and the renderer; lights need electricity.
  - Hourly energy meter billed at the closing.
  - Colour grading; coloured room light; façade window panes when zoomed out.
  - Night emission layer: city windows, neighbour windows, street lamps.
  - Save format 9.

## In progress
- Nothing. Waiting for approval to continue (Phase 13 — weather).

## Known bugs / unverified
- No human play test yet; iPad never launched.
- Lighting energy is small next to rent (about $130/day vs $45k/day); balancing is still open. There is no player lighting policy yet.
- Plant rooms keep 15–20 % light without power (they have no electricity demand in the content).
- City lights are static per game, and the lamp glow is flat programmer art.
- Balancing notes from Phase 11 still apply (reputation floor near 50, fast class B).

## Technical debt
- Utility allocation now runs in the hourly meter, the daily assessment and the 4 Hz UI refresh (facilities, power map, lighting load). Cache per structure/upkeep change if profiles show it.
- Simulation on the main thread.

## Next tasks (Phase 13 — Weather)
1. Weather states as content (clear, overcast, rain, storm, snow, heat, fog), with deterministic daily and hourly changes from the city seed.
2. Visual: sky and grade per weather, rain streaks, fog, wet paving reflections.
3. Simulation hooks (data-driven): heat and cold raise the energy load; storms and snow add wear and cleaning jobs; rain shifts arrivals and departures.
4. Captures across weather types; docs.

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
