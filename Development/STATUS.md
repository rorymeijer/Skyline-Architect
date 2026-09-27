# Development Status

_Last updated: 2026-09-27 (Phase 9 — M1)_

## Current phase
**Phase 9 — Economy + basic day/night: COMPLETE → milestone M1 “First Playable” reached**
(awaiting approval to continue with Phase 10).

## Quality gates (Phase 9)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36343296837 |
| Automated tests pass | ✅ | 183 tests (Linux + macOS) incl. charged construction with exact undo refunds, refusal without cash, daily closing traceability, loans, bankruptcy, rent level vs demand, day/night, preview funds check, save v5→v6 + v6 fixture |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 8 captures in `Development/Screenshots/Phase-09/` |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | ECONOMY.md (new), GRAPHICS (day/night), SAVE_FORMAT v6, MODDING, ARCHITECTURE, DECISIONS D-031…D-033, PERFORMANCE, CHANGELOG 0.9.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | dark start and wrong closing day found, fixed, recaptured |
| Known issues recorded | ✅ | below |

## M1 “First Playable” checklist
| Step | Status | Evidence |
|------|--------|----------|
| Launch the app → main menu | ✅ | capture 01 |
| Start a new game (sandbox, starting capital) | ✅ | capture 02, `newGamesStartWithCapital` |
| Build floors, rooms, stairs and an elevator; pay for them; undo refunds | ✅ | capture 02, `constructionIsChargedAndUndoRefundsExactly`, `constructionNeedsCash` |
| Tenants arrive, choose units, move in | ✅ | Phase 8 captures, `marketFillsAnEmptyTowerDeterministically` |
| People follow schedules, use stairs and elevators | ✅ | Phases 4–7 captures and tests |
| Rent income and running costs, traceable | ✅ | captures 03, 06, `dailyClosingIsTraceable` |
| Loans, rent level, bankruptcy | ✅ | `loansAreLimitedAndRepaid`, `rentLevelDrivesAskingRentAndDemand`, `sevenDaysInTheRedIsBankruptcy` |
| Day and night visibly differ; lit homes at night | ✅ | captures 04, 05 |
| Save → back to menu → Continue → identical game | ✅ | captures 07, 08 (`matches the save: true`) |
| Quit the app and relaunch → Continue | ⚠️ | not exercised: CI runs one process; Continue reads the newest save file from disk, which is what a relaunch uses |
| Human play test with mouse/keyboard (and iPad) | ⚠️ | never done — all interaction so far is scripted |

## Completed
- Phases 0–8 (merged: rorymeijer/Skyline-Architect#1 … #8).
- Phase 9 (FUNCTIONAL): ledger with traceable transactions; construction charged through
  the history (exact undo refunds, refused without cash, preview warns); daily closing
  (rent, maintenance, utilities, interest); loans; rent level; bankruptcy; economy panel
  (⌥⌘M); cash in the status pill; basic day/night; main menu with Continue; bankruptcy
  screen; save format 6.

## In progress
- Nothing. Waiting for approval to continue (Phase 10 — utilities + maintenance).

## Known bugs / unverified
- No human play test yet (see checklist); iPad never launched.
- Economy balance is first-pass (rent billed per game day, D-032); no taxes, wages or staff.
- Tenants who move out vanish instantly; long tenant names only show when zoomed in.
- Night lighting is basic (no window emission from façades at far zoom beyond room glow).

## Technical debt
- Per-step O(rooms) checks (structure signature, elevator sync); call assignment scans.
- Market appraisal cost with many vacancies unmeasured; simulation on the main thread.

## Next tasks (Phase 10 — Utilities + maintenance)
1. Utility networks (electricity, water, HVAC, waste, internet) with capacity from
   equipment rooms; shortages affect tenants.
2. Wear and cleanliness per room; repair and cleaning jobs done by staff who travel
   through the building (shared navigation); wages in the ledger.
3. Service elevators for staff (deferred from Phase 7).
4. Maintenance/utilities overlays and panels.

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
