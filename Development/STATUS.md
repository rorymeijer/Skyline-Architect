# Development Status

_Last updated: 2026-09-29 (0.26.0 — F2: 500 floors)_

## Current phase
**Next round (the player's plan):**

| Step | Content | State |
|------|---------|-------|
| F1 | Balance bot and tuning | COMPLETE (rorymeijer/Skyline-Architect#31) |
| F2 | 500 floors running smoothly | COMPLETE on the branch |
| F3 | Tutorial, in-game manual, website (`Website/`) | Planned |
| F4 | Accessibility and iPad | Planned |
| F5 | iPhone | Planned |

F2 profiled a 526-floor tower (2 511 people, 74 cars) with callgrind and removed the hot
spots:
- staff rooms are looked up once per call;
- cars have graph nodes only at their stops;
- routes use A* search;
- breakdowns keep the route cache;
- the cache is warmed on load;
- night windows are drawn as strips when zoomed far out.

Two game days: 9.1 s → 3.6 s. Worst step: 400 → 134 ms. Daily closing: 826 → 65 ms.
Details in PERFORMANCE.md and D-057.

Evidence: 357 tests (new: a warmed cache changes nothing; breakdowns keep the graph; night
strips). `skyline-bench` numbers are in PERFORMANCE.md. The app side (strips, warming on load)
is verified by the CI build and captures only: no 500-floor app capture was taken.

F1 (merged) ran the `skyline-balance` bot on every scenario, fixed high-floor leasing, eased
the class thresholds, tuned the targets and fixed an elevator-repair crash (BALANCE.md,
D-056).

## Quality gates (0.20.1)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36444953400 |
| Automated tests pass | ✅ | 290 tests (Linux + macOS): per-city weather, v14 migration and fixture, pack hashes, estate split, camera inset, particle scale, city activity |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Fixes demonstrable | ✅ | CI run 36445406112: 7 captures in `Development/Screenshots/Fixes-0.20.1/` (weather, grant and panel openings set by the script — labelled) |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | OPEN_ITEMS, SAVE_FORMAT (v14), ESTATE, WEATHER, LIGHTING, MODDING, DECISIONS D-046/D-047, CHANGELOG 0.20.1, ROADMAP |
| Screenshots produced & inspected | ✅ | The estate capture first fell outside the 24 h window (estate $0): script adjusted and recaptured |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–20 (merged: rorymeijer/Skyline-Architect#1 … #20).
- 0.20.1:
  - **B1** side panels become tabs when they do not fit (`PanelStack`).
  - **B2** the camera may look 150 pt below the ground; presets frame above the build bar.
  - **B3** weather per city (save format 14, migration, golden fixture v14).
  - **B4** one account for the estate — kept by design (D-046).
  - **B5** a content hash per pack in saves; changed packs are reported on load.
  - **B6** the estate overview splits building and estate money and shows each city's weather.
  - **B7** rain and snow scale with the zoom.
  - **B8** city windows go out through the night; street lamps stay on (own tile layer).

## Whole-game review (end of the roadmap)
- **FUNCTIONAL, with tests and real captures:**
  - construction with undo;
  - people and navigation;
  - elevators, banks and dispatch;
  - tenants and the market;
  - economy;
  - facilities;
  - progression;
  - lighting;
  - weather;
  - emergencies;
  - estate and cities;
  - scenarios;
  - modding;
  - versioned saves (format 14);
  - save sync logic;
  - performance at scale;
  - polish.
- **Implemented but unverified:**
  - iCloud Drive (needs a signing team);
  - the iPad (built on CI, never launched);
  - performance on real Apple hardware (only CI VMs and a Linux container).
- **Not done:**
  - human play test and balancing (only Opening Day is proven winnable);
  - Dynamic Type;
  - keyboard navigation inside panels;
  - removing entries or shipping images in mods;
  - a background simulation thread (D-044).

## Known bugs / unverified
- With many panels open the tab row can get wide (nine tabs ≈ 650 pt); fine on the tested 1024–1440 pt windows.
- The daily closing is still a 100 ms spike on very large towers; night window panes cost 4–5 ms per frame on the 211-floor tower.
- Accessibility is verified by code review only, not with VoiceOver on a device.
- Earlier notes still apply (STATUS history in git): scenario balance. Which city windows are lit does not change through the night, only how many show.

## Technical debt
- Utility allocation is a full recomputation (about 4 ms at 400 floors).
- Window panes are separate nodes.
- Simulation on the main thread.

All open items in one checklist: `Documentation/OPEN_ITEMS.md`.

## Suggested next steps (beyond the roadmap)
1. A human play test on a Mac and an iPad, followed by a balancing pass (scenario targets, tenant budgets, costs).
2. A signed build with iCloud, then verify sync between two devices.
3. Dynamic Type, keyboard navigation of panels, and a VoiceOver pass on a device.
4. A background simulation actor if the play test shows the daily-closing hitch.

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
