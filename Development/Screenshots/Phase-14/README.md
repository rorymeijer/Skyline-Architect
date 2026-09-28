# Phase 14 — Screenshots (events & emergencies)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36388937901 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.14.0 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the scenes were set up.** Some starting conditions were set by the script. Everything
that follows from them is the simulation's own behaviour.

* The fires were **started with the developer tool** (`igniteForTesting`). Real ignitions
  are rare, about 1.5 per 1,000 rooms per day.
* The storm in 08 was **set** by the script. The storm damage itself was drawn by the game,
  after 98 stormy game hours.

The notes in `capture-report.json` say which conditions were set.

| File | Demonstrates |
|------|--------------|
| `01-ignition.jpg` | 10:30: a fire starts in an office on floor 2 (glow at floor level). The alert names it: "brigade in 16 min, building evacuated", with **Show**. |
| `02-evacuation.jpg` | 80 s later, **everyone takes the stairs down**. The elevators stand empty (no rides during a fire). 24 people are still inside or on their way out. |
| `03-spreading.jpg` | 10:43: the building is empty and smoke fills the office. |
| `04-fire-brigade.jpg` | 10:48: the **fire engine** is at the kerb, and 2 rooms are burning. |
| `05-aftermath.jpg` | 11:16: the fire went out after 45 min, having damaged 3 rooms. **One tenant was lost** (the unit is now *Vacant* and shows **soot**). Repairs cost $19,800, and reputation fell 50 → 42. The incidents panel (⌥⌘I) records it all. |
| `06-sprinklers.jpg` | 14:02: a **fire control room** was built on floor 9, covering all 39 rooms. A second fire burns under **sprinkler spray**, with evacuees on the stairs. |
| `07-sprinklers-win.jpg` | Sprinklers put that fire out in 4 min: 1 room damaged, $9,900. Close-up of the fire control room (valve set, alarm panel, pump). |
| `08-storm-damage.jpg` | Day 5 (storm set): **storm damage** to the corridor on floor 2. The alert and the incidents panel show it; a repair job was opened. The tower was also promoted to class B in the meantime (second banner). |
| `09-save-load.jpg` | Saved and reloaded **while a fire burns**: `worldIdentical=true`, 1 fire in progress. |

## Inspection notes

* **First run (CI run 36388614468)** had three problems, all fixed and recaptured:
  * The evacuation shot was taken after the building had already emptied, so nobody was on the stairs.
  * No storm damage occurred within 18 game hours; the script now waits hour by hour.
  * The save happened after the second fire was already out.
* **The app build before that (CI run 36387241168) failed** on a missing import after the view commands moved to their own file. Fixed.
* **Programmer art:** flames and smoke are gradients, the spray is a streak texture, and the fire engine is simple shapes.
