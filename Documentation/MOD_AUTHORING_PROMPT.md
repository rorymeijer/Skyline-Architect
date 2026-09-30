# Mod authoring prompt

A ready-to-share brief for making a Skyline Architect mod, by hand or with an AI assistant.
It summarises the content format of engine format version **1** (game 0.24 era); the
authoritative reference stays [MODDING.md](MODDING.md) and the base pack in
`Packages/SkylineKit/Sources/SkylineContent/Resources/Base/`.

## How to use it

1. Copy everything inside the **Prompt** block below into a new chat with an AI assistant
   (or give it to a person).
2. Replace the `<<MOD IDEA>>` section at the end with what you want the mod to do.
3. If the assistant can read this repository, tell it to read the files listed under
   "Reference files" first. If not, attach `rooms.json`, `tenants.json`, `schedules.json`
   and the Kestrel Bay example files so it can copy real field values.
4. Put the resulting folder in the mods folder: on a Mac, main menu → *Mods…* → *Open
   Folder*; on an iPad or iPhone, the Files app → *On My iPad/iPhone ▸ Skyline Architect ▸
   Mods*. Then press *Rescan*, turn it on, press *Apply*. If it shows *Not loaded: …*, paste that
   message back to the assistant — the message names the pack, file and entry.
5. Optional, with the repository checked out: validate headlessly with the test snippet in
   "Headless validation" below.

---

## Prompt

````text
You are helping me create a content mod ("content pack") for Skyline Architect, a native
macOS/iPadOS vertical building management sim. Produce a complete, valid mod folder.

## Hard rules
- A mod is DATA ONLY: a folder of JSON files. No scripts, no code, no images (images and
  sprite sheets are not supported yet). Never suggest executable content.
- The mod loads completely or not at all. One broken reference rejects the whole mod.
- All content must be original: no names, buildings, brands or text copied from existing
  games or real companies.
- Every new id is lowercase-kebab-case and prefixed with the mod id
  (e.g. mod "harbour-life" → room "harbour-life-marina-bar"). Only reuse a base id when you
  deliberately want to REPLACE that base entry.
- Output valid JSON only (no comments, no trailing commas). Numbers are plain numbers.

## Folder layout
<mod-id>/
  pack.json          manifest (required)
  <kind>.json ...    one file per definition kind you use

pack.json:
{
  "id": "<mod-id>",               // unique, kebab-case, not "base"
  "name": "Human Name",
  "version": "1.0.0",
  "formatVersion": 1,             // must be exactly 1
  "description": "One line for the mod manager.",
  "author": "Name",
  "requires": [],                 // other mod ids that must load BEFORE this one (base is implicit)
  "files": { "rooms": "rooms.json", "tenants": "tenants.json" }
}

Allowed keys in "files" (any other key rejects the pack — typos are caught):
  list kinds:   cities, plots, starts, rooms, blueprints, furniture, interiors, schedules,
                elevators, tenants, amenities, hotels, scenarios
  merged map:   materials
  whole-file:   buildRules, names, economy, facilities, progression, weather, events

## How packs combine (load order: base, then enabled mods in order; later wins)
- List kinds: an entry whose key already exists REPLACES it in place; new keys are ADDED.
  The key is "id", except interiors, elevators, amenities and hotels, which are keyed by "room".
  To change one field of a base entry, copy the WHOLE base entry and edit it.
- materials: merged per key.
- Whole-file kinds replace the entire base file — copy the full base file and edit it,
  otherwise you delete every setting you left out.
- Base entries cannot be removed (planned feature). Deprecate them by replacing instead.
- After each mod is laid on top, the combined content is validated with the same rules as
  the base game.

## Definition formats (fields marked ? are optional)

CityDefinition (cities.json, list)
  id, name, description, seed (int),
  geology: [{ material: paving|topsoil|clay|sand|gravel|bedrock, thickness (m) }] — last stratum bedrock,
  economy?: { rent?, construction?, demand?, tax?, energy? }  (multipliers 0…5)

PlotDefinition (plots.json, list)
  id, name, cityID, frontageModules, maxBasementFloors, siteMarginModules,
  price?  (a priced plot is for sale and then NEEDS a foundation),
  foundation?: { buildingName, footprintOffsetModules, footprintModules, basementFloors,
                 pileDepthMeters, pileSpacingModules }
  The foundation must fit inside frontageModules and maxBasementFloors.

StartDefinition (starts.json, list)
  id, name, mode: "sandbox"|"standard", cityID, plotID, propertyName, startingCash?,
  startingFoundation?: { same fields as plot foundation }

RoomSpec (rooms.json, list) — the build palette shows new rooms automatically
  id, name, category (circulation|office|residential|amenity|infrastructure),
  kind: "room"|"shaft" (shafts span ≥ 2 floors), appearance, minWidth, maxWidth,
  minFloors, maxFloors, lowestLevel?, highestLevel?, costPerModule (≥ 0),
  rentPerModule? (makes it rentable; needs a tenant type that rents it),
  noise? (0…1), maintenancePerModulePerDay?, wearPerDay?, unlockClass? (class index),
  utilityDemand? { electricity|hvac|water|data: perModule }, utilitySupply?, utilityRange?,
  fireProtection? (sprinkler range in floors), transport? ("stairs"|"elevator"),
  wasteCapacityPerModule?, staffPerModule?, staffRange?,
  lighting?: { color "#RRGGBB", occupied, empty, wattsPerModule,
               quietHours? { from "HH:MM", to "HH:MM", level, spreadMinutes } }
  appearance ∈ apartment, cinema, corridor, electrical, elevatorShaft, expressElevatorShaft,
    fireControl, fitness, lobby, mechanical, office, parking, restaurant, shop, skyBar,
    staffRoom, stairs, telecom, theater, waste (unknown → neutral shell).
  A room with transport "elevator" needs exactly one ElevatorSpec.

ElevatorSpec (elevators.json, keyed by room)
  room, name, capacity, speed (m/s), acceleration (m/s²), doorSeconds, transferSeconds,
  expectedWaitSeconds, stops? "all"|"ends", patienceSeconds? (default 150),
  serviceOnly?, wearPerStop?, breakdownChance?

TenantType (tenants.json, list)
  id, name, kind: "household"|"business", rooms: [room ids that have rentPerModule],
  role: "resident"|"worker", members: { "fixed": n } or { "perModule": x },
  schedules: [schedule ids with the SAME role], budgetPerModule,
  weights: { rent, access, noise, view, services? }, minScore, leaveBelow, prospectsPerDay,
  minClass? (class index)

Schedule (schedules.json, list)
  id, role: "resident"|"worker",
  events: [{ at "HH:MM", jitterMinutes, goal: home|work|outside|lunch|leisure, chance? (0…1) }]

HotelSpec (hotels.json, keyed by room) — for a room WITHOUT rentPerModule (nights are sold, not leased)
  room, guests (1…8), nightlyRate, checkIn "HH:MM", lastCheckIn "HH:MM" (not before checkIn),
  checkOut "HH:MM" (before checkIn; guests leave the next morning), bookingChance (0…1 per night)
  Base hotel rooms: hotel-single, hotel-twin, hotel-suite (category "hotel", appearance "hotel").

AmenitySpec (amenities.json, keyed by room) — the room also needs a tenant type renting it
  room, opens "HH:MM", closes "HH:MM" (before opens = past midnight),
  occasions: ["lunch","leisure"], capacityPerModule, stayMinutes, spendPerVisit,
  turnoverShare (0…1), streetVisitorsPerModulePerHour, busyHours? [0…23],
  heightBonusPerFloor?, appeal?

FurnitureDefinition (furniture.json, list) — vector art, meters from bottom-left
  id, name, width, height, minDetail?,
  parts: [{ shape: rect|ellipse|polygon|line, x, y, w, h  |  points: [[x,y],…],
            material: "<materials key>" or "$slot", shade?, lineWidth?, opacity?, minDetail? }],
  variants?: [{ "<slot>": "<materials key>" }]

InteriorLayout (interiors.json, keyed by room)
  room, items: [
    { furniture, anchor: left|right|center, offset, elevation?, flip?,
      minRoomWidth?, maxRoomWidth?, reserve? }
    | { repeat: { spacing, margin?, items: [{ furniture, offset, elevation?, flip? }] } } ]

materials.json: { "key": "#RRGGBB" or "#RRGGBBAA" }

Blueprint (blueprints.json, list) — columns relative to the building footprint
  id, name, description, steps: [
    { "floor": { level, start, count } }
    | { "room": { definition, start, count, lowest, highest } }
    | { "foundation": { left?, right?, basementFloors?, pileDepth? } } ]
  A room needs floors under it; shafts/stairs span lowest…highest.

ScenarioDefinition (scenarios.json, list)
  id, name, difficulty: easy|medium|hard, summary, briefing, startID, startingCash?,
  days (≥ 1), holdDays? (1…days),
  objectives: [{ metric: population|occupiedUnits|cash|dailyProfit|buildingClass|
                 reputation|averageWait|properties, target }]   (at least one)
  restrictions?: { forbiddenRooms?, maxFloor?, maxLoans?, fixedRent?, noStaff? },
  events?: [{ day, hour?, kind (e.g. "grant"), message, amount?, when? { metric, target } }],
  scoring?: { fastShare, margin, winPoints },
  tutorial?: [{ id, title, text, chapter?, done: [{ kind, count, rooms? }] }]
  buildingClass targets are class indexes from 1; reputation 0…100; averageWait is an upper limit.

Whole-file kinds (copy the base file in full before editing):
  build-rules.json, names.json, economy.json, facilities.json, progression.json,
  weather.json, events.json — see Documentation/MODDING.md and the topic docs
  (ECONOMY, FACILITIES, PROGRESSION, WEATHER, EMERGENCIES) for every field.

## Base ids you may reference without redefining
rooms: lobby, sky-lobby, corridor, stairs, elevator-shaft, elevator-express,
  service-elevator, office-small, apartment-studio, mechanical, electrical-room,
  telecom-room, parking, fire-control-room, shop, restaurant, fitness, cinema, theater,
  sky-bar, waste-room, staff-room
tenants: consultancy, design-studio, call-centre, couple, single-professional,
  retired-couple, boutique, bistro, fitness-club, cinema-chain, theatre-company, sky-lounge
schedules (worker): office-worker, office-early, office-late, shop-staff, early-staff,
  hospitality-staff, night-staff; (resident): resident-commuter, resident-late, resident-retired
building classes (index): 0 class-c, 1 class-b, 2 class-a, 3 prime
utilities: electricity, hvac, water, data
furniture: door-office, door-apartment, desk-workstation, monitor, office-chair,
  filing-cabinet, meeting-set, plant-tall, plant-small, whiteboard, wall-art, printer,
  kitchen-unit, kitchenette, fridge, bed-double, nightstand-lamp, sofa, tv-unit,
  bathroom-pod, wardrobe, floor-lamp, reception-desk, lobby-sofa, directory-board, bench,
  fire-extinguisher, ahu-unit, pump-set, electrical-panel, car, server-rack,
  sprinkler-valves, fire-panel, clothing-rack, shop-shelf, shop-counter, dining-set,
  pendant-lamp, back-bar, bar-counter, bar-counter-stools, lounge-set, treadmill,
  exercise-bike, weight-rack, mirror-panel, cinema-screen, cinema-seats, stage,
  theater-seats, waste-container, waste-chute, baler, lockers, staff-table,
  coffee-station, tool-board
(If you can read the repository, verify these against Resources/Base — they may have grown.)

## Reference files (read these first if you have repository access)
- Documentation/MODDING.md (authoritative format + merge rules)
- Packages/SkylineKit/Sources/SkylineContent/Resources/Examples/kestrel-bay/ (a complete working mod)
- Packages/SkylineKit/Sources/SkylineContent/Resources/Base/*.json (real values to calibrate against)
- Documentation/BALANCE.md, TENANTS.md, AMENITIES.md, SCENARIOS.md for balancing context

## Consistency checklist (verify before answering)
1. Every file in the folder is listed in pack.json "files", and every listed file exists.
2. Every reference resolves: plot.cityID, start.cityID/plotID, scenario.startID,
   tenant.rooms, tenant.schedules (same role), interior/amenity/elevator.room,
   interior furniture, furniture materials/slots, blueprint room definitions,
   restrictions.forbiddenRooms, progression requiredRooms.
3. A rentable room (rentPerModule) has at least one tenant type that rents it, or players
   can build it but never lease it. An amenity room needs an operator tenant type.
4. New room types get an interior layout (otherwise they render as an empty shell).
5. Ranges are sane: minWidth ≤ maxWidth, minFloors ≤ maxFloors, shafts ≥ 2 floors,
   0…1 fields within 0…1, costs ≥ 0, scenario holdDays ≤ days.
6. Balance: keep new numbers within roughly ±30 % of the closest base entry
   (costPerModule, rentPerModule, budgetPerModule ≥ rentPerModule-ish, minScore > leaveBelow).
7. When replacing a base entry, the full entry is copied, not just the changed field.
8. If a plot has a price, it has a foundation that fits its frontage and basement limit.

## What to deliver
1. A short design summary: what the mod adds/replaces and why, with balance reasoning.
2. The folder tree.
3. Every file in full, each in its own ```json block headed by its file name.
4. A list of base entries the mod REPLACES (so I know what changes for players).
5. How to test it in-game: which start or scenario to pick, what to build, what to expect.

## My mod idea
<<MOD IDEA — e.g. "A harbour district: a new seaside city with a cheap plot, a Marina Bar
amenity open 16:00–01:00, a Boat Club tenant that operates it, and an easy scenario
'Harbour Lights' (40 residents and 3 000/day profit in 25 days).">>
````

---

## Headless validation

With the repository checked out and Swift installed (see `Development/STATUS.md` →
Environment), a mod can be validated without the app. Put this in a scratch test file under
`Packages/SkylineKit/Tests/SkylineContentTests/` (do not commit it), set the path, and run
`Scripts/test-package.sh --filter MyModCheck` (or `swift test --filter MyModCheck` in
`Packages/SkylineKit`):

```swift
import Foundation
import Testing
@testable import SkylineContent

@Suite struct MyModCheck {
    @Test func myModLoads() throws {
        let mods = URL(fileURLWithPath: "/path/to/folder/containing/your-mod")
        let result = try ModLoader.load(mods: ModLoader.discover(in: mods), enabled: ["your-mod-id"])
        for pack in result.packs { print(pack.id, pack.state, "added:", pack.changes.added, "replaced:", pack.changes.replaced) }
        #expect(result.packs.first { $0.id == "your-mod-id" }?.state == .active)
    }
}
```

The printout shows the same *Not loaded* reason the mod manager would, plus exactly which
entries the mod added and replaced.
