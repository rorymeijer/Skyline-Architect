# Simulation

Status: **FUNCTIONAL (Phases 4–16)** — clock, speeds, people with schedules, tenants and a
rental market (TENANTS.md), navigation graph with stair transfers and elevators, route
cache, re-planning after construction, elevator cars, banks and dispatch strategies,
patience, economy (ECONOMY.md), utilities, upkeep and staff (FACILITIES.md), reputation and
building classes (PROGRESSION.md), lighting energy (LIGHTING.md), weather (WEATHER.md), fire and incidents (EMERGENCIES.md), markets per city (ESTATE.md), scenario objectives (SCENARIOS.md).
PLANNED: needs.

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
  structure changed / cars out of sync? → sync cars, re-plan invalidated trips
  heap ← market, cars and people with nextEventTick ≤ target   (order: tick, market, cars, people, id)
  while pop (tick, who):
    market     → hourly: lighting meter (LIGHTING.md), prospects sign or decline; 06:00: upkeep, jobs, wages (FACILITIES.md),
                 daily closing (ECONOMY.md), tenant reviews/move-outs (TENANTS.md),
                 reputation and promotion (PROGRESSION.md), scenario objectives (SCENARIOS.md),
                 next day's weather (WEATHER.md);
                 prospects per city (ESTATE.md), scaled by its demand, reputation and the weather;
                 hourly also: weather incidents, fire ignition (EMERGENCIES.md)
    fires      → every 60 s: grow / suppress / damage / spread; out → repairs, reputation
    burning building → its people leave by the stairs and keep out (EMERGENCIES.md)
    staff      → arrive / start or finish a job / claim the next / go home (FACILITIES.md)
    car        → collective control step (ELEVATORS.md): alight, board, move or idle
    arrival with pendingRide → bank assigns a car (walk to its doors if another shaft);
                               place = waiting (queue), patience timer; wake the car if idle
    patience ran out → take the stairs if ≤ 5 min (counted as abandoned), else keep waiting
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
  Phase 8 adds early offices (07:30–16:15), late offices (10:00–19:00), late commuters
  (08:40 / 19:40) and retirees (two outings a day); each tenant type picks its schedules.
* People belong to tenants (Phase 8, TENANTS.md); the Phase 4 automatic occupancy was
  replaced. The population sync ends leases of demolished units after every construction
  command and adopts people of older saves on load.

## Navigation (Phase 5)

Code: `NavigationGraph.swift`, `NavigationService.swift`, `RoutePlanner.swift`,
`Replanning.swift`, `NavigationOverlay.swift`.

Two levels:

* **Floors.** A floor plate is one contiguous walking surface (the ground floor extends out
  to the street, 14 m left of the entrance), so two points on one floor are always joined
  by a straight walk. Same-floor trips never touch the graph.
* **Vertical transport.** Each stair shaft (`transport: "stairs"` in `rooms.json`) adds a
  *portal* at its landing on every floor it serves, linked storey by storey
  (14 s per storey). On each floor the portals are chained in x order with walk links
  (distance / 1.3 m/s). A walk link between two shafts is a **transfer**.

A trip between floors = walk to a portal, climb, (transfer walks, climbs)…, walk to the
target. Deterministic Dijkstra over the portals with a virtual source (all portals on the
start floor) and target (all portals on the target floor); the heap orders by
(cost, node index). Consecutive storeys on one shaft merge into one multi-floor leg;
consecutive walks on a floor merge into one walk.

**Cache and invalidation.** `NavigationService` (one per engine, shared by copies) keeps
each building's graph with a *structure signature* — a hash of the floor plates and all
transport shafts. `advance` recomputes the signatures once per step; a changed signature
drops that graph and its cached routes. Placing or removing ordinary rooms does not
invalidate anything. Routes are cached per exact (from floor, from x, to floor, to x) — the
bit patterns of the positions — and store the portal sequence. Because the key is exact, a
cache hit returns precisely what a fresh search would: the cache never changes outcomes
(tested against a run that discards the cache every step, as after loading a save). People
repeat their trips daily from fixed personal spots, so hit rates grow after the first day.
The cache holds at most 4096 routes per building and is cleared when full.

**Re-planning after construction.** A trip is invalid when a remaining leg walks where there
is no floor or uses a shaft that no longer serves those floors. Affected travellers are
re-planned from where they are at that tick (people on stairs step onto the nearest
landing of that shaft). With no route left they leave the building
(`place = outside`, `unreachable = true`) and resume their schedule later. Valid trips are
kept even when a faster route has appeared. The app re-plans right after every command (so
a paused game is consistent); `advance` also does it whenever the structure changed.

**Unreachable** people are counted in the UI; failures are counted in the navigation
metrics (queries, cache hits, failures, graph builds, portals, links) shown in the
developer HUD.

**Debug overlay** (Debug builds, ⌥⌘N): portals, walk links, stair links and each
traveller's remaining route, drawn from `NavigationOverlay` data.

**Elevators** (Phase 6) add a landing node and an in-car node per served floor (board /
ride / alight edges; see ELEVATORS.md). A planned trip stops at its first ride: the
walking legs lead to the landing and `pendingRide` records the ride. After alighting the
rest is planned again from that landing (identical to the original remainder, since the
costs are static), which may include further walks, stairs or another elevator.

## Not yet simulated (honest list)

Needs (hunger, energy …), moods, visitors, live queue length in route choice (patience is
the only reaction to queues), congestion on stairs, economy effects.

## Concurrency

Phase 4 runs the simulation on the main thread inside the SpriteKit frame (≈0.1–0.2 ms per
frame for ~40 people). The engine is a pure value-type function over `GameWorld`, so moving it
to a background `SimulationHost` actor publishing snapshots (Phase 19) needs no model change.
