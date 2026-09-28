# 0.21.0 — Screenshots (Phase A: extending foundations)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36478216982 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.20.4 (1)** (built before the 0.21.0 version bump), Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the scenes were set up.** The script builds the demo tower in the sandbox, leases it
with the developer tools and sets the weather to clear. It then presses the foundation
panel's buttons (`model.perform` with the panel's own commands).

| File | Demonstrates |
|------|--------------|
| `01-foundation-panel.jpg` | The Foundation panel: 32 m wide, 1 of 3 basement levels, 20 m piles carrying 40 storeys (9 built). Each button shows its price. |
| `02-widened.jpg` | Widen Left and Widen Right pressed: 40 m wide, with a wider raft and an extra pile on each side. |
| `03-deeper-and-piles.jpg` | A basement level dug (B2, empty) and the piles lengthened twice to 30 m, now carrying 60 storeys. The drawn ground section goes deeper with them. |
| `04-palette-icons.jpg` | The build palette with the new Foundation button and icons for Electrical (bolt), Telecom (antenna) and Express Elevator. At 1024 pt the palette is too wide for labels, so it shows icons only; labels return in wider windows. |
