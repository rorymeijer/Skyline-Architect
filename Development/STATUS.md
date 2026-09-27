# Development Status

_Last updated: 2026-09-27 (Phase 8)_

## Current phase
**Phase 8 — Tenants + schedules: COMPLETE** (awaiting approval to start Phase 9).

## Current milestone
M1 “First Playable” (end of Phase 9) — Phases 1–8 of 9 done.

## Quality gates (Phase 8)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36341716790 |
| Automated tests pass | ✅ | 172 tests (Linux + macOS) incl. tenant model, adoption of old populations, appraisal criteria, market fill (reproducible), move-outs when units become unreachable, satisfied tenants stay, reports, content validation, save v4→v5 + v5 fixture |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 7 captures in `Development/Screenshots/Phase-08/` |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | TENANTS.md (new), SIMULATION, SAVE_FORMAT v5, MODDING, ARCHITECTURE, DECISIONS D-029/D-030, PERFORMANCE, CHANGELOG 0.8.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | vacant labels and log flooding found, fixed, recaptured |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–7 (merged: rorymeijer/Skyline-Architect#1 … #7).
- Phase 8 (FUNCTIONAL): tenants (households/businesses) from `tenants.json`; rooms with
  rent and noise; deterministic hourly market with appraisal (rent, access incl. measured
  elevator waits, noise, view), signing/declining with reasons; daily reviews and
  move-outs; four new schedules; unit inspector (click), tenant labels, Leasing panel
  (⌥⌘L), developer lease-all; save format 5 with adoption of existing people.

## In progress
- Nothing. Waiting for Phase 9 approval.

## Known bugs / unverified
- Clicking rooms, the inspector and ⌥⌘L not exercised by a human; iPad never launched.
- Market balance: the demo tower fills within ~1 day; rates/budgets to be tuned with the
  economy. Rent is recorded, not charged.
- People of a tenant who moves out vanish immediately (no leaving walk).
- Long tenant names only show when zoomed in; no amenities criterion yet (retail later).

## Technical debt
- Market appraisal cost with many vacancies is unmeasured (route plans cached).
- Call assignment/car decisions scan people; signature and sync checks per step (O(rooms)).
- Simulation on the main thread.

## Next tasks (Phase 9 — Economy + basic day/night → M1 First Playable)
1. Ledger with traceable transactions: rent collection, construction costs charged,
   maintenance, utilities; balance and bankruptcy.
2. Configurable rents (per unit or building) feeding tenant appraisal.
3. Economy panel (income/expenses by source, cash flow).
4. Basic day/night: sky, ambient tint, lit windows at night.
5. Main menu (new game, continue, load) and the M1 checklist (§38).

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
