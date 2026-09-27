# Modding

Status: **SCAFFOLDED** — content already loads from a declarative JSON pack; pack
merging and user mod folders are PLANNED for Phase 17.

## Rules

* Mods are **data only** (JSON, and later images/sprite sheets). No scripts, no native
  code, no dynamic libraries. Ever.
* Every definition has a stable string `id` (`namespace.name` recommended for mods,
  e.g. `acme.rooftop-bar`).
* Validation errors name the pack, file and id; invalid packs are rejected, never
  partially applied.

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

## Planned (Phase 17)

Load order (base → mods by dependency), override-by-id with explicit `"override": true`,
additive lists, content hashes stored in saves so a save knows which packs it needs.
