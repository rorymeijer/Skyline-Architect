# Phase 11 — Screenshots (progression / reputation)

**Real screenshots of the running game**, taken by the screenshot director in the Debug build.

* **Source:** CI run 36347268108 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.11.0 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.
* **Script:** the director starts a *standard* game from the main menu, then drives the same model calls as the menus. It builds the demo tower (developer blueprint, with a grant), advances time and builds floors through the undo history.

`capture-report.json` holds the numbers behind each caption.

| File | Demonstrates |
|------|--------------|
| `01-main-menu.jpg` | Main menu: **New Game** (standard, unlocks by building class) and **New Sandbox** (everything unlocked). |
| `02-standard-start.jpg` | Standard game on the empty lot. The Standing panel (⌥⌘P) shows Class C at reputation 50, a height limit of floor 12, and the Class B requirements and unlocks. In the build palette, sky lobby, express elevator and service elevator are **locked** (dimmed, padlock). |
| `03-class-c-tower.jpg` | Demo tower built in class C: population 0/35, reputation 50/55, elevator ✓. |
| `04-first-tenants.jpg` | Day 3, 10:00. 13 of 15 units let and reputation 65; every Class B requirement is met, and promotion follows at the next closing. |
| `05-promotion.jpg` | Day 4. **Promotion banner**: *"Quay Street Lot is now Class B — unlocked: Service Elevator, Design studio tenants, Single professional tenants, Floors up to 25"*. The service elevator tool is unlocked, and the panel now shows the Class A requirements. |
| `06-taller-than-class-c.jpg` | Floors 9–13 built after the promotion. Floor 13 would have been refused in class C; the limit is now floor 25. |
| `07-reputation-falls.jpg` | The electrical room is demolished, cutting power. After 5 days all 15 tenants have moved out (every unit *Vacant*) and reputation fell from 71 to 50. The building **stays Class B**. |
| `08-save-load-roundtrip.jpg` | Save and reload: `worldIdentical=true`, Class B at reputation 50. |

## Inspection notes

**First run (CI run 36346853287)** showed two problems, both fixed and recaptured:

* The promotion banner under the clock overlapped the Standing panel's header. It now sits above the status pill.
* The reputation-fall step raised the rent level to 1.6, but reputation *rose* (71 → 76) with no move-outs. The rent level only changes asking rents, and the existing tenants stayed content. That step now cuts the power instead, which shows a real fall.

**Where an emptied building settles:** `07` shows the building at about 50. With no tenants left, satisfaction counts as neutral (0.5), and the move-out penalty only applies on the day tenants leave. This is recorded as a balancing issue in STATUS.md.
