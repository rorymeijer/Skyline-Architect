# 0.20.1 — Screenshots (known-bug fixes)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36445406112 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.20.1 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the scenes were set up.**

* The script builds the demo tower in the sandbox and leases it with the developer tools.
* It **sets** the weather of the city on view where the notes say so (clear, rain).
* It **grants** $1,000,000 before buying the Saltmere plot (03); the grant shows as estate money.
* Panels are opened through the same toggles as their buttons.
* Saltmere's rain in 03 is its own drawn weather, not set by the script.

| File | Demonstrates |
|------|--------------|
| `01-skyline-street.jpg` | **B2:** the skyline preset framed above the build bar; the street and the tower stay visible. |
| `02-panel-tabs.jpg` | **B1:** six panels open. They do not fit, so the Estate panel shows in full and the others are tabs above it. |
| `03-estate-two-cities.jpg` | **B3, B6:** Port Calder is clear at 21° while Saltmere rains. The overview shows the last 24 h as buildings (−$1,081,300: the tower's construction) plus estate money ($3,050,000: starting capital, developer grants, minus the land). |
| `04-rain-close.jpg` | **B7:** rain at 32 pt/m, with large, fast drops. |
| `05-rain-far.jpg` | **B7:** the same rain at 0.9 pt/m, with small, dense and faint drops. |
| `06-city-evening.jpg` | **B8:** 21:30, all city windows lit. |
| `07-city-small-hours.jpg` | **B8:** 03:00, 40 % of the city's windows showing and the street lamps at full strength. |

**Inspection.** In the first run the estate capture was taken two days after the purchase,
so the estate money read $0. The script now captures at 17:00 on the day of the purchase.
