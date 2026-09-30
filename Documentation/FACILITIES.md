# Facilities — Utilities, Upkeep and Staff

Status: **FUNCTIONAL (Phase 10)** — abstracted utilities from equipment rooms with capacity
and range, equipment failure, wear and cleanliness per room, cleaning/repair jobs done by
hired staff who travel through the building (incl. staff-only service elevators), wages,
effect on tenants, facilities panel, services overlay. **PLANNED:** waste, energy prices,
staff rooms and skills, elevator wear/outages, security (Phase 14 events).

Code: `SkylineCore/Facilities.swift` (Upkeep, jobs), `SkylineSimulation/Utilities.swift`
(allocation), `Staff.swift` (daily upkeep, jobs, staff behaviour, hiring),
`FacilitiesReports.swift` (panel/overlay data), content `facilities.json`, room fields in
`rooms.json`; app `FacilitiesPanel.swift`, `ServicesOverlayNode.swift`.

## Utilities (derived, not saved)

Four utilities in `facilities.json`: electricity, water, climate (hvac), data. Rooms declare
`utilityDemand` (per module per floor); equipment rooms declare `utilitySupply` (per module
of width) and `utilityRange` (floors above and below they reach):

| Equipment | Supplies (per module) | Range |
|-----------|----------------------|-------|
| Electrical room | electricity 120 | ±25 floors |
| Mechanical room | climate 70, water 40 | ±20 |
| Telecom room | data 150 | ±45 |

Allocation per building and utility: consumers are served lowest floor first; each draws
from the nearest equipment within range that has capacity left (ties: lower id). The
result is a served fraction per room and utility. Equipment whose condition is below
`failureBelow` (0.15) supplies nothing. Tall buildings therefore need plant floors and
enough capacity — the demo tower is fully supplied; the sky tower's climate plant is too
small for its upper floors (a deliberate shortage, tested).

## Upkeep (saved beside rooms)

`Upkeep` (condition, cleanliness 0…1) per room, created with the room. Each 06:00 closing:
condition −= `wearPerDay` of the room type (equipment wears fastest), cleanliness −=
`dirtPerPersonPerDay` × people belonging to the room (shared rooms: a fixed rate). Jobs
open when cleanliness < 0.6 (clean) or condition < 0.3 (repair; equipment already < 0.5).

## Staff

Janitors (clean) and technicians (repair) are hired per building in the Facilities panel
and paid daily (`wages` in the ledger). Shift 07:00–19:00: they come in from the street,
claim the most urgent job of their trade (failed equipment first, then the worst room,
then the oldest), travel there with stairs, public and **service elevators** (route mode
`staff`; tenants' routes never board service elevators), work 20 min (clean) or 45 min
(repair), restore the room and take the next job; after the shift they go home. A job
whose room is demolished disappears; a dismissed employee's job returns to the list.

### Staff rooms (Phase E)

- A **Staff Room** houses 0.75 staff per module, rounded down (a 6-module room holds 4).
- The Facilities panel can hire only while a place is free. Existing staff in older saves
  keep working.
- Staff with nothing to do on their shift wait in the nearest staff room.
- A job more than `staffRange` (10) floors from every staff room takes
  `outOfRangeFactor` (1.5×) as long.
- Content without staff rooms keeps unlimited hiring.

### Waste rooms (Phase E)
See ECONOMY.md → closing. The Facilities panel shows the daily waste against what the
waste rooms take.

### Elevator wear (Phase E)
See ELEVATORS.md → Wear and breakdowns. A broken car's shaft is the most urgent repair job.

## Effect on tenants

Appraisals gain a **services** criterion: 60 % utilities supplied, 20 % cleanliness, 20 %
condition (tenant-type weight `services`, default 0.25). A unit's total is also capped at
0.3 + 0.7 × its worst-served utility — without power a unit is unusable. Prospects then
decline with *poor services*; tenants review daily and leave after three bad days.

## UI

* Facilities panel (⌥⌘F): supply / demand and short rooms per utility, equipment out of
  order, staff counts with hire/dismiss, open jobs, wages, average cleanliness/condition.
* Services overlay (⌥⌘U): rooms tinted by their worst problem — red out of order, orange
  missing utilities, amber worn, blue dirty, faint green fine.
* Inspector: utilities ✓/⚠ per unit, cleanliness and condition, services bar.
* Staff wear coveralls: janitors teal, technicians orange, housekeepers plum (0.30.1, hotel rooms only: HOTELS.md).
