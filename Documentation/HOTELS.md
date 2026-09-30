# Hotels

Status: **FUNCTIONAL (0.30)**. The hotel follows the classic tower games: rooms are sold night
by night instead of being leased.

## Content
`hotels.json` (a list keyed by `room`; mods may add or replace entries) says what each room
offers:

* how many guests it sleeps;
* the nightly rate;
* the booking hours (`checkIn`…`lastCheckIn`);
* `checkOut`;
* a `bookingChance` per night.

A hotel room is a room type **without** `rentPerModule`, so the rental market never leases it.
The base game has three rooms, in category `hotel` with appearance `hotel`:

| Room | Guests | Rate | Booking hours | Check-out | Chance |
|------|--------|------|---------------|-----------|--------|
| `hotel-single` | 1 | 1300 | 15:00–23:00 | 10:00 | 0.8 |
| `hotel-twin` | 2 | 2100 | 15:00–23:00 | 10:00 | 0.7 |
| `hotel-suite` | 3 | 3800 | 15:00–22:00 | 11:00 | 0.55 (Class B) |

## Simulation (`SkylineSimulation/Hotels.swift`, hourly with the market)
1. **Checkout.** Every stay whose `checkOut` has passed:
   * the night is paid (ledger category `hotel`);
   * the room is added to `awaitingHousekeeping`;
   * a clean job opens.
2. **Booking.** In its booking hours, a room that is vacant and cleaned, in a building not on
   fire, is booked with the chance
   `1 − (1 − p)^(1/hours)`, where
   `p = bookingChance × city demand × weather demand × reputation demand × servicesLevel`.
   The night's chance is therefore `p`, whatever the number of booking hours.
3. **Guests.** A booking creates `guests` people with role `guest`, their room in `visit`:
   * they arrive within the hour;
   * they stay in the room until `checkOut` (±45 minutes);
   * they then leave and are purged with the street visitors.
   * A fire sends them home early; the night is still paid at checkout.
4. **Housekeeping.** When a janitor completes the clean job, the room leaves
   `awaitingHousekeeping` and can be booked again. Without janitors, every room sells one
   night and then stands empty.

Everything is deterministic: seeded per city, room and hour. Hotel income counts toward the
scenarios' daily profit.

## State (save format 20)
`world.hotel` (`HotelState`) holds:

* `stays` (room, guests, booked, checkOut, rate);
* `awaitingHousekeeping` (sorted room ids);
* the totals `nights` and `income`.

Guests are `PersonRole.guest`. The ledger's daily totals grow by one (`hotel`); the v19→v20
migration pads them.

## App
* The unit inspector shows the room's state: vacant, booked (guests in the room and
  check-out time), or needs housekeeping (whether a janitor is on the way).
* The people count's tooltip counts guests.

Screen tour step 23 captures two rooms booked at night.
