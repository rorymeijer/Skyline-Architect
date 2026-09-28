# Amenities and Visitors

Status: **FUNCTIONAL** (0.22, Phase B). Code: `SkylineSimulation/Amenities.swift` (content
type), `Visitors.swift` (visits, visitors, takings, appeal), `AmenityReports.swift` (UI data);
content: `amenities.json`, the amenity rooms in `rooms.json`, their operators in
`tenants.json`, lunch and leisure events in `schedules.json`.

## Rooms and operators

Six amenity rooms (palette group *amenity*), each rented like an office by an operator
tenant type:

| Room | Operator | Hours | Serves | Seats / m | Stay | Spend | Share |
|------|----------|-------|--------|-----------|------|-------|-------|
| Shop | Boutique | 09:00–21:00 | lunch, leisure | 0.8 | 20 min | $30 | 8 % |
| Restaurant | Bistro | 11:00–23:00 | lunch, leisure | 1.5 | 55 min | $32 | 7 % |
| Fitness Club | Fitness club | 07:00–21:00 | lunch, leisure | 0.8 | 60 min | $12 | 10 % |
| Cinema | Cinema chain | 13:00–23:30 | leisure | 2.5 | 130 min | $18 | 8 % |
| Theatre | Theatre company | 18:00–23:00 | leisure | 3 | 150 min | $45 | 6 % |
| Sky Bar (floor 15+) | Sky lounge | 16:00–01:00 | leisure | 1.2 | 75 min | $45 | 10 % |

An amenity without an operator is closed: no customers, no appeal. The operator's staff are
its members (workers on `shop-staff`, `early-staff`, `hospitality-staff` or `night-staff`).

## Who comes

**Occupants.** Office schedules have a `lunch` event and resident schedules a `leisure`
event, each with a `chance` per person and day (lunch 60 %, leisure 35–40 %). At the event:

1. Candidates are the building's open venues that serve the occasion and stay open another
   20 minutes.
2. The seats have to go round: the person looks in with a probability of
   seats ÷ workers (lunch) or seats ÷ residents (leisure), at most 1.
3. A venue is picked weighted by its seats (deterministic per person and day).
4. Otherwise lunch is eaten out (the old behaviour) and leisure is skipped.

They stay until their next schedule event (back to work at 13:00, home at 22:15).

**Street visitors** (`PersonRole.visitor`) are spawned at every market hour for every open
venue. The number per hour is:

  width × `streetVisitorsPerModulePerHour` × 2 in `busyHours` × city demand × weather demand
  × reputation demand × (1 + `heightBonusPerFloor` × floor).

It is capped at the seats' turnover in an hour. Arrivals are spread over the hour.

A visitor walks in from the street, takes the elevators like anyone else, and stays about
`stayMinutes` (personal ±30 %, never past closing). Then they walk out. Someone who cannot
get in or out (the venue closed, no route) goes home at once. Departed visitors are
removed hourly in one pass. During a fire, visitors leave and do not come back.

## Money

Every arrival of a customer adds the venue's `spendPerVisit` × the city's price level to
its operator's takings (`Tenant.sales`). At the 06:00 closing the landlord receives
`turnoverShare` × the day's takings, booked in the ledger category `turnover`, on top of
the operator's rent. The day's figures then become yesterday's.

## Appeal

Open amenities make the building's other units more attractive. Each kind of amenity
counts once and adds its `appeal` to their appraisal (the base game: 0.02–0.03 each,
0.14 for all six). The inspector shows it as part of the total.

## UI

- **Unit inspector** of an amenity:
  - open or closed, with the hours and seats;
  - customers inside;
  - today's and yesterday's customers (from the street) and takings;
  - the landlord's share.
- **Leasing panel:**
  - venues open;
  - visitors inside;
  - yesterday's customers, takings and share.
- **Economy panel:** the *Turnover* row.
- **HUD:** the in/out count leaves out visitors who are still outside or have gone home.

## Limits and follow-ups

- The seat check is statistical (seats ÷ occupants), not a live count, so a venue can be
  briefly over-full. It keeps visits deterministic and cheap.
- Operators do not yet weigh their own takings when reviewing the unit (a quiet shop stays).
- Visitors have no needs or moods. They come for one venue only.
