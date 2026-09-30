# Elevators

Status: **FUNCTIONAL (Phases 6–7)** — cars with analytic motion, doors and boarding times,
queues, banks with call assignment (collective / zoning / destination), express shafts
and sky-lobby transfers, patience and abandonment, per-car statistics, traffic overlay and
bank panel. **PLANNED:** service/freight cars (with staff, Phase 10), mid-trip
re-targeting, queue-aware route choice, jerk-limited motion.
Elevators are a core feature and the main optimization puzzle.

## Stops per car, floor numbers and see-through shafts (0.30)

* **Stops.** `ElevatorCar.skippedFloors` (save format 19) lists floors the player switched off.
  * `ElevatorSpec.stopFloors(of:)` gives the floors a car may stop at: all, or the ends.
  * `servedFloors(of:skipping:)` takes the switched-off ones away. At least two always remain;
    `ElevatorStops.set` refuses a change that would leave fewer.
  * The navigation graph, the banks, call assignment and dispatch all read the same list.
  * The graph's structure signature includes it, so switching a floor re-plans trips and
    rebuilds the bank cache.
  * A car standing at a floor that was just switched off, or carrying people to it, stops at
    the nearest served floor and lets everyone out. This is the same rule as for a shortened
    shaft.
  * It is a player setting like the dispatch strategy: there is no undo.
* **Floor numbers.** `RoomLabels.build(…, stops:)` labels an elevator shaft with `FloorLabel`
  at each floor its car stops at, and nothing where it passes.
* **See-through shafts.** A view setting (`⌥⌘J`, remembered). `ArtPalette.seeThroughShafts`
  draws the hoistway as faint glass with a steel frame and half-transparent doors. Shafts
  stand in front of rooms (D-064), so the room behind shows through. Changing the setting
  composes the site anew.

## Wear and breakdowns (Phase E, 0.23)

Code: `SkylineSimulation/ElevatorWear.swift`.

**Wear.** Each stop wears the shaft's `Upkeep` condition by `wearPerStop`: 0.0012 for
passenger shafts, 0.0008 express, 0.0015 service. Below the facilities'
`equipmentRepairBelow` (0.5), a repair job opens at once.

**Breakdowns.** Each further stop risks a breakdown. The chance rises linearly to
`breakdownChance` (4 %) at `failureBelow` (0.15), drawn from `SeededRandom` per car and
tick. A broken car (`outOfService`):
- stands at that floor, and its riders get out;
- is left out of the navigation graph and of call assignment;
- sends everyone who waited for it, rode it or walked to it on a new route (often the stairs).

**Repair.** Technicians take a broken car's shaft before any other repair. Repairing it
restores the condition and puts the car back in service; routes use it again from the next
step. The cab is drawn dark with a warning band, and the Facilities panel counts broken cars.

## Implemented (Phase 7)

Code: `SkylineSimulation/ElevatorBanks.swift` (banks, assignment, ETA),
`ElevatorTraffic.swift` (overlay/panel data), app `TrafficOverlayNode`, `ElevatorBanksPanel`.

* **Banks** are derived, never stored: elevator shafts of the same room type that touch side
  by side and overlap in floors. A bank's id is its lowest shaft id; its strategy is stored
  on each of its cars (a shaft added next to a bank adopts the bank's strategy).
* **Call assignment** happens when a person reaches a landing (`Ride.assigned`): the bank
  picks the car; if it is another shaft of the bank the person walks over to its doors and
  queues there. Cars then run the Phase 6 collective logic over the people assigned to them.
  * **Collective**: the car with the lowest estimated arrival (ETA: travel along its
    current sweep + a dwell per stop on the way + 60 s if it is full).
  * **Zoning**: floors above the bank's main floor are split into one contiguous zone per
    car (left to right); a trip belongs to the zone of its upper end. Other trips: ETA.
  * **Destination**: join a car already collecting people from this floor to the same
    floor (with room); otherwise ETA plus 8 s per extra destination the car already has.
* **Express shafts** (`stops: "ends"` in `elevators.json`, room type `elevator-express`)
  stop only at their lowest and highest floor. With a `sky-lobby` there and a second bank
  above, navigation routes upper-floor trips G → express → sky lobby → upper bank.
* **Patience**: queuing starts a personal patience timer (`patienceSeconds` ± 50 % by
  traits; 150 s local, 240 s express). When it runs out the person takes the stairs if a
  route without elevators exists and takes at most 5 minutes; otherwise they keep waiting.
  Abandonments are counted per car.
* **Statistics** (`CarStats`, saved): boardings, total and maximum wait, stops,
  abandonments, boardings per hour of the current day. Summed per bank for the panel.
* **Measured** (demo-skytower, 175 workers, morning 06:00–11:00; release): all strategies
  deliver everyone; average waits 19–20 s per bank with every strategy; zoning shows higher
  maxima in the low bank (66 s vs 52 s). In a sharp up-peak (arrivals 08:15 ± 5 min) the
  low bank needs 98 stops for 72 boardings with destination dispatch vs 99 for 70 with
  collective — grouping helps only slightly at this traffic level. A 60-floor tower with a
  bank of two cars peaks at 15 waiting (21 with two separate shafts in Phase 6).
* **UI**: traffic overlay (⌥⌘T): queue badges `people · longest wait` (green < 30 s, amber
  < 60 s, red), car loads (when zoomed in), bank labels with strategy and average wait.
  Bank panel (⌥⌘E): strategy per bank, average/max wait, passengers in the last hour,
  boardings, stops, abandonments, waiting now.

## Implemented (Phase 6)

Code: `SkylineCore/Elevator.swift` (state, motion), `SkylineSimulation/ElevatorDispatch.swift`
(sync, collective control), `NavigationGraph` (elevator edges), content `elevators.json`.

* **Car** (`ElevatorCar`, saved): one per elevator shaft room, same id. Floor, direction,
  motion (`idle` / `moving(from, to, start, end, speed, acceleration)` / `stopped(since,
  until)`), passengers in boarding order, next event tick. Created for new shafts (parked
  at G or the served floor nearest to it) and removed with their shaft.
* **Parameters** from `elevators.json` per shaft type: capacity 13, 2.5 m/s, 1 m/s²,
  doors 2 s (open, and again to close), 1 s per person boarding or alighting.
* **Motion** is a trapezoidal velocity profile computed analytically (accelerate, cruise,
  decelerate; triangular for short hops). Trip durations are rounded up to whole ticks.
  Rendering evaluates the exact height at fractional ticks.
* **Queues**: a person whose walking legs end at a landing becomes `waiting(ride, since)`;
  the queue at a landing is everyone waiting there in (since, id) order. A hall call is
  simply a non-empty queue. Riders are `riding(ride)` and listed in the car.
* **Collective control** (at every car event — arrival, doors closed, or a call waking an
  idle car): keep direction while passengers or calls lie ahead; at a floor let out
  everyone for that floor and take waiting people travelling in the car's direction, in
  queue order, up to capacity; dwell = 2 × door time + transfers; next stop = nearest
  passenger floor, call in the travel direction, or the farthest call ahead (turning
  point). An idle car goes to the nearest call. Calls made while a car moves are
  considered at its next stop (no mid-trip re-targeting yet).
* **Routing**: each shaft adds a landing and an in-car node per served floor. Boarding
  costs `expectedWaitSeconds` + door and transfer time + v/a; riding costs storey height /
  speed per floor; alighting the transfer time. With the base values the stairs win for
  one or two storeys, the elevator from three. The expected wait is a constant so routes
  stay cacheable and deterministic (DECISIONS D-026); the live queue does not influence
  route choice yet (Phase 7).
* **Construction**: removing a shaft moves its riders to the queue at the floor the car
  was nearest to, then everyone waiting for or heading to it is re-planned (stairs or
  another shaft) or leaves the building if there is no way.
* **Rendering**: cab (lit interior, sliding car doors in 4 steps, crosshead) and hoist rope
  drawn above the static shaft art and below people; people queue at the landing doors and
  stand inside the cab. HUD: cars, riding, waiting, longest current wait.

## Model (planned)

* **Shaft** — vertical span of floors, column position, width (1 or more cars side by
  side belong to a *bank*), type: local / express / service / freight.
* **Car** — capacity (persons, kg), max speed, acceleration/jerk, door open/close
  time, per-passenger boarding time, served floors (subset of shaft span), wear.
* **Bank** — group of shafts sharing hall buttons and a dispatcher.
* **Hall call** — floor + direction (collective control) or floor + destination
  (destination dispatch).
* **Queue** — ordered agents waiting at a landing; each knows its destination and
  patience; abandonment is recorded.

## Motion

Trapezoidal (later jerk-limited) velocity profiles computed analytically per trip:
given distance, max speed and acceleration, the trip time and position(t) are exact.
Cars therefore only need events (arrive, doors open, doors closed), not per-tick
integration — cheap and deterministic.

## Dispatch strategies (original plan; see "Implemented (Phase 7)")

`ElevatorDispatcher` is a strategy chosen per bank:
1. **Collective control** (Phase 6): cars serve calls in the direction of travel.
2. **Zoning / up-peak** (Phase 7): cars assigned to floor zones during peaks.
3. **Destination dispatch** (Phase 7): passengers enter destination at the landing;
   the dispatcher groups passengers by destination to minimize stops.
4. Player-configurable policies (future).

## Statistics

Per bank and building: average wait, max wait, passengers/hour, car occupancy,
travel time, abandoned queues. Feeds tenant decisions (Phase 8) and the elevator
traffic overlay.
