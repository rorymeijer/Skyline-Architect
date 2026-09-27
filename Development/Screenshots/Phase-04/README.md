# Phase 4 — Screenshots (basic people simulation)

**Real screenshots of the running game** from the Debug build's screenshot director on a
GitHub Actions `macos-15` runner — CI run 36328915766, commit `35bab60`, Skyline Architect
**0.4.0 (1)**, Debug, 1024 × 681 pt @1×, JPEG copies. The game is paused during captures;
the director advances the simulation by exact tick counts, and finds busy moments by
looking ahead on a *copy* of the world (the real world only moves forward in time).

| File | Demonstrates |
|------|--------------|
| `01-morning-arrivals.jpg` | Busiest moment of the 07:40–09:20 rush (07:58): people on the stairwell, residents at home, first workers at their offices; HUD shows 14 drawn / 38 simulated, simulation 0.25 ms/frame. |
| `02-stairs-closeup.jpg` | A resident on the stairwell mid-flight (48 pt/m), found automatically; workers at their offices. |
| `03-offices-occupied.jpg` | 10:00: all 24 workers at their workplaces (4-frame figures, business attire, varied looks). |
| `04-lunch-exodus.jpg` | Busiest moment of 11:50–12:40: people leaving for lunch. |
| `05-evening-home.jpg` | 20:30: residents home in their apartments (casual clothing), offices empty. |
| `06-far-zoom-lod.jpg` | Day 2 at massing zoom: façade LOD, people still simulated (38) but not drawn (render LOD). |
| `07-save-load-roundtrip.jpg` | Save → load with 38 people and trips in progress: `worldIdentical=true`. |

## Measurements (`capture-report.json`)

| Capture | Zoom / LOD | Tiles shown / cached | Raster ms/tile | FPS | Scene update ms | Nodes | People drawn | Memory MB |
|---|---|---|---|---|---|---|---|---|
| 01 | 10.4 Floors | 15 / 15 | 11.4 | 59 | 0.26 | 135 | 14 | 136 |
| 02 | 48 Interior | 12 / 27 | 12.7 | 60 | 0.22 | 182 | 4 | 167 |
| 03 | 38 Interior | 9 / 36 | 13.8 | 60 | 0.20 | 206 | 19 | 167 |
| 04 | 14 Rooms | 9 / 36 | 13.8 | 60 | 0.25 | 211 | 24 | 167 |
| 05 | 38 Rooms | 9 / 39 | 13.0 | 60 | 0.35 | 200 | 10 | 171 |
| 06 | 3.2 Massing | 8 / 47 | 11.5 | 60 | 0.14 | 198 | 0 | 188 |
| 07 | 3.2 Massing | 8 / 8 | 5.5 | 60 | 0.11 | 27 | 0 | 145 |

## Inspection notes — issues found and fixed

1. First capture run: the morning/lunch/stairs captures showed nobody moving — trips last
   1–2 minutes while arrivals spread over 80 minutes, so on average fewer than one person
   travels at any instant and the fixed "wait for 3 travellers" loop timed out. Fixed by the
   look-ahead search for the busiest moment (the simulation itself was correct).
2. `ARCHITECTURE.md` still labelled the simulation module as planned → updated.

## Known visual limitations

- People **stand** in rooms at personal spots; they do not yet sit at desks, lie in beds or
  interact with furniture (animation states in ASSET_REQUIREMENTS §1).
- Figures are programmer art; no idle animation.
- Only stairs connect floors; elevator shafts have no cars yet (Phase 6), so upper floors
  are slow to reach — which is exactly the pressure elevators will relieve.
- Arrivals come from the left sidewalk only; no street, cars or transit yet.
