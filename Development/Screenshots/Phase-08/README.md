# Phase 8 — Screenshots (tenants + schedules)

**Real screenshots of the running game** from the Debug build's screenshot director on a
GitHub Actions `macos-15` runner — CI run 36341716790, Skyline Architect **0.8.0 (1)**,
Debug, 1024 × 681 pt @1×, JPEG copies. The game is paused during captures; the director
advances the simulation by exact tick counts. Rooms are selected through the same model
call a click makes.

Building: the demo tower (8 offices, 7 studios), built at 06:00 on day 1 — **empty**: every
tenant arrives through the rental market.

| File | Demonstrates |
|------|--------------|
| `01-vacant-tower.jpg` | Day 1, 06:00: all 15 rentable units labelled *Vacant*; Leasing panel 0 of 15, nobody inside. |
| `02-first-tenants.jpg` | Day 1, 20:00: 12 of 15 let after 13 prospects; tenant names replace the labels where they fit; rent roll $33,599/month (not yet charged). |
| `03-inspector-tenant.jpg` | Inspector for *Quayside Analytics* (call centre, 4 people, $3,838/month): satisfaction and the unit's criteria — rent (red: close to their budget), access 42 s, quiet, view (low floor). Selection outlined in yellow. |
| `04-inspector-vacant.jpg` | The least attractive vacant office (floor 3): consultancy would sign (68 %), design studio declines for the view, call centre finds it too expensive. |
| `05-mixed-schedules.jpg` | Day 3, 07:22 with the HUD: call centres, consultancies, a design studio, retired couples and single professionals — different schedules spread the morning. |
| `06-leasing-week.jpg` | Day 7, 09:00: 15 of 15 let, 7 households / 8 businesses, average satisfaction 70 %; 99 prospects, 15 signed, 73 no vacancy, 5 too expensive, 6 poor view; recent market log. |
| `07-save-load-roundtrip.jpg` | Save → load with tenants and market: `worldIdentical=true`. |

## Inspection notes

* First run (CI run 36341366224): *"Small Office · vacant"* labels were too long to fit at
  this zoom and never showed; once the tower was full, the market log filled with "no
  vacancy". Fixed (label *Vacant*; no-vacancy declines counted but not logged); recaptured.
* Long tenant names (e.g. "Quayside Analytics") only appear when zoomed in far enough —
  the label rule (fit inside the room) is unchanged.
* The demo tower fills within about a day; market balance is revisited with the economy.
