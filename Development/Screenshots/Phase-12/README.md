# Phase 12 — Screenshots (full day/night + lighting)

**Real screenshots of the running game**, taken by the screenshot director in the Debug build.

* **Source:** CI run 36380170316 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.12.0 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.
* **Script:** the director builds and leases the demo tower in a sandbox, then advances the clock through one day and the next evening.

`capture-report.json` holds the numbers behind each caption.

| File | Demonstrates |
|------|--------------|
| `01-noon.jpg` | 12:00, plain daylight, no grade. Lighting load 1.2 kW, with the offices busy. |
| `02-golden-hour.jpg` | 18:40, the warm golden-hour grade before sunset. |
| `03-sunset.jpg` | 20:00, sunset: amber toward the horizon. City and neighbour windows light up, street lamps come on, and homes glow. |
| `04-evening-close-up.jpg` | 21:30, close-up. Homes glow warm, the offices are empty and dark, and corridors are dimmed. City lights stay behind the tower. |
| `05-night-skyline.jpg` | 22:15, zoomed out. The tower's lit rooms show as window panes, with the lit city behind and a row of street lamps. |
| `06-small-hours.jpg` | 02:30. Homes are asleep (dimmed, switching off one by one from 22:30); lobbies, corridors and plant stay lit. Load 0.3 kW. |
| `07-sunrise.jpg` | 05:25, the rose sunrise grade. |
| `08-lighting-bill.jpg` | 06:05 closing: the economy panel lists **"Lighting — 17 kWh, Quay Street Tower −$129"** next to the utilities, maintenance and rent lines. |
| `09-power-cut.jpg` | 21:00 the next evening. The electrical room is demolished and the tower goes dark (lighting 0.6 → 0.01 kW), while the neighbours and street lamps stay lit. |

## Inspection notes

**First run (CI run 36379537698)** showed two problems, both fixed and recaptured:

* **Bug:** the additive emission layer drew distant city windows *over* the tower in the
  close-up. The emission tiles now clear the property's building silhouettes and are
  re-rendered on construction. Windows behind the neighbours are left out of the drawing.
  The test `buildingsOccludeCityLights` covers this.
* `08` stacked two panels past the bottom of the view and showed a leftover promotion
  banner. It now shows only the economy panel.

The build before that (CI run 36379325065) failed to compile the app: `Grade` had no public
initializer. That was fixed.

**Programmer art:** lamp glow is flat translucent discs, and the grade is a two-colour
vertical gradient. Real light falloff is Phase 20 (ASSET_REQUIREMENTS).
