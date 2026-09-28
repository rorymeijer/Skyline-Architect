# Development Status

_Last updated: 2026-09-28 (Phase 17)_

## Current phase
**Phase 17 — Modding / content system: COMPLETE** (awaiting approval to continue with Phase 18).

## Quality gates (Phase 17)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36405609107 |
| Automated tests pass | ✅ | 269 tests (Linux + macOS); see the list below |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Feature demonstrable | ✅ | 8 captures in `Development/Screenshots/Phase-17/` (the broken mod was written by the capture script, and the tower built with the blueprint tool — labelled) |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | MODDING.md (rewritten: mods, overlay rules, validation, saves, example), ARCHITECTURE, DECISIONS D-042, CHANGELOG 0.17.0, GAME_DESIGN, ROADMAP |
| Screenshots produced & inspected | ✅ | Unreadable validation prefix and palette overflow (then a scroll view that does not render in captures): fixed and recaptured. Two app compile failures fixed first. |
| Known issues recorded | ✅ | below |

The Phase 17 tests cover:

* **Example mod:** it loads over the base pack (city, plot, room, layout, tenant, scenario, blueprint); a replaced entry keeps the base order.
* **Playability:** the mod's content works — its scenario starts, a loft is placed, and its blueprint builds.
* **Disabled mods** are listed but not loaded.
* **Broken mods** are reported and skipped, while the others load: invalid JSON, a bad reference (attributed to the mod), an unknown kind, a missing requirement, a duplicate id.
* **Requirements** follow the load order.
* **Discovery** ignores folders without a manifest.
* **Single files** replace, and materials merge.

## Completed
- Phases 0–16 (merged: rorymeijer/Skyline-Architect#1 … #16).
- Phase 17 (FUNCTIONAL):
  - **Loading:** `ContentPack` (read and overlay) and `ContentLibrary.build`; `ModLoader` handles discovery, load order, validation per mod, `requires`, and a status per pack.
  - **App:** it loads the enabled mods, and the mod manager enables, orders, installs examples and applies. Saves record every pack.
  - **Example mod:** Kestrel Bay.
  - **Palette:** icon-only when too wide.

## In progress
- Nothing. Waiting for approval to continue (Phase 18 — iCloud persistence).

## Known bugs / unverified
- No human play test yet; iPad never launched (the mod folder there is the app container, with no file browser integration yet).
- Mods cannot remove base entries or ship images; a replaced entry must be copied whole.
- Saves check pack ids, not versions or content hashes: a changed mod can alter a running save.
- Changing mods starts a fresh game (by design, D-042).
- Earlier notes still apply: scenario balance beyond Opening Day, shared weather, estate-wide cash.

## Technical debt
- Validating after each mod rebuilds the whole library, which is fine for a handful of mods.
- `FireSafety.protectedRooms` and utility allocation are recomputed often.
- Reloading restores the saved camera even when a caller moves it right after.
- Simulation on the main thread.

## Next tasks (Phase 18 — iCloud persistence)
1. Optional iCloud Drive save sync (ubiquity container), off by default.
2. Conflict handling: keep both copies, newest-wins suggestion, never silent overwrite.
3. Status in the load sheet (local, uploading, in iCloud, conflict).
4. Tests for the conflict rules; docs and captures (as far as CI can show without an iCloud account).

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
