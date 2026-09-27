# Simulation

Status: **FUNCTIONAL (Phase 4 subset)** — clock, speeds, people with schedules, routes via
stairs, population sync. PLANNED: navigation graph (Phase 5), elevators (6–7), tenants and
needs (8), economy (9).

Code: `Packages/SkylineKit/Sources/SkylineSimulation` (logic) and `SkylineCore/People.swift`
(saved state).

## Principles (implemented)

1. **Authoritative state lives in the model.** `GameWorld.people` and `GameWorld.clock` are
   saved; the renderer reads them and never writes.
2. **Fixed tick.** 1 tick = 1 game second. The day starts at 06:00 on tick 0.
3. **Speed = ticks per real second**, never a longer tick: 1× = 24 ticks/s (one game hour
   takes 150 real seconds), 2× = 48, 4× = 96, 10× = 240; pause = 0. `SimulationHost`
   converts frame time into whole ticks (max 480 per frame, so a hitch cannot spiral).
4. **Batch-independent.** `SimulationEngine.advance(world, by: n)` gives the identical world
   whether called once with n or n times with 1 (tested with 5 game hours in 7-tick steps vs.
   one call). Therefore outcomes never depend on game speed or frame rate.
5. **Event-driven.** A person is only processed at `nextEventTick` (arrival, next schedule
   goal). Between events, trips are *analytic*: a `Place.travelling` holds legs (walk / stairs)
   with absolute start and end ticks, and `PersonMotion.sample(legs, at: t)` gives the exact
   position for any fractional `t` — the renderer evaluates it at `tick + fraction`, so there
   is no snapshot buffer and interpolation is exact.
6. **Deterministic.** Events are processed in (tick, person id) order from a binary heap
   rebuilt per call (never stale, never saved); jitter and names come from `SeededRandom`
   keyed by person traits, day and event index.

## Tick processing

```
advance(world, n):
  target = clock + n
  heap ← people with nextEventTick ≤ target
  while pop (tick, id):
    arrival?   → place = destination; schedule next goal
    goal due?  → resolve work/home/outside → plan route → place = travelling(legs)
                 (no route → unreachable = true; stays put; next goal)
    re-push if the new nextEventTick ≤ target
  clock = target
```

## People (Phase 4)

* Identity: id, generated name (`names.json`), age, role (worker / resident), schedule id,
  building, home or work room, traits seed (appearance + jitter).
* Schedules (`schedules.json`): office workers arrive 08:15 ± 40 min, lunch out 12:15 ± 20,
  back 13:00 ± 15, leave 17:15 ± 45; residents commute out 07:45 ± 40 and return 18:15 ± 75.
* Population sync (stand-in for Phase 8 tenants): rooms whose spec has `occupancy` get
  that many people (offices 0.3 per module, studios 2 residents); demolished rooms'
  occupants leave. Runs after every construction command and on load.

## Routing (Phase 4 minimum)

Street (14 m left of the entrance) → ground-floor entrance → walk → **one stairwell** whose
floor range contains both floors (nearest overall) → walk → personal spot in the room.
Walking 1.3 m/s, stairs 14 s per storey. No stairs to a floor ⇒ unreachable (reported in
the UI). Phase 5 replaces this with a hierarchical navigation graph (transfers, elevators,
route caching, invalidation on construction).

## Not yet simulated (honest list)

Needs (hunger, energy …), moods, visitors, elevators, route invalidation for people already
mid-trip when construction changes (they finish the old trip), economy effects.

## Concurrency

Phase 4 runs the simulation on the main thread inside the SpriteKit frame (≈0.1–0.2 ms per
frame for ~40 people). The engine is a pure value-type function over `GameWorld`, so moving it
to a background `SimulationHost` actor publishing snapshots (Phase 19) needs no model change.
