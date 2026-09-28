# Phase 13 — Screenshots (weather)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Source:** CI run 36384182661 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.13.0 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the weather was chosen.** Capture 01 shows the weather the game drew itself: day 0 of
seed 7301 is a clear summer day. For captures 02–07 the director **sets** the weather with a
developer helper (`force`), because showing every kind naturally would take weeks of game
time. The notes mark these "(set)", so snow can appear in "summer" there. All simulation
effects shown are real.

Rain and snow particles run in real time, so their exact positions are not reproducible.

| File | Demonstrates |
|------|--------------|
| `01-clear-summer.jpg` | 12:00, the game's own weather: *Clear 23 °C*, tomorrow clear. The chip next to the clock shows the forecast; effects are prospects +10 %, utilities ×1.12. |
| `02-overcast.jpg` | 13:00 (set): overcast, 17 °C. The grade is greyed. |
| `03-rain.jpg` | 14:00 (set): rain, with rain streaks, a darker grade and wet paving outside the tower. Prospects −20 %, wear ×1.2, dirt ×1.5. |
| `04-storm.jpg` | 15:00 (set): storm. Heavy rain, a dark grey sky, the moment of a lightning flash, and office lights on in daytime. Prospects −55 %, wear ×2.5. |
| `05-fog.jpg` | 16:30 (set): fog. The skyline fades and the fog veil whitens toward the horizon. |
| `06-heatwave.jpg` | 17:00 (set): heatwave, 34 °C. A warm haze; utilities ×1.45. |
| `07-snow.jpg` | 18:00 (set): snow, −3 °C. Falling snow, snow on the roofs, the setbacks and the street (not over the cutaway). Utilities ×1.66. |
| `08-snow-night.jpg` | 21:30: snowy night with lit homes, city lights and street lamps. |
| `09-cold-bill-and-forecast.jpg` | Day 2, 06:05. The closing billed **"Utilities — 38 people, 1 elevator cars, −3 °C ×1.66: −$352"**. The new day's own weather is clear, 24 °C. |

## Inspection notes

**First run (CI run 36383539656)** showed three problems, all fixed and recaptured:

* The lightning flash washed the storm scene almost white. Its strength went from 0.45 to
  0.16, and heavy cloud now darkens more than proportionally (CI run 36384182661).
* Snow on roofs and the street was one or two pixels at building zoom. It is now drawn
  thicker than real snow (documented in WEATHER.md).
* Snowflakes were too small; they are larger now.

**Programmer art:** particles are simple streaks and dots.
