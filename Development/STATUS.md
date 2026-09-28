# Development Status

_Last updated: 2026-09-28 (Phase 18)_

## Current phase
**Phase 18 — iCloud persistence: COMPLETE** (awaiting approval to continue with Phase 19). Status of the parts:

* The sync logic is FUNCTIONAL and tested.
* The iCloud Drive connection is implemented but **unverified**: it needs a signed build with an iCloud container.

## Quality gates (Phase 18)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36416756463 |
| Automated tests pass | ✅ | 275 tests (Linux + macOS); 6 new sync tests with two simulated devices |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ (sync logic) · ⚠️ (iCloud itself) | 7 captures in `Development/Screenshots/Phase-18/`, synced against a stand-in folder with a simulated second device (labelled); 06 shows the real iCloud lookup failing on the unsigned CI build |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | SAVE_FORMAT (Sync section, iCloud setup), DECISIONS D-043, CHANGELOG 0.18.0, ARCHITECTURE, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | Conflict scene wrongly scripted (no conflict — correct behaviour for that order): fixed; conflict badge shortened |
| Known issues recorded | ✅ | below |

The Phase 18 tests cover:

* **Travel:** saves travel between devices (upload, download, idempotent).
* **Conflicts** keep both versions on both devices, under valid, unique names.
* **Deletions** follow only unchanged copies; a changed copy is restored.
* **Placeholders** are pending: never overwritten and never taken as a deletion.
* **Autosaves** stay on the device, and the sync state file is not a save.
* **Fingerprints** are stable.

## Completed
- Phases 0–17 (merged: rorymeijer/Skyline-Architect#1 … #17).
- Phase 18:
  - **`SaveSync`:** two-way sync between folders — fingerprints, a per-device base, keep-both conflicts, safe deletions, placeholders.
  - **App:** iCloud Drive container, sync off by default, and sync on launch, on save, when the panel opens and on Sync Now.
  - **Saves panel:** replaces the load sheet, with sync badges, paging and delete.

## In progress
- Nothing. Waiting for approval to continue (Phase 19 — Large-scale performance).

## Known bugs / unverified
- **iCloud Drive has never run.** It needs the iCloud capability with a container and a signing team (SAVE_FORMAT.md → Setup). Only the sync logic is verified (tests, and captures against a stand-in folder).
- No `NSFileCoordinator` and no live `NSMetadataQuery` updates: sync happens at fixed moments.
- The conflict row's detail text is cut off with long slot names.
- No human play test yet; iPad never launched.
- Earlier notes still apply: mods cannot remove entries or ship images, scenario balance beyond Opening Day, shared weather.

## Technical debt
- Sync reads every save file to fingerprint it on each run (fine for tens of saves).
- `FireSafety.protectedRooms` and utility allocation are recomputed often.
- Simulation on the main thread (Phase 19).

## Next tasks (Phase 19 — Large-scale performance)
1. Build a large test tower (hundreds of floors, thousands of rooms and people) with a blueprint generator, and profile simulation, navigation, rendering and saving.
2. Record baselines in PERFORMANCE.md; fix the worst hot spots (caching of utilities and fire protection, route cache, tile rasterization).
3. Move the simulation off the main thread if profiles call for it (SimulationHost actor publishing snapshots).
4. Scale tests, docs and captures.

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
