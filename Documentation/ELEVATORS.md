# Elevators

Status: **PLANNED** (Phases 6–7). Elevators are a core feature and the main
optimization puzzle.

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
