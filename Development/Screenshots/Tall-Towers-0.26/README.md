# 500 floors — 0.26.0 (F2)

Real in-game captures from the macOS app (**Debug build**), taken by CI run 36541308032
(`--capture-screenshots`, GitHub `macos-15` runner, 1024 × 681 pt).

How the script set up the game:
- It loads the 526-floor stress tower with the developer tool (*Developer: Load Stress
  Tower (526 floors)*): 25 zones, 1 429 rooms, 2 850 people, 74 cars, every unit let. It is
  not a tower a player built.
- It advances time explicitly (paused game). The HUD's "Simulation … ms/frame" in captures
  01, 02, 04 and 05 is that one large jump (4 or 12 game hours in a Debug build), not a
  frame.

| File | What it shows |
|------|---------------|
| `01-526-floors.jpg` | The base of the tower at 10:00 with the developer HUD. Loading, including warming the route cache and building the scene, took 6.1 s in the Debug build. |
| `02-whole-tower.jpg` | All 526 floors by day at the camera's furthest zoom (0.35 pt/m); the tower is taller than the window. |
| `03-mid-tower.jpg` | Floors ~255–270 at 10:04: offices with their tenants and people, the elevator shafts. The last 240-tick step took 2.9 ms (Debug). |
| `04-night-whole.jpg` | 22:00, zoomed out: lit homes as one strip per storey (new in F2); the offices are dark. |
| `05-night-panes.jpg` | 22:00, the upper zones at 3 pt/m: individual window panes, as before. |

What was checked in the captures:
- All five captures settled, at 44–45 fps (Debug, CI runner).
- Route planning reports 0 failures and 0 unreachable people.
- The strips and the panes line up with the storeys.

Not shown: Release-build timings. Those come from `skyline-bench` (PERFORMANCE.md → F2).
