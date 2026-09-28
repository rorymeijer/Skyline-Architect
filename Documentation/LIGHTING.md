# Lighting — Day/Night, Light Sources and Energy

Status: **FUNCTIONAL (Phase 12)**. Implemented:

* a lighting model per room type, stored as content;
* colour grading through the day;
* coloured room light;
* façade window emission at far zoom;
* a night emission layer: city windows and neighbour windows, fewer lit as the night goes on;
* street lamps in their own layer, on all night;
* lighting energy metered and billed;
* lights that need power.

**PLANNED:**

* lights as security in events (Phase 14);
* player lighting policies (timers, sensors);
* real light falloff and shadows (Phase 20).

Code:

| Part | Where |
|------|-------|
| Model (shared by simulation and renderer) | `SkylineCore/Lighting.swift` (`LightingSpec`, `Lighting.level`) |
| Energy meter | `SkylineSimulation/Energy.swift` (metering), `Economy.closeDay` (billing) |
| Rendering | `SkylinePresentation/Art/DayNight.swift` (grade, lit rooms, panes), `Art/NightArt.swift` (emission art), `SiteComposition.emission` / `.occluders`; app `DayNightLayer.swift` and a second, additive `TileLayer` |
| Content | `lighting` in `rooms.json`, `lightingPricePerKWh` in `economy.json` |

## One model, two consumers

`Lighting.level(spec, room, occupied, secondOfDay, power)` gives a room's light level from 0
to 1:

* `occupied` while someone is in the room, `empty` otherwise;
* capped at `quietHours.level` during the quiet hours;
* multiplied by the room's served **electricity** fraction (Phase 10).

Quiet hours start up to `spreadMinutes` later per room, stable per room id, so homes go dark
one by one.

| Room | Colour | Occupied / empty | W per module | Quiet hours |
|------|--------|------------------|--------------|-------------|
| Office | cool white `#EAF1FF` | 1 / 0 | 11 | — |
| Studio apartment | warm `#FFC47E` | 1 / 0 | 7 | 22:30–06:15 → 6 %, spread 90 min |
| Lobby, sky lobby | `#FFE3B5` | 1 / 0.6 | 9 | — |
| Corridor | `#FFE9C4` | 1 / 0.45 | 5 | — |
| Parking | `#DDE6FF` | 1 / 0.5 | 3 | — |
| Plant rooms | `#DCE7FF` | 1 / 0.15–0.2 | 3 | — |
| Shafts | — (no lights) | | | |

The same function drives:

* **what is drawn:** `DayNight.litRooms` scales each level by the darkness, 1 − daylight;
* **what is paid:** the simulation meters lighting load at every hourly market event. It
  adds watts × 1 h to `Building.lightingKWh`, which is saved, so metering does not depend
  on batch size. The 06:00 closing posts a `Lighting — N kWh` utilities line and resets
  the meter.

The price is `lightingPricePerKWh` (7.5). Like rent, it is a month's worth per day (D-032).

A power cut therefore darkens the tower and stops its lighting bill (`noPowerNoLight`).
The plant rooms have no electricity demand in the content, so they keep their dim light,
which reads as emergency lighting.

Measured on the leased demo tower:

| Time | Load | Why |
|------|------|-----|
| 11:00 | 1.16 kW | offices busy |
| 20:00 | 0.64 kW | homes lit |
| 03:00 | 0.26 kW | circulation and plant only |

Energy is about 17–18 kWh per day, which comes to about $130 a day. That is small next to
rent (about $45k a day); balancing is still open.

## Rendering

* **Grade:** instead of one flat tint, the scene is multiplied with a vertical gradient
  (`DayNight.grade`). Plain by day. The colours are:
  * sunrise: rose;
  * golden hour (from 17:15) and sunset: amber, warmest at the horizon;
  * night: blue with a slightly lighter horizon.
* **Room light:** additive quads in each room's light colour. Below 5 pt/m (the massing
  and skyline zoom levels), lit rooms become **window panes** on the façade: 1.5 m panes
  every 2 m, from sill to head.
* **Emission layer:** the composition carries a static `emission` drawing (city windows at
  reduced scale, neighbours' windows). The app shows it as a second tile layer with additive
  blending. Its opacity follows the darkness times `DayNight.cityActivity` (the share of the
  city still awake), and it sits above the grade so that it glows. Two things keep it from shining through buildings:
  * the property's building silhouettes (`occluders`, one per floor plate) are cleared
    from its tiles, which are re-rendered on construction;
  * distant windows behind the neighbours are left out of the drawing.
* **Street lamps:** a post every 32 m outside the buildable frontage (posts in the site
  layer, glow in the composition's `lamps` drawing, a third small additive tile layer whose
  opacity follows the darkness only).

## Limits

* The grade and the window panes work in screen space and room rectangles; there is no
  per-light falloff and no shadows.
* The city's lit windows are baked once per game; the hour changes how many show as a whole
  (`DayNight.cityActivity`: all on until 22:00, 40 % from 01:30, early risers from 04:30), not
  which ones. Street lamps are a separate layer and stay on all night.
