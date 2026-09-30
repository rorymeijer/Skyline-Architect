# CLAUDE.md — Skyline Architect development rules

Skyline Architect is an original, native Apple-platform vertical building management
simulation (macOS primary, iPadOS secondary). Swift, SwiftUI, SpriteKit. No third-party
engines, no web wrappers, no copied assets/UI/names from existing games.

Before starting work, read `Development/STATUS.md` (current state) and
`Documentation/ARCHITECTURE.md` (module boundaries). Record significant decisions in
`Documentation/DECISIONS.md`.

## Repository layout

| Path | Contents |
|------|----------|
| `SkylineArchitect.xcodeproj` | Xcode project: one multiplatform app target (macOS + iPadOS) |
| `App/` | Apple-only app shell: SwiftUI, SpriteKit renderer, input, platform glue (synchronized folder — new files are picked up automatically) |
| `Packages/SkylineKit/` | Swift package with all platform-independent engine code + tests |
| `Packages/SkylineKit/Sources/SkylineCore` | Authoritative game model (world, property, plot, building, grid) |
| `Packages/SkylineKit/Sources/SkylineContent` | Data-driven content definitions (JSON), loading, validation, new-game factory |
| `Packages/SkylineKit/Sources/SkylinePresentation` | Camera, LOD, culling, drawing IR, procedural art, scene composition, tile planning |
| `Packages/SkylineKit/Sources/SkylinePersistence` | Versioned saves, migrations, save store |
| `Packages/SkylineKit/Sources/SkylineSnapshot` | `skyline-snapshot` CLI: renders compositions to SVG (headless design inspection) |
| `Mods/` | 24 community content mods (JSON only), validated by `CommunityModsTests` |
| `Documentation/` | Architecture, design, decisions, formats |
| `Website/` | Static website (www.skyline-architect.com); `Website/manual/` is generated from `SkylineContent/Resources/Manual` by `skyline-website` |
| `Development/` | STATUS.md journal, screenshots per phase |
| `Scripts/` | Build/test/capture helpers used locally and in CI |

## Build & test

```sh
Scripts/test-package.sh            # swift test for SkylineKit (works on macOS and Linux)
Scripts/build-app.sh               # xcodebuild for macOS (+ iPad simulator with --ipad)
Scripts/capture-screenshots.sh OUT # launch app in capture mode, writes PNGs to OUT
```

CI: `.github/workflows/ci.yml` runs package tests on Linux + macOS, builds the app for
macOS and iPad Simulator, launches it in screenshot-capture mode, uploads screenshots and —
on `claude/**` branches — commits JPEG copies to `Development/Screenshots/_ci-latest/`
(`git pull` after CI to inspect them; the bot commit uses `[skip ci]`).

## Non-negotiable rules

1. Never leave the project intentionally uncompilable. Build after meaningful changes.
2. Run the tests (`Scripts/test-package.sh`) before every commit; add tests for new simulation logic.
3. Fix warnings where practical. Do not silence them with blanket flags.
4. Preserve architectural boundaries:
   - `SkylineCore` / `SkylineContent` / `SkylinePresentation` / `SkylinePersistence` must not import SpriteKit, SwiftUI, AppKit, UIKit or CoreGraphics. They must build and test on Linux.
   - The renderer never contains game rules. SpriteKit nodes are never authoritative state.
   - SwiftUI views never run the simulation.
   - Content (room types, cities, balance) lives in data files, not in engine switch statements.
5. Avoid giant files (soft limit ~400 lines). Avoid duplicated logic.
6. Never replace a finished system with a mock to make compilation succeed.
   Never silently remove functionality to fix an error.
7. Determinism: simulation code must not iterate `Dictionary`/`Set` in order-sensitive
   ways, must not use `Date()`/system randomness; use `SeededRandom` and `EntityStore`.
8. Profile before major optimization; record measurements in `Documentation/PERFORMANCE.md`.
9. After visual phases: capture real screenshots, inspect them, fix obvious issues, save
   them under `Development/Screenshots/Phase-XX/` with a README. Never fake a screenshot.
   `skyline-snapshot` SVG previews are design aids, NOT game screenshots — label them so.
10. Status vocabulary in docs: PLANNED / SCAFFOLDED / FUNCTIONAL / POLISHED. A button
    or empty protocol is not a feature. Never claim unverified work is done.
11. Keep `Development/STATUS.md` current at the end of every work session.
12. Commits: logical, conventional style (`feat(camera): …`, `fix(grid): …`, `test(core): …`,
    `docs: …`). No giant all-in-one commits.
13. Do not overengineer: build the smallest robust architecture that can evolve.
    No protocols/abstractions for hypothetical problems.
14. Debug/developer tooling must be isolated from release gameplay (`#if DEBUG` or the
    developer-mode setting), never mixed into gameplay rules.
15. Mods are declarative data only (JSON). Never execute native code from mods.
16. Construction changes the world only through `BuildCommand`s + `ConstructionEngine`;
    every command needs an exact inverse (undo) and tests.
17. Save format changes require a version bump, a migration and a kept golden fixture
    (Documentation/SAVE_FORMAT.md).
18. Versioning: every change that ships in the app bumps `MARKETING_VERSION` (patch for
    fixes and small additions) and always raises `CURRENT_PROJECT_VERSION` by 1, in both
    build configurations of `SkylineArchitect.xcodeproj`, with a matching CHANGELOG heading.
    The owner uploads builds to TestFlight and should never have to bump these by hand.

## Environment notes

- The Linux cloud container has no Xcode. Swift for Linux can be installed from the
  official `swift` Docker image layers (see `Development/STATUS.md` → Environment).
  Only the package builds there; the app target is verified by macOS CI.
- App target uses Swift 5 language mode (Apple UI frameworks); the package uses Swift 6
  strict concurrency. See DECISIONS.md D-006.
