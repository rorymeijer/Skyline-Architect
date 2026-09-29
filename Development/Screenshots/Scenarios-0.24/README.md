# Scenarios — 0.24.0 (Phase C)

Real in-game captures from the macOS app, taken by CI run 36527125766 (`--capture-screenshots`).

How the script set up the game:
- It starts Opening Day through the scenario model's own call.
- It builds the demo tower and leases every unit with the developer tools. The developer
  blueprint also grants the build costs.
- The simulation decided the result, and the record was written by the app's own code.

| File | What it shows |
|------|---------------|
| `01-news.jpg` | Opening Day, day 1 10:00. The objectives panel shows the first scripted news line. |
| `02-result.jpg` | The closing decided it: won on day 2 with 3 stars and 1885 points, flagged "new best!". |
| `03-browser-record.jpg` | The scenario browser. Opening Day shows its record: 3 stars, best 1885 points, 1 of 1 won. |
| `04-browser-rules.jpg` | The new Lean Tower scenario, with its rules (no Studio Apartment, floors up to 12, fixed rents, no staff) and 2 scripted events. |
| `05-lean-tower.jpg` | Lean Tower. The demo tower's blueprint stops at the first apartment ("Not allowed in this scenario"). The palette shows the apartment locked, and the economy panel shows the rent as "fixed by the scenario". |

What was checked in the captures:
- The stars and points are readable.
- The record matches the result.
- The rules show in the browser, the panel and the palette.
