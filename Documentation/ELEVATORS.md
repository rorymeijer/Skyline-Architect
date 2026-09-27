# Elevators

Status: **FUNCTIONAL (Phase 6 subset)** — one car per shaft, analytic motion, doors and
boarding times, hall calls as queues, collective control, elevator routes in navigation,
rendering of cars / queues / riders. **PLANNED (Phase 7):** banks with several cars,
express/local, sky lobbies, other dispatch strategies, statistics and traffic overlay.
Elevators are a core feature and the main optimization puzzle.

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

## Dispatch strategies (planned)

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
