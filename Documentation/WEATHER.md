# Weather — Seasons, Daily Weather and Its Effects

Status: **FUNCTIONAL (Phase 13)**. Implemented:

* seasons;
* seven kinds of weather, drawn per day with a forecast, separately in every city (save
  format 14); a building feels its own city's weather and the screen shows the weather of
  the city on view;
* effects on prospective tenants, wear, dirt and heating/cooling costs;
* weather visuals and a weather chip.

**PLANNED:**

* weather within a day (hourly changes);
* seasonal day length;
* wind acting on elevators and façades;
* flooding (storm damage, outages and burst pipes exist since Phase 14);
* commuters reacting to rain.

Code:

| Part | Where |
|------|-------|
| Model | `SkylineCore/Weather.swift` (`WeatherKind`, `WeatherRules`, `WeatherState`, `Weather` draw / next) |
| Effects | `SkylineSimulation/WeatherEffects.swift`, `WeatherReports.swift`; hooks in `Leasing.runMarket`, `Staff.facilitiesDaily`, `Economy.closeDay` |
| Visuals | `SkylinePresentation/Art/WeatherArt.swift` (`WeatherLook`, grade, lightning, roofs, street); app `WeatherLayer.swift` |
| Content | `weather.json` |

## Seasons and daily weather

`weather.json` defines four seasons over a 28-day year, starting in summer to match the
summer daylight curve (LIGHTING.md). Each **kind** has:

* a relative weight per season (snow only in autumn and winter; heatwaves only in summer);
* an optional persistence;
* simulation effects;
* a look.

At every 06:00 closing, tomorrow becomes today and a new forecast is drawn:

* The weather keeps yesterday's kind with its persistence (for example 40 % by default,
  10 % for storms), if the season allows that kind.
* Otherwise it is a weighted draw for the season.
* The temperature is the season's value plus the kind's offset, ± 3 °C.

Everything is a pure function of the city seed, the day and the previous kind. The state
(`yesterday`, `today`, `tomorrow`, temperature, day) is saved (format 10). Older games start
their weather on their current day.

| Kind | Demand | Wear | Dirt | °C | Look |
|------|--------|------|------|----|------|
| Clear | ×1.1 | 1 | 1 | +2 | — |
| Overcast | 1 | 1 | 1 | −1 | cloud 0.6 |
| Rain | ×0.8 | ×1.2 | ×1.5 | −3 | cloud 0.8, rain 0.6, wet paving |
| Storm | ×0.45 | ×2.5 | ×1.8 | −4 | cloud 1, heavy rain, lightning |
| Snow | ×0.65 | ×1.5 | ×1.6 | −5 | cloud 0.7, snow, snow cover |
| Heatwave | ×0.9 | ×1.2 | 1 | +11 | warm haze |
| Fog | ×0.9 | 1 | ×1.1 | −2 | fog 0.75 |

## Effects on the simulation

* **Prospective tenants:** every tenant type's arrival rate is multiplied by `demand` (and
  by reputation, Phase 11).
* **Upkeep:** the daily wear and dirt of the day that ends are multiplied by `wear` and
  `dirt`. A stormy day therefore creates more repair and cleaning jobs.
* **Heating and cooling:** the daily utilities line is multiplied by
  `1 + 0.03 × |temperature − 19 °C|`, and the line states the temperature and the factor
  (`… −3 °C ×1.66`).

Tests:

* `stormsKeepProspectsAway`: 7 prospects in 23 h during a storm against 18 when clear.
* `extremeTemperaturesRaiseTheUtilitiesBill`: ×1.48 at 35 °C, ×1.60 at −1 °C.
* `stormsWearAndDirty`.

## Visuals

`WeatherView.look` turns the saved state into a look at an instant. After 06:00 it changes
from yesterday's look to today's over 45 minutes.

* **Grade:** clouds desaturate and darken the day grade (heavy cloud more than
  proportionally); fog whitens it, most at the
  horizon; heat warms it. Clouds and fog also count as darkness for the lights, so lights
  come on in a daytime storm.
* **Fog veil:** a screen-space veil above lights and emission, dimmed at night. City
  lights fade in fog.
* **Rain and snow:** screen-space particle emitters (decoration; they run in real time and
  are prewarmed when precipitation starts). Their size, speed, density and opacity follow the
  zoom (`WeatherView.particleScale`): larger and faster close up, smaller, denser and fainter
  far out; neutral at 8 pt/m.
* **Lightning:** a deterministic flash in game time. In every 40 s window there is a 25 %
  chance of a strike, which fades over 3 s.
* **Ground:** snow lies on roofs and setbacks and on the street outside the foundations.
  It stays for a day after snowfall while the temperature is at or below 3 °C, and is
  drawn thicker than real snow so it reads at building zoom. Rain darkens the paving.
* **UI:** a weather chip next to the clock: symbol, name, temperature and tomorrow's
  symbol. Its tooltip shows the season, the effects and the forecast.

## Limits

* Weather changes once a day.
* Day length does not follow the season (always summer daylight).
* Every city has the same climate (content rules); only its days differ.
