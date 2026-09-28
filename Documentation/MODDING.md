# Modding

Status: **FUNCTIONAL (Phase 17)**. Implemented:

* the base pack plus user mods from a mods folder;
* an enabled list and a load order;
* entries replaced or added by id;
* each mod validated on top of everything loaded before it (a failing mod is skipped and reported);
* dependencies (`requires`);
* saves record their packs with a content hash; loading a save whose packs changed since
  (another version or edited files) works, and the player is told;
* the mod manager;
* an example mod ("Kestrel Bay").

**PLANNED:**

* removing base entries;
* images and sprite sheets;
* hot reload without a new game;
* sharing mods through a catalogue.

## Rules

* Mods are **data only**: JSON, and later images and sprite sheets. There are no scripts, no
  native code and no dynamic libraries, ever. The loader only decodes JSON (rule 15).
* Every definition has a stable string `id`. For new entries, prefix it with your pack's
  name (e.g. `acme-rooftop-bar`).
* Validation errors name the pack, the file or area, and the entry. A mod is never
  partially applied: it loads completely or not at all.

## Mods (Phase 17)

**Where mods live.**

* Each mod is a folder with a `pack.json`, laid out like the base pack below.
* The folder is `~/Library/Application Support/Skyline Architect/Mods/` (on iPadOS, the
  app container equivalent).
* The mod manager (main menu → *Mods…*) lists every installed pack. There you switch a
  pack on or off, change the load order, and install the bundled examples.
* *Apply* reloads all content and starts a fresh game; saves are kept.

**The manifest** (`pack.json`):

```json
{ "id": "kestrel-bay", "name": "Kestrel Bay", "version": "1.0.0", "formatVersion": 1,
  "description": "One line for the mod manager.", "author": "…", "requires": ["other-pack"],
  "files": { "cities": "cities.json", "rooms": "rooms.json", … } }
```

`files` may list these kinds:

* `cities`, `plots`, `starts`, `rooms`, `buildRules`, `blueprints`;
* `materials`, `furniture`, `interiors`, `schedules`, `names`, `elevators`;
* `tenants`, `economy`, `facilities`, `progression`, `weather`, `events`, `scenarios`.

An unknown kind rejects the pack, which catches typos.

**How packs combine.** Packs load in order, starting with the base pack:

* **List kinds:**
  * An entry with an id that already exists **replaces** that entry in place, keeping its
    position (for interiors and elevators, the key is `room`).
  * New ids are **added**.
  * To change one field, copy the whole entry and edit it.
* **Single-file kinds** (`buildRules`, `names`, `economy`, `facilities`, `progression`,
  `weather`, `events`): the mod's file replaces the whole file.
* **`materials`:** merged per key.

**Validation.**

* After laying each mod over the base pack and the mods before it, the loader validates
  the result with the same rules as the base pack.
* A mod that fails is skipped. It is listed as *Not loaded* with the first problem, for
  example: `[bad-ref/…] tenant 'ghost': unknown room type 'no-such-room'`.
* The mods after it still load, and the base game never depends on a mod.
* Other reasons a mod is skipped:
  * its JSON is invalid;
  * its format is unsupported;
  * its id is already taken;
  * a pack listed in `requires` is not loaded before it.

**Saves** list every pack that was loaded. Loading such a save without one of those packs
is refused and names the missing pack. A mod that adds content the save uses must stay
installed.

**The example mod** is Kestrel Bay (`SkylineContent/Resources/Examples/kestrel-bay`). It
adds:

* the city of Kestrel Bay and a plot for sale there;
* a scenario start and the scenario "Kestrel Lofts";
* the Loft Apartment room with its interior layout;
* the "Pier Lofts" blueprint;
* a Creative Household tenant type.

It also replaces the Couple tenant type, so couples rent lofts too.

## Pack layout (current base pack)

```
Base/
  pack.json      { "id": "base", "name": "…", "version": "0.1.0", "formatVersion": 1,
                   "files": { "cities": "cities.json", "plots": "plots.json", "starts": "starts.json" } }
  cities.json        [CityDefinition]
  plots.json         [PlotDefinition]
  starts.json        [StartDefinition]
  rooms.json         [RoomSpec]        — placeable rooms and shafts
  build-rules.json   BuildRules        — slab costs, cantilever, demolition refund
  blueprints.json    [Blueprint]       — scripted construction (dev tools, tests, later scenarios)
  materials.json     { key: "#RRGGBB[AA]" } — colours used by furniture
  furniture.json     [FurnitureDefinition] — vector furniture recipes
  interiors.json     [InteriorLayout]  — how each room type is furnished
```

### CityDefinition
`id, name, description, seed, geology: [{ material, thickness }]` — `material` ∈
`paving, topsoil, clay, sand, gravel, bedrock`; the last stratum is bedrock (infinite).

### PlotDefinition
`id, name, cityID, frontageModules, maxBasementFloors, siteMarginModules`

### StartDefinition
`id, name, mode ("sandbox"), cityID, plotID, propertyName, startingFoundation?
{ buildingName, footprintOffsetModules, footprintModules, basementFloors,
pileDepthMeters, pileSpacingModules }`

### RoomSpec (rooms.json)
`id, name, category, kind ("room" | "shaft"), appearance, minWidth, maxWidth, minFloors,
maxFloors, lowestLevel?, highestLevel?, costPerModule`. `appearance` selects the
presentation style (`office`, `apartment`, `lobby`, `corridor`, `stairs`, `elevatorShaft`,
`mechanical`, `parking`; unknown keys fall back to a neutral shell). Validation: unique
ids, sane ranges, shafts span ≥ 2 floors, non-negative costs. The build palette shows
every definition automatically — a mod adding a room type needs no code.

### Rooms: rent and noise (rooms.json)
`rentPerModule` (monthly asking rent per module; makes the room rentable) and `noise`
(0…1 emitted to neighbours). The Phase 4–7 `occupancy` field was replaced by tenant types.

### Economy (economy.json, rooms.json, starts.json)
`economy.json`: `loanStep, maxLoans, loanInterestRate, bankruptcyDays,
utilitiesPerPersonPerDay, elevatorCarPerDay, rentDaysPerMonth`. Rooms may set
`maintenancePerModulePerDay`; starts may set `startingCash`. See ECONOMY.md.

### Facilities (facilities.json, rooms.json, elevators.json)
`facilities.json`: `utilities [{id, name}], janitorWagePerDay, technicianWagePerDay,
dirtPerPersonPerDay, circulationDirtPerDay, cleanBelow, repairBelow, equipmentRepairBelow,
failureBelow, cleanMinutes, repairMinutes, shiftStart, shiftEnd`. Rooms may set
`utilityDemand {utility: perModule}`, `utilitySupply {utility: perModule}`, `utilityRange`,
`wearPerDay`. Elevator specs may set `serviceOnly: true` (staff only). Tenant weights may
set `services`. See FACILITIES.md.

### Cities and plots (cities.json, plots.json)
Cities may set `economy {rent, construction, demand}` (multipliers, 0…5). Plots may set
`price` and `foundation {buildingName, footprintOffsetModules, footprintModules,
basementFloors, pileDepthMeters, pileSpacingModules}`; a plot with a price is for sale and
needs a foundation that fits its frontage and basement limit. See ESTATE.md.

### Scenarios (scenarios.json)
`[{id, name, difficulty ("easy" | "medium" | "hard"), summary, briefing, startID,
startingCash?, days, holdDays?, objectives [{metric, target}]}]`. Metrics: `population`,
`occupiedUnits`, `cash`, `dailyProfit`, `buildingClass`, `reputation`, `averageWait` (an
upper limit) and `properties`. See SCENARIOS.md.

### Events (events.json, rooms.json)
`fire {ignitionPerRoomPerDay, wornBelow, wornMultiplier, equipmentMultiplier,
protectedIgnitionFactor, stepSeconds, startIntensity, growthPerStep, spreadAbove,
spreadChancePerStep, protectedSpreadFactor, sprinklerSuppressionPerStep,
brigadeResponseMinutes, brigadeSuppressionPerStep, damagePerStep, destroyedBelow,
repairCostPerModule, reputationPenalty}` and `incidents [{id, name, weather [kinds],
maxTemperature?, chancePerDay, target ("room" | "supplies:<utility>"), condition, cleanliness,
cost, reputation}]`. Rooms may set `fireProtection` (sprinkler range in floors). See
EMERGENCIES.md.

### Weather (weather.json)
`seasons [{id, name, temperature}], daysPerYear, startSeason, persistence, temperatureSpread,
energyPerDegree, comfortTemperature, kinds [{id, name, symbol, weights {season: w},
persistence?, effects {demand, wear, dirt, temperature}, look {cloud, fog, precipitation?
("rain" | "snow"), intensity, lightning, heat}}]`. See WEATHER.md.

### Lighting (rooms.json, economy.json)
Rooms may set `lighting {color "#RRGGBB", occupied, empty, wattsPerModule, quietHours?
{from "HH:MM", to, level, spreadMinutes}}`; `economy.json` may set `lightingPricePerKWh`.
See LIGHTING.md.

### Progression (progression.json, rooms.json, tenants.json, starts.json)
`progression.json`: `reputation {dailyAdjustment, weights {satisfaction, services, waits,
occupancy}, goodWaitSeconds, badWaitSeconds, moveOutPenalty, demandAtZero, demandAtHundred}`
and ordered `classes [{id, name, population, reputation, requiredRooms, maxFloor?}]`. Rooms
may set `unlockClass` (class index), tenant types `minClass`; starts set `mode`
(`sandbox` | `standard`). See PROGRESSION.md.

### TenantType (tenants.json)
`id, name, kind ("household" | "business"), rooms [room ids with rentPerModule], role,
members {fixed | perModule}, schedules [schedule ids of that role], budgetPerModule,
weights {rent, access, noise, view}, minScore, leaveBelow, prospectsPerDay`. See TENANTS.md.
`names.json` may add `businessWords` and `businessSuffixes` for business names.

### ElevatorSpec (elevators.json)
`room` (elevator shaft room id), `name, capacity, speed (m/s), acceleration (m/s²),
doorSeconds, transferSeconds (per person), expectedWaitSeconds` (the waiting time route
planning assumes when choosing elevator vs. stairs). Every room with `transport: "elevator"`
needs exactly one entry; validation rejects out-of-range values and unknown rooms.
Optional: `stops` (`"all"` default, or `"ends"` for express/shuttle shafts that stop only at
their lowest and highest floor) and `patienceSeconds` (default 150; personal ±50 %).

### BuildRules (build-rules.json)
`slabCostPerModule, basementSlabCostPerModule, maxCantileverModules, demolitionRefund (0…1)`.
`maxCantileverModules` is how far (modules per side) a floor may stick out past the floor
below; the base game uses 0.

### Blueprint (blueprints.json)
`id, name, description, steps: [{ "floor": {level, start, count} } | { "room": {definition,
start, count, lowest, highest} }]`. Columns are relative to the target building's footprint.

### FurnitureDefinition (furniture.json)
`id, name, width, height, parts: [{ shape: rect|ellipse|polygon|line, x, y, w, h | points,
material ("key" or "$slot"), shade?, lineWidth?, opacity?, minDetail? }], variants?: [{slot: material}],
minDetail?`. Coordinates are meters from the piece's bottom-left.

### InteriorLayout (interiors.json)
`room` (room definition id), `items: [{ furniture, anchor: left|right|center, offset,
elevation?, flip?, minRoomWidth?, maxRoomWidth?, reserve? } | { repeat: { spacing, margin?,
items: [{ furniture, offset, elevation?, flip? }] } }]`. Validation rejects unknown
materials, furniture, slots and rooms.


