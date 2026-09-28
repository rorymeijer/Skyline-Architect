# Tenants & Leasing

Status: **FUNCTIONAL (Phase 8)** — tenant types from content, a deterministic rental
market, unit appraisal, daily reviews and move-outs, unit inspector and leasing panel;
flats for sale next to flats for rent (0.20.3, see *Buying and renting* below).
**PLANNED:** amenities and retail (later room types), visitors.

Code: `SkylineCore/Tenant.swift` (saved state), `SkylineSimulation/TenantType.swift`,
`Leasing.swift` (appraisal, market, signing, move-out), `LeasingReports.swift` (UI data),
content `tenants.json`; app `LeasingViews.swift`, `AppModel+Tenants.swift`.

## Buying and renting (0.20.3)

* **Per flat, in the inspector.** A vacant flat is *for rent* (the default) or *for sale*.
  Only room types that some household type lives in can be sold; businesses always rent.
* **A sale.** A household that signs for a flat for sale buys it: the player receives the
  asking rent × `saleMonths` (100) at once, booked in the ledger's `sales` category. The flat
  is then privately owned (`Tenure.owned`) and the owner pays `serviceChargeShare` (25 %) of
  the asking rent every month instead of rent ("Service charges" in the ledger).
* **Owners stay.** They move out only after `ownerPatience` (9) bad reviews in a row;
  renters after 3. When an owner leaves, the flat stays owned and is resold between private
  parties: the next household pays the player nothing, the service charges go on.
* **Their property.** A sold flat cannot be offered for rent again, demolished or cut by a
  shaft (`ConstructionError.privatelyOwned`).
* **Code.** `SkylineSimulation/Sales.swift`; `Room.tenure`, `Tenant.purchasePrice`; rules in
  `economy.json`. Save format 15.

## Model

* **Tenant** (saved): type id, generated name ("Meridian Labs", "Falk household"), unit
  (room), agreed monthly rent, start tick, satisfaction 0…1, consecutive unhappy days.
  Members are `Person`s with `tenantID`; a unit has at most one tenant.
* **Tenant types** (`tenants.json`): kind (household/business), room types they rent,
  members (fixed or per module), schedules (each member gets one by traits), budget per
  module per month, weights for **rent / access / noise / view**, `minScore` to sign,
  `leaveBelow` for reviews, `prospectsPerDay`.
  Base: consultancy, design studio, call centre (offices); couple, single professional,
  retired couple (studios) — with office-early / office-late / resident-late /
  resident-retired schedules, so traffic peaks spread out.
* **Rooms**: `rentPerModule` makes a room rentable; `noise` (0…1) is what it emits.

## Appraisal (0…1 each)

| Criterion | Measure |
|-----------|---------|
| Rent | asking rent per module vs. the type's budget: `(budget − ask)/budget × 2 + 0.3`; over budget = unaffordable |
| Access | street-to-unit seconds: route walking/stairs + per elevator ride the bank's **measured average wait** (after 10 boardings; otherwise the content estimate) + ride time; 30 s → 1, 300 s → 0. Unreachable → the whole unit scores 0 |
| Quiet | 1 − noise of neighbours (side by side fully, directly above/below half) |
| View | 0.2 + 0.8 × min(floor/15, 1) |

Total = weighted mean. Asking rent = rent per module × width × (1 + 1 % per storey).

## Market (hourly event, deterministic)

Every game hour, for each tenant type in content order, a seeded draw (city seed, hour,
type) decides whether a prospect arrives (`prospectsPerDay / 24`). The prospect appraises
every vacant unit of its room types, prefers affordable ones, takes the best (ties: lower
room id) and signs if it scores ≥ `minScore`; otherwise it declines with its weakest
criterion (too expensive, hard to reach, too noisy, poor view) — or "no vacancy". New
residents move in within 10 minutes; workers start with their next scheduled event.

**Daily review** at 06:00: satisfaction ← 0.6 × old + 0.4 × current appraisal (with
measured waits); three reviews in a row below `leaveBelow` → the tenant moves out (people
leave, unit vacant). Bad elevator service or removed stairs therefore cost tenants.

## Construction and old saves

Demolishing a unit ends its lease. `PopulationSync` no longer fills rooms; it adopts
people from pre-Phase-8 saves into one tenant per room (first type renting that room
type). `Leasing.fillAll` (developer menu, tests) lets every vacant unit to the default
type at once.

## Measured (demo tower, 15 units, CI capture run)

12 of 15 units let within the first 14 game hours; full on day 2–3; in a week 99
prospects: 15 signed, 73 found no vacancy, 5 found units too expensive, 6 declined for the
view (design studios on low floors); average satisfaction 70 %, no move-outs. With stairs
and elevator removed, all upper-floor tenants move out after three daily reviews (tested).
Balancing (rates, budgets) will be revisited with the economy (Phase 9).
