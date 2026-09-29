# Community mods

24 content mods for Skyline Architect (mod format version 1). They are data only (JSON,
rule 15) and separate from the game. None of them changes the base pack in
`Packages/SkylineKit/Sources/SkylineContent/Resources/Base/`.

Status: **FUNCTIONAL**. `CommunityModsTests` (in `SkylineContentTests`) loads every mod on its
own and all 24 together. It also checks that:

* no mod replaces a base entry;
* every new room can be placed, is furnished, and has a tenant type that rents it;
* every mod scenario starts;
* the Quick Starts blueprints build.

Not verified yet: in-game screenshots of the new interiors, and play balance over long games.

## Installing

Copy a mod's folder into the game's mods folder:

* **Mac:** main menu → *Mods…* → *Open Folder*.
* **iPad or iPhone:** the Files app → *On My iPad/iPhone ▸ Skyline Architect ▸ Mods*.

Then press *Rescan*, switch the mod on and press *Apply*. *Apply* starts a new game; your
saves are kept.

## The mods

**New cities.** Each adds a city, a free lot with a sandbox start and a standard start, a
second lot for sale, and a scenario.

| Folder | Adds |
|--------|------|
| `nordhaven-fjord` | Nordhaven: a cold fjord port on granite with dear energy. Scenario *The Long Winter* (medium). |
| `reedwater-delta` | Reedwater: a delta town on deep clay with low rents and high demand. Scenario *Delta Boomtown* (easy). |
| `highveld-plateau` | Highveld: a plateau business city with top rents and dear builders. Scenario *Prime Address* (hard). |
| `ember-coast` | Ember Coast: a hot resort coast with dear cooling. Scenario *High Season* (medium). |

**New rooms and tenants**

| Folder | Adds |
|--------|------|
| `rooftop-greenhouse` | Rooftop Greenhouse (floor 2 and up) under grow lights, with a City farm tenant. |
| `coworking-hub` | Co-working Space: many workers per module, long hours. |
| `student-housing` | Student Room: small and cheap, with late nights. |
| `medical-clinic` | Medical Clinic with a Family practice tenant; uses a lot of water and climate. |
| `luxury-penthouse` | Penthouse (floor 20 and up, needs the Prime class) for Wealthy households. |
| `daycare-school` | Daycare Centre and Family Apartment, with Young families who value services. |

**Food and leisure (amenities)**

| Folder | Adds |
|--------|------|
| `night-market` | Night Market Food Hall, open 17:00–02:00. |
| `rooftop-pool-spa` | Rooftop Pool & Spa (floor 10 and up, Class A); gets better with height. |
| `bowling-arcade` | Bowling & Arcade for the basement or ground floor; loud, open until 00:30. |
| `cafe-bakery` | Café-Bakery, open 06:30–16:00, for breakfast and lunch. |

**Transport and infrastructure**

| Folder | Adds |
|--------|------|
| `panorama-elevator` | Panorama elevator: 24 persons at 1.4 m/s, and people wait for it longer. |
| `hyperlift-express` | Hyperlift: 10 m/s and stops only at its ends; dear, wears fast, needs the Prime class. |
| `solar-battery` | Solar Array and Battery Room, which both supply electricity. |

**Rule changes.** Each of these replaces one whole rules file. Rule mods that replace the same
file cannot be combined; the last one in the load order wins.

| Folder | Replaces | Changes |
|--------|----------|---------|
| `hard-economy` | `economy.json` | Loans at 12 % up to $3M, bankruptcy after 5 days, higher taxes and bills. |
| `relaxed-builder` | `build-rules.json` | About a third cheaper slabs and foundations, 75 % demolition refund, 2-module cantilevers. |
| `extreme-weather` | `weather.json` | More storms, heatwaves and snow; adds Blizzard, Gale and Drought. |
| `disaster-mode` | `events.json` | About 2.7× as many fires, a slower fire brigade, all incidents 1.6× as often, and new incidents: flooded basement, cooling failure, network outage. |

**Scenarios, furniture and blueprints**

| Folder | Adds |
|--------|------|
| `five-towers` | Five scenarios on the base-game lots: *Corner Shop Row*, *Walk-Up* (no elevators), *Marsh Mansions*, *Crown Jewel*, *Rush Hour* (no staff). |
| `modern-living` | Five designer furniture pieces and new colours, in a Designer Apartment and a Designer Office with their own tenants. |
| `quick-starts` | Three blueprints for 32-module lots: Starter Office, Residential Tower, Mixed Tower. Blueprints cannot be picked in the game yet; for now only the developer tools and the tests use them. |

## Conventions

* Every new id is prefixed with the mod's id (`night-market-hall`).
* New material keys are prefixed in camelCase (`nightMarketLantern`).
* Numbers stay within roughly ±30 % of the closest base entry.
