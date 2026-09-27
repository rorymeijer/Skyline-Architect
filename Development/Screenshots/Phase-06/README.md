# Phase 6 — Screenshots (first functioning elevators)

**Real screenshots of the running game** from the Debug build's screenshot director on a
GitHub Actions `macos-15` runner — CI run 36337293798, Skyline Architect **0.6.0 (1)**
(captured just before the version bump commit), Debug, 1024 × 681 pt @1×, JPEG copies. The
game is paused during captures; the director advances the simulation by exact tick counts
and finds moments by looking ahead on a *copy* of the world.

The captures use the `demo-highrise` blueprint: the demonstration tower extended to 21
storeys (floors 9–20 are offices), with **one** elevator over the full height and the
stairwell only up to floor 8 — 98 people, one car, so the rushes form queues.

| File | Demonstrates |
|------|--------------|
| `01-morning-queues.jpg` | 08:13, whole building: people at their floors, the car in the shaft; HUD: 1 car, 4 waiting, longest wait 33 s. |
| `02-lobby-queue.jpg` | 08:26, ground-floor landing (42 pt/m): four people queuing at the elevator doors, first two at the doors, others alongside. |
| `03-doors-open-boarding.jpg` | One second-scale search later (08:27): the car stopped at G with doors open and the four inside. |
| `04-car-moving-riders.jpg` | The same car moving up with its four riders, drawn at the exact interpolated height (hoist rope above). |
| `05-elevator-routes-overlay.jpg` | 12:31 with the navigation overlay: elevator links (green) over 22 floors, stairs (orange) to floor 8, walk links (cyan), a route from the street. |
| `06-evening-down-peak.jpg` | 16:52, busiest moment of the evening: 4 waiting, longest wait 52 s. |
| `07-save-load-roundtrip.jpg` | Save → load with 98 people, the car and its state: `worldIdentical=true`. |

## Measurements (`capture-report.json`)

60 fps throughout (display cap), scene update 0.3–0.6 ms, 150–250 nodes. The HUD's
"Simulation ms/frame" in these captures is the director's last *jump* (up to 90 game
minutes in one call, e.g. 8.3 ms), not a per-frame cost. Package scale runs: see
`Documentation/PERFORMANCE.md`.

## Inspection notes

* First run (commit `b09a954`, demo tower): queues were at most one person and the
  waiting person stood on the adjacent stairwell (queue drawn beside the shaft). Fixed by
  queuing at the landing doors and adding the `demo-highrise` blueprint; recaptured.
* Riders are drawn in front of the car's (semi-transparent) doors — cutaway convention,
  like people in rooms.
* Queues stay short (≤ 4) in this building because arrivals spread over ±40 minutes; the
  60-floor scale test peaks at 21 waiting with full cars.
