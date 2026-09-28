# Phase 16 — Screenshots (scenarios)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36398839340 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.16.0 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the scenes were set up.**

* The script opens the browser and starts scenarios through the same calls as its buttons.
* It builds the demo tower with the **developer blueprint tool**.
* No developer leasing is used: every tenant signed on its city's own market.
* The results (won and lost) were decided by the simulation's daily closings.

| File | Demonstrates |
|------|--------------|
| `01-main-menu.jpg` | The main menu with the new **Scenarios…** entry. |
| `02-scenario-browser.jpg` | The browser: five scenarios with difficulty tags. Opening Day's briefing shows its setting (Quay Street, $2.5M, 10 days) and objectives. |
| `03-briefing-skyline.jpg` | The hardest scenario: population ≥ 1,500, average wait ≤ 60 s, daily profit ≥ $1, held for 7 closings in a row. |
| `04-opening-day-start.jpg` | Day 1, 11:00: Opening Day started and the demo tower built. The objectives panel (⌥⌘O, flag button) shows 4 units let and $0 profit, with 10 closings left. |
| `05-opening-day-progress.jpg` | Day 2, 16:00: 11 of 12 units let. Profit $23,765 is met; the panel measures live, but only the closings decide. |
| `06-opening-day-won.jpg` | **Scenario complete** at the day 4 closing: 15 units let, $43,672 profit. The result screen offers *Keep Playing*, *Scenarios…* and *Main Menu*. The building was also promoted to class B (banner behind). |
| `07-harbour-failed.jpg` | Harbour Revival, left unbuilt: **Scenario failed — time ran out** at the day 31 closing (30 days). |
| `08-save-load.jpg` | Crown Prestige, day 2: saved and reloaded mid-scenario (`worldIdentical=true`). The tower leased on the Harrowgate market; the average wait of 9 s is met, while class and reputation are not yet. |

## Inspection notes

* **The first run (CI run 36397657704) found a real bug:** the Harrowgate tower in 08 was
  still empty after a day. The cause was a Phase 15 bug: Harrowgate's rents (×1.35) priced
  every class C tenant out. Tenant budgets now follow the city's rent level, and a test
  checks that the Saltmere and Harrowgate towers find tenants on their own markets.
* **Also fixed after that run:**
  * the browser stretched to the full window height;
  * the title badge ran under the clock;
  * counts showed without thousands separators ("1500");
  * the main menu's New Game subtitle was cut off.
* **08 framing:** reloading restores the saved camera, so the capture's camera move does not
  apply and the tower's top is cut off. The subject, the objectives panel after the reload,
  is fully visible.
