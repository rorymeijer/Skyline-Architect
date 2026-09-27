# Phase 5 — Screenshots (navigation / pathfinding)

**Real screenshots of the running game** from the Debug build's screenshot director on a
GitHub Actions `macos-15` runner — CI run 36332717554, Skyline Architect **0.5.0 (1)**,
Debug, 1024 × 681 pt @1×, JPEG copies. The game is paused during captures; the director
advances the simulation by exact tick counts and finds interesting moments by looking ahead
on a *copy* of the world. All construction goes through the normal command path
(`AppModel.perform`), so re-planning happens exactly as for a player.

The coloured lines are the **developer navigation overlay** (⌥⌘N, Debug builds only):
yellow dots = portals (stair landings), orange = stair links, cyan = walk links between
portals on a floor (transfers), pink = the remaining route of each traveller.

| File | Demonstrates |
|------|--------------|
| `01-navigation-graph.jpg` | Demo tower at 07:58 with the overlay: 10 portals, 18 links, live routes from the street through the entrance and up the stairwell. HUD shows path queries, cache rate, graph builds, unreachable count. |
| `02-transfer-routes.jpg` | Floors 9–12 added and served only by a second stairwell starting on floor 8: two routes climb the lower stairs, cross floor 8 (cyan transfer link) and continue up the upper stairwell. |
| `03-transfer-closeup.jpg` | Close-up at floor 8 during the morning (40 pt/m): a person at the transfer floor between the two stairwells (both visible). Overlay off — the normal game view. |
| `04-replanned-after-rebuild.jpg` | A new stairwell is placed on the far (left) side, then the upper stairwell is demolished while a trip uses it: that trip is re-planned from where the person is — the pink route now turns left along floor 8 to the new shaft. The old shaft's column is empty. |
| `05-unreachable-floors.jpg` | The replacement is demolished too: floors 9–12 have no stairs. 5 people are unreachable (stuck upstairs or unable to reach their room), 5 failed path queries, graph rebuilt 9 times across the session (once per structural change). |
| `06-save-load-roundtrip.jpg` | Save → load after all this with 46 people: `worldIdentical=true` (the route cache is not saved and not needed). |

## Measurements (`capture-report.json`)

60 fps throughout (display cap), scene update 0.3–0.4 ms, simulation 0.03–1.8 ms per
captured frame for 46 people (the 1.8 ms frame includes a ¾-hour jump by the director).
Package scale test: see `Documentation/PERFORMANCE.md` (200 floors, 1 194 people, one day
at 10× in 68 ms, release).

## Inspection notes

* First run (commit `6d13269`): the HUD hid the new stairwell in 04 and the title badge
  still said "Phase 4 preview"; 04 counted only people *on* the old shaft. Fixed framing,
  badge and the scenario metric; recaptured.
* Walking across a floor ignores interior partitions (people pass through the elevator
  shaft zone on the transfer floor) — walls are derived art (D-014, D-023). Recorded as a
  known issue.
* Only one trip is affected at the moment of the rebuild in 04 (the upper floors hold 10
  people); larger re-planning cases are covered by `ReplanningTests`.
