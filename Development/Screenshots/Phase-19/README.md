# Phase 19 — Screenshots (large-scale performance)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36423606533 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.19.0 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.
* **Diagnostics:** the developer HUD is on. `capture-report.json` holds each capture's render
  diagnostics, including the new per-section split of the scene update (`sceneSections`).

**How the scenes were set up.**

* The towers come from the **developer stress-tower tool**: every unit is let at once, and
  $1 billion is granted for the construction.
* Everything after that is the simulation's own. That includes the **fire** in a studio on
  floor 66 and the **promotion to class B**; their banners appear in 02, 03 and 05.
* The HUD's "Simulation ms/frame" shows the last `advance` call. In these captures that call
  simulated hours or a whole day at once, so the notes give the honest meaning.

| File | Demonstrates | fps | Scene update |
|------|--------------|----:|-------------:|
| `01-stress-overview.jpg` | 211 floors, 576 rooms, 1 140 people, 29 cars at 0.75 pt/m (the whole tower). | 57 | 0.32 ms |
| `02-morning-rush.jpg` | Day 3, 08:20: sky lobby 21 and zone 2 at rush hour. 24 cars riding and 26 people waiting; one game day took 8.0 s to simulate in this Debug build (0.72 s release). | 57 | 0.78 ms |
| `03-sky-lobby.jpg` | Close-up of the sky lobby, the plant floor and the zone's offices (24 pt/m). | 56 | 0.75 ms |
| `04-upper-zones.jpg` | Floors 170–210 at 3 pt/m, façade level of detail. | 52 | 0.24 ms |
| `05-night.jpg` | 22:00: lit homes (studio zones) and dark offices over 211 floors; 1 845 nodes for the window panes. | 48 | 5.2 ms |
| `06-400-floors.jpg` | **400 floors**, 1 084 rooms, 2 166 people, 56 cars; the whole 1.6 km tower at 0.4 pt/m. | 49 | 0.59 ms |
| `07-save-load.jpg` | The 400-floor tower saved (42 ms) and reloaded (0.76 s incl. scene rebuild): `worldIdentical=true`. | 47 | 0.83 ms |

## Inspection notes (four CI runs)

1. **First run: 32–42 fps, with a scene update of 3–12 ms** that grew with the building.
   * The 4 Hz panel refresh made four utility allocations per building, and the services
     overlay one per frame. Now one allocation is shared per refresh: 52–57 fps at 211
     floors.
2. **A per-section timing** was added to the diagnostics to find the rest. The *weather*
   section took 11 ms at 400 floors: snow roofs looked up each floor's upper plate by linear
   search, every frame, even without snow. Now it is linear and runs only under snow, and
   the scene update dropped to 0.6–1.3 ms.
3. **Camera:** the first 01 and 06 captures showed the default preset instead of the
   whole-tower view, because a freshly built scene applies its placement when presented.
   Fixed with `initialPlacement`.
4. **The remaining cost** is the night window panes (a 4.6 ms "light" section), noted in
   PERFORMANCE.md.
