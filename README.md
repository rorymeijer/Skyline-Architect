# Skyline Architect

An original, native vertical-building management simulation for macOS (primary) and
iPadOS. Swift · SwiftUI · SpriteKit. No third-party engines, no copied assets.

<img src="App/Assets.xcassets/AppIcon.appiconset/mac-256.png" width="128" alt="App icon: a cut-away tower at dusk">

## What the game does (0.20.3)

Build a tower in cross-section and keep it running.

| Area | What you get |
|------|--------------|
| **Construction** | Floors, rooms and shafts on a grid, with structural rules. Undo and redo. Construction costs and refunds. |
| **People** | Every resident, worker and staff member is simulated: schedules, walking and stairs, elevators with patience, route planning with sky-lobby transfers. |
| **Elevators** | Cars, banks, express shuttles, and three dispatch strategies with statistics and a traffic overlay. |
| **Tenants** | A rental market with flats for sale beside flats for rent, where prospects appraise rent, access, noise, view and services, with satisfaction and move-outs. |
| **Economy** | Ledger, rent, running costs, loans and bankruptcy. |
| **Facilities** | Utilities with a reach and a capacity, wear and dirt, and janitors and technicians. |
| **Progression** | Reputation and building classes that unlock rooms, height and tenants. |
| **Environment** | Day and night with lighting energy, and weather with seasons, forecasts and effects. |
| **Emergencies** | Fires, sprinklers, evacuation, and storm damage. |
| **Estate** | Three cities with their own markets, ground and weather, land for sale, and the whole estate simulating at once. |
| **Scenarios** | Objectives against the clock, from Opening Day to Skyline. |
| **Modding** | JSON content packs over the base game, validated per mod, with a mod manager and an example mod. |
| **Saves** | Versioned format (14) with migrations and golden fixtures, a content hash per pack; optional iCloud Drive sync that keeps both versions on a conflict. |
| **Scale** | Profiled on generated towers up to 400 floors and 2,000+ people. |
| **Polish** | Procedural art throughout, clouds, the app icon, VoiceOver labels and Reduce Motion. |

**Honest status.** Every system above is implemented, tested and seen working in automated
captures. The following have not been done or verified:

* no human play test;
* the iPad build never launched;
* iCloud needs a signing team;
* balancing is first-pass.

See [Development/STATUS.md](Development/STATUS.md).

## Build and run

- **Play:** open `SkylineArchitect.xcodeproj` in Xcode 16+ and run the `SkylineArchitect` scheme (My Mac).
- **Test** the engine: `Scripts/test-package.sh` (also runs on Linux, 300+ tests).
- **Profile:** `cd Packages/SkylineKit && swift run -c release skyline-bench --zones 10 --width 64`.
- **Regenerate the icon:** `Scripts/make-icon.sh`.

## Where to read next

- `CLAUDE.md` — development rules.
- `Documentation/ARCHITECTURE.md` — module boundaries.
- `Documentation/DECISIONS.md` — why things are the way they are.
- `Documentation/OPEN_ITEMS.md` — everything still open, in one checklist.
- One document per system in `Documentation/` (SIMULATION, ELEVATORS, TENANTS, ECONOMY, FACILITIES, PROGRESSION, LIGHTING, WEATHER, EMERGENCIES, ESTATE, SCENARIOS, MODDING, SAVE_FORMAT, PERFORMANCE, GRAPHICS, ACCESSIBILITY).
- `Development/Screenshots/Phase-XX/` — real captures of every phase, with notes.
