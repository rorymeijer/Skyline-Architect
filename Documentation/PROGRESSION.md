# Progression — Reputation, Building Classes and Unlocks

Status: **FUNCTIONAL (Phase 11)**. Implemented:

* reputation per building, assessed daily;
* building classes with requirements and one-way promotion;
* room-type and height unlocks by class in the standard game;
* premium tenant types gated by class;
* reputation-driven demand;
* a standing panel, a promotion banner and locked build tools.

**PLANNED:**

* scenario goals and win conditions (Phase 16);
* city-wide reputation across several properties (Phase 15);
* events that hit reputation (Phase 14).

Code:

* Core: `SkylineCore/Standing.swift` (`Standing`, `BuildingClass`, `UnlockMode`).
* Construction gating: `ConstructionEngine` (`ConstructionError.locked`).
* Simulation: `SkylineSimulation/Progression.swift` (assessment, requirements, daily step, demand) and `ProgressionReports.swift` (UI summary).
* Content: `progression.json`, `unlockClass` in `rooms.json`, `minClass` in `tenants.json`, `mode` in `starts.json`.
* App: `ProgressionViews.swift`.

## Game modes

A start's `mode` sets the world's `unlocks`:

| Start | Mode | Unlocks |
|-------|------|---------|
| New Game — Quay Street | `standard` | Room types and height open up with the building's class. |
| New Sandbox | `sandbox` | Everything is available. Class and reputation are still tracked and shown. |

Saves from before format 8 load as sandbox games, since they were built without locks.

## Reputation (0…100)

Every building starts at 50. At the 06:00 closing, after the tenant reviews, reputation moves
`dailyAdjustment` (0.3) of the way toward the day's **assessment**:

```
assessment = 100 × weighted mean of
  satisfaction   average tenant satisfaction (0.5 without tenants)      weight 0.45
  services       average services level of the rentable units             0.20
  waits          1 at ≤ 30 s average elevator wait, 0 at ≥ 150 s          0.15
                 (banks with ≥ 10 boardings; 1 without elevators)
  occupancy      leased share of the rentable units                        0.20
  − 5 points per tenant that moved out that morning
```

Reputation acts on the whole rental market. Prospects per day of every tenant type are
multiplied by a factor that runs linearly from 0.5 at reputation 0 to 1.5 at 100, using the
average over buildings with rentable units. A good building therefore fills faster, and a
building that drives tenants away finds it harder to replace them.

## Building classes

Classes are ordered in `progression.json`. Every building starts in the first class. At
each closing, a building that meets **all** requirements of the next class is promoted:

| Class | Population | Reputation | Required rooms | Build up to | Unlocks (standard game) |
|-------|-----------:|-----------:|----------------|-------------|-------------------------|
| Class C | — | — | — | floor 12 | lobby, corridor, stairs, elevator, offices, apartments, plant, parking |
| Class B | 35 | 55 | elevator | floor 25 | service elevator; design-studio and single-professional tenants |
| Class A | 150 | 65 | service elevator, telecom room | floor 45 | express elevator, sky lobby; consultancy tenants |
| Prime | 400 | 75 | express elevator, sky lobby | no limit | — (top class) |

Rules:

* **Population** counts tenant members (residents and workers), not staff.
* A building rises at most one class per day and **never drops** (D-036). A falling
  reputation costs demand, not unlocks.
* Height limits are checked when a floor is built. Room unlocks are checked when a room is
  placed. Undo and redo use restore commands and are never blocked.
* Tenant types with `minClass` do not come by at all until some building has reached that
  class. After that they only consider units in such buildings.
* The equipment Phase 10 made necessary (electrical and telecom rooms) is available from
  the start, so a class C building can supply every utility.

The demo tower fills through the market and reaches class B on its third morning
(`anEmptyTowerEarnsClassBByPlaying`). If its electrical room is then demolished, all 15 tenants move out
within five days. Reputation falls from 75 to 50, but the building stays class B
(`aPowerCutCostsReputationNotTheClass`).

## UI

* **Standing panel** (⌥⌘P, rosette button): class, a reputation bar, today's assessment by
  component, the next class's requirements with ✓/○, and what it unlocks.
* **Status pill**: class and reputation next to the cash.
* **Build palette**: locked tools are dimmed with a lock. Their tooltip names the class
  that unlocks them.
* **Promotion banner** below the clock: *"Quay Street Lot is now Class B — unlocked: …"*.
* **Main menu**: *New Game* (standard) and *New Sandbox*. File ▸ New Game (⌘N) starts a
  standard game, and File ▸ New Sandbox Game a sandbox.

## Modding

`progression.json` is validated at load:

* the first class has no requirements;
* required rooms exist;
* `maxFloor` never decreases, and once a class has no limit the later ones have none either;
* the reputation parameters are in range;
* every `unlockClass` / `minClass` names an existing class.
