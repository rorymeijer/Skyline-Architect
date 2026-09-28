# Estate — Properties, Cities and Land

Status: **FUNCTIONAL (Phase 15)**. Implemented:

* cities with their own market (rent, construction, demand), geology and skyline;
* plots for sale with a price and a ready foundation;
* buying land;
* a rental market per city;
* switching between properties while the whole estate keeps running;
* an estate overview.

**PLANNED:**

* weather per city;
* selling land;
* more than one building per plot;
* city-specific tenant types, taxes and events;
* a map view of the estate;
* scenarios built on it (Phase 16).

| Area | Code |
|------|------|
| Model | `SkylineCore/GameWorld.swift` (`City.economy`, `Property.plotID`, `city(of:)`) |
| Construction prices | `ConstructionEngine` (costs × city construction) |
| Rents and market | `SkylineSimulation/Leasing.swift` (asking rent × city rent; `runCityMarket`) |
| Buying, offers, legacy matching | `SkylineContent/Estate.swift` |
| Overview | `SkylineContent/EstateReports.swift` |
| Content | `cities.json` (`economy`), `plots.json` (`price`, `foundation`) |
| App | `AppModel+Estate.swift`, `EstateViews.swift` |

## Cities

| City | Rent | Construction | Demand | Ground |
|------|-----:|-------------:|-------:|--------|
| Port Calder | ×1 | ×1 | ×1 | Deep soft clay and sand over sandstone (the start). |
| Harrowgate | ×1.35 | ×1.25 | ×1.15 | Inland capital. Granite about 4.6 m down (short piles, basements allowed). |
| Saltmere | ×0.75 | ×0.8 | ×0.85 | Harbour town on marsh: 12 m of clay, long piles, one basement level. |

A city's market is copied into the save when the city joins the estate. Each city has its
own seed, so its skyline, neighbours and terrain look different.

## Plots

| Plot | City | Frontage | Basements | Price |
|------|------|---------:|----------:|------:|
| Quay Street Lot | Port Calder | 48 m | 3 | — (the start's plot) |
| Ferry Lane Corner | Port Calder | 32 m | 2 | $900,000 |
| Crown Yard | Harrowgate | 44 m | 4 | $2,400,000 |
| Harbour Row | Saltmere | 56 m | 1 | $450,000 |

**Buying** (`Estate.buy`) does the following:

* adds the city, if it is new to the estate;
* adds the property with its plot id;
* adds a building with the plot's foundation;
* posts the price as a `land` transaction.

It is refused without the cash, and nothing changes on failure. Land purchases are not
construction: they cannot be undone (like loans).

Every plot for sale is tested to be buildable on a fresh estate.

## Effects

* **Construction:** every cost (and demolition refund) is scaled by the building's city.
  Test: a Harrowgate slab costs ×1.25.
* **Asking rent:** base × storey premium × building rent level × city rent. Test: a
  Harrowgate office asks ×1.35.
* **Rental market per city:**
  * prospects come by per city and tenant type, with their own random stream per city seed;
  * they are scaled by city demand × the reputation of the city's buildings × the weather;
  * they only consider that city's units.

  For a one-city game the draws are exactly those of earlier phases. Test: demo towers in
  Port Calder and Saltmere both fill in 3 days.
* **Simulation:** it always runs the whole estate (one clock). The app shows one property
  at a time.

## Estate panel (⌥⌘K, globe button)

* Every property: city, floors, units let, population, best class and reputation, and the
  money booked to its buildings over the last 24 game hours. *Go* switches to it, with a
  new scene and a fresh camera; the undo history is cleared.
* **Land for sale:** frontage, basement limit, the city's market, and **Buy**, which is
  disabled when you cannot afford it. After buying, the view moves to the new plot.

## Save format

Format 12:

* cities gain `economy`;
* properties may carry `plotID`;
* the ledger gains the `land` category.

Older saves load with the default market. On load, `Estate.adoptLegacy` matches their
property to its plot by city and name, and applies the city's content market.

## Limits

* Weather is shared by the whole estate: it is drawn from the first city's seed.
* Loans and cash are estate-wide.
* The overview's 24-hour figure only counts transactions booked to a building. Loans,
  interest and land are estate-level.
