# Phase 7 — Screenshots (advanced elevator queues & dispatch)

**Real screenshots of the running game** from the Debug build's screenshot director on a
GitHub Actions `macos-15` runner — CI run 36339081561, Skyline Architect **0.7.0 (1)**,
Debug, 1024 × 681 pt @1×, JPEG copies. The game is paused during captures; the director
advances the simulation by exact tick counts and finds moments by looking ahead on a copy
of the world. Strategy changes go through the same model call as the panel's buttons.

Building: the `demo-skytower` blueprint — 42 storeys, 175 office workers. **Bank A**: three
elevators B1–20. **Bank B**: express shuttle G ↔ 21 (stops only at its ends). **Bank C**: two
elevators 21–40. Sky lobby on floor 21; stairs over the full height.

| File | Demonstrates |
|------|--------------|
| `01-skytower-traffic.jpg` | 08:30, whole tower at façade zoom with the **traffic overlay**: bank labels (strategy, average wait; stacked so they never overlap, kept below the top bar) and queue badges at the ground floor. |
| `02-bank-panel.jpg` | The **Elevator Banks panel**: bank A switched to *zoning* 20 minutes earlier; per-bank average/max wait, passengers in the last hour, boardings, stops, abandonments, waiting now. The express (1 car) has no strategy choice. |
| `03-sky-lobby-transfer.jpg` | Day 2, 07:56: a person who came up on the express walks across the floor-21 sky lobby level to the upper bank (overlay off — the plain game view). |
| `04-lobby-queues.jpg` | 08:07, ground floor: queues at a bank-A car and at the express, badges `2 · 31s` (amber) and `2 · 15s` (green); car loads above the cabs. |
| `05-evening-down-peak.jpg` | 17:02, busiest moment of the evening with the developer HUD: 6 waiting, longest wait 26 s. |
| `06-bank-statistics.jpg` | 18:05: statistics since the start — A 576 boardings avg 22 s (max 92 s), B 760 avg 19 s, C 720 avg 24 s; 46 / 69 / 68 passengers in the hour 17–18; nobody took the stairs. |
| `07-save-load-roundtrip.jpg` | Save → load with 175 people, six cars, strategies and statistics: `worldIdentical=true`. |

## Inspection notes

* First run (CI run 36338553711): bank labels A and B overlapped, label C sat under
  the clock bar, car-load badges piled up at far zoom, and the sky-lobby shot caught the
  person still inside the express cab with a label over them. Fixed (label stacking and
  clamping, loads only from 8 pt/m, mid-walk moment, overlay off for the close-up);
  recaptured.
* At façade zoom the overlay shows badges over the glass façade (cabs are not drawn there).
* With realistic arrival spread the three strategies give very similar waits in this
  building (see ELEVATORS.md → Measured); the panel makes the difference inspectable
  rather than dramatic.
