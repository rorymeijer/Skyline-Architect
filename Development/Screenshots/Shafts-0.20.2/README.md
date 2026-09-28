# 0.20.2 — Screenshots (shafts over rooms, shaft heights, unique names)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36457150047 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.20.1 (1)** (built before the 0.20.2 version bump), Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the scenes were set up.**

* The script builds the demo tower in the sandbox and leases it with the developer tools.
* It **sets** the weather to clear.
* Every construction goes through `AppModel.perform`, the same path as a click on the
  canvas or a button in the inspector.

| File | Demonstrates |
|------|--------------|
| `01-unique-names.jpg` | 15 tenants with 15 different names; household labels on the upper floors. |
| `02-shaft-selected.jpg` | The elevator shaft selected (B1–8). The inspector shows its height controls: Extend Up needs a floor 9 first; shortening refunds $5,400 per floor. |
| `03-shaft-extended.jpg` | A ninth storey is built, then Extend Up is pressed: the shaft now reaches floor 9, with the same car. |
| `04-stairs-through-rooms.jpg` | A second stairwell placed over B1–G. The Mechanical Room narrows from 8 to 4 modules and the Lobby from 13 to 9. |
| `05-undo.jpg` | Undo: the stairwell is gone and both rooms are back at full width. |
