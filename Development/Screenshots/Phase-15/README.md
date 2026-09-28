# Phase 15 — Screenshots (multiple properties & cities)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36392926388 on a GitHub Actions `macos-15` runner (commit eeb5658).
* **Build:** Skyline Architect **0.15.0 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the scenes were set up.** The script buys land through the same `Estate.buy` path as
the Buy button. It builds the demo tower in each new city with the **developer blueprint
tool**, which grants the cash it needs first. The Harrowgate purchase is funded by a
$2.5M loan taken by the script. Leasing, rents and the 24-hour figures are the
simulation's own. The notes in `capture-report.json` say which steps were scripted.

| File | Demonstrates |
|------|--------------|
| `01-home-estate.jpg` | Day 1, 11:00: the estate panel (⌥⌘K) with one property and **land for sale** in three cities: Ferry Lane Corner $900k, Crown Yard $2.4M, Harbour Row $450k. The 24 h figure still includes the day's construction. |
| `02-bought-saltmere.jpg` | Bought Harbour Row, Saltmere: cash $1,418,700 → $968,700. The view moves to a new street, a smaller skyline and marsh ground with long piles. |
| `03-saltmere-tower.jpg` | The demo tower in Saltmere, built at **×0.8** construction prices (telecom room $11,520 instead of $14,400). |
| `04-bought-harrowgate.jpg` | After a $2.5M loan: bought Crown Yard, Harrowgate. Granite lies just under the street; the plot has two basement levels. |
| `05-harrowgate-tower.jpg` | The demo tower in Harrowgate at **×1.25** prices (telecom room $18,000). The economy panel shows the land line (−$2,850,000 total) and the loans. Cash is $0 after the developer grant. |
| `06-estate-overview.jpg` | Day 4, 10:00: *3 properties in 3 cities*. Every tower is 15/15 let, each by its own city market. Last 24 h: Port Calder $43,689, Saltmere $32,280, Harrowgate $59,671. Crown Yard was promoted to class B (banner). |
| `07-back-home.jpg` | *Go* back to Quay Street Lot; the other towers kept running meanwhile. |
| `08-save-load.jpg` | Saved and reloaded the whole estate: `worldIdentical=true`, 3 properties. |

## Inspection notes

* **First runs** had two problems, both fixed and recaptured:
  * Crown Yard was too narrow for the demo tower. Its frontage is now 44 m with a 32 m footprint.
  * The developer blueprint grant priced every command against the unbuilt world, so it
    granted too little and the Harrowgate tower stopped halfway. The grant now prices each
    step on a copy of the world (commit eeb5658).
* The 24-hour figure counts only money booked to a building; loans, interest and land are
  estate-level (see ESTATE.md → Limits).
* **Programmer art:** the city skylines are the procedural Phase 1 skyline with each city's seed.
