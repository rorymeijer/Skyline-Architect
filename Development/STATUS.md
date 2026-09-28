# Development Status

_Last updated: 2026-09-28 (Phase 14)_

## Current phase
**Phase 14 — Events & emergencies: COMPLETE** (awaiting approval to continue with Phase 15).

## Quality gates (Phase 14)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36388937901 |
| Automated tests pass | ✅ | 242 tests (Linux + macOS); see the list below |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 9 captures in `Development/Screenshots/Phase-14/` (fires started with the developer tool, storm set — labelled) |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | EMERGENCIES.md (new), GRAPHICS, SIMULATION, SAVE_FORMAT v11, MODDING, ARCHITECTURE, DECISIONS D-039, CHANGELOG 0.14.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | Evacuation shot too late, no storm damage in time, and saved after the fire: fixed and recaptured. One app build failure (missing import): fixed. |
| Known issues recorded | ✅ | below |

The Phase 14 tests cover:

* **Evacuation:** everybody leaves by the stairs, with no elevator boardings, and nobody goes in.
* **Unprotected fire:** it burns until the brigade arrives, and brings the repair bill, repair jobs, reputation loss and people returning.
* **Sprinklers:** a covered fire is out in 4 min instead of 45 min.
* **Determinism:** fires are deterministic and batch-independent.
* **Ignition odds:** worn rooms and plant ignite more often; sprinklers halve the odds; shafts never ignite.
* **Weather incidents:** storm damage; a power outage fails the plant and turns the lights off.
* **Visuals:** flames, fire engines, soot, sprinkler flags.
* **Saves:** v10→v11 migration and the v11 fixture with a fire in progress.

## Completed
- Phases 0–13 (merged: rorymeijer/Skyline-Architect#1 … #13).
- Phase 14 (FUNCTIONAL):
  - **Fire:** ignition; growth and spread; sprinklers from a new fire control room; the fire brigade; stairs-only evacuation with nobody entering during the fire; damage, repairs, lost tenants and reputation loss.
  - **Weather incidents:** storm damage, power outages, burst pipes.
  - **UI:** alert with Show, incidents panel, fire visuals.
  - **Save format 11.**

## In progress
- Nothing. Waiting for approval to continue (Phase 15 — multiple properties and cities).

## Known bugs / unverified
- No human play test yet; iPad never launched.
- The fire brigade and smoke are abstract: the engine parks at the kerb, and smoke does not move between floors or through the stairs.
- Nobody is ever harmed (by design).
- Fire and incident rates are first-pass balancing (one unprotected office fire costs about $20k).
- The capture script sets fires and weather; natural ignition is rare and was only unit-tested.
- Earlier balancing notes still apply (lighting costs, reputation floor, fast class B).

## Technical debt
- `FireSafety.protectedRooms` and utility allocation are recomputed often (hourly ignition, fire steps, 4 Hz UI). Cache per structure/upkeep change if profiles show it.
- Simulation on the main thread.

## Next tasks (Phase 15 — Multiple properties & cities)
1. Several properties per city and more cities as content, each with plots, geology and economic variables (rents, costs, demand).
2. A property switcher and overview; buying land.
3. The simulation runs all properties (shared clock); the ledger attributes per property.
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
