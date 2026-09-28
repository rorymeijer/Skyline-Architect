# Phase 20 — Screenshots (visual polish)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36435317412 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.20.0 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the scenes were set up.**

* The script builds the demo tower in the sandbox and leases it with the developer tools.
* It **sets** the weather for 02–04: clear, then overcast, then clear.
* The promotion banner is the simulation's own.
* `app-icon-512.png` is **not a screenshot**. It is the generated icon asset (`IconArt` via
  `Scripts/make-icon.sh`), copied here for review.

| File | Demonstrates |
|------|--------------|
| `app-icon-512.png` | The macOS app icon: a cut-away tower at dusk (homes lit warm, offices cool, an elevator car, the sky lobby band), the foundation and the blueprint grid, on a rounded plate. |
| `01-main-menu.jpg` | The main menu over the live city; clouds behind the skyline. |
| `02-clouds-fair.jpg` | Clear day (set): a few fair-weather clouds. |
| `03-clouds-overcast.jpg` | Overcast (set), 30 game minutes later: nine denser clouds in view, drifted east. |
| `04-dusk.jpg` | 19:30: clouds dim with the light. |
| `05-panels.jpg` | The economy panel in the shared card style (hairline edge, named close button), now five recent lines. |
| `06-inspector.jpg` | The unit inspector and facilities panel in the same style, a close-up at 22 pt/m. |
| `07-night.jpg` | 22:00: clouds as dark shapes against the night sky. |

## Inspection notes (three CI runs)

* **First run:**
  * The clouds were too sparse and too faint to read. Fixed: the field is twice as dense,
    the clouds sit lower and are more opaque.
  * The economy panel together with another panel ran off the bottom of a 681 pt window.
    The economy panel now lists five transactions. **Stacks of tall panels can still
    overflow small windows** (known issue).
* **Framing:** in the wide sky views (0.9 pt/m) the camera limits keep the street at the
  bottom edge, partly behind the build bar. The clouds and skyline are the subject there.
* **What VoiceOver hears and what Reduce Motion does** is not visible in screenshots. It is
  listed in ACCESSIBILITY.md and verified only by reading the code, not with a screen reader.
