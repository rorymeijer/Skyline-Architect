# Simulation

Status: **PLANNED** (Phase 4+). Phase 1 has no running simulation; the model is static.

## Principles

1. **Authoritative state lives in the model** (`SkylineCore` value types, later a
   `SkylineSimulation` module). Renderer and UI read snapshots.
2. **Fixed tick.** Simulation advances in fixed ticks (planned: 0.25 s of game time).
   Game speed (1×, 2×, 4×, 10×) = number of ticks run per real second. The tick length
   never changes, so results are identical at every speed (determinism tests will run
   the same scenario at 1× and 10× and compare state hashes).
3. **Simulation frequency ≠ render frequency.** Rendering runs at display rate and
   interpolates agent positions between the last two published snapshots.
4. **Event-driven where possible.** People are not updated every tick. Each agent has a
   *next wake time* in a priority queue (activity finished, arrived at waypoint,
   elevator arrived). Walking along a known segment is analytic
   (position = start + speed × t), so agents between events cost nothing.
5. **Simulation LOD.** Agents far from the camera skip cosmetic behaviour (idle
   wandering, animation state) but keep all logically relevant state (location,
   schedule, needs, queue membership). There is never "fake" teleporting that would
   change elevator loads or economy.
6. **Determinism.** Seeded `SeededRandom` (SplitMix64) per subsystem, stable
   iteration (`EntityStore`), no wall-clock reads, fixed merge order for any parallel
   work.

## Planned tick pipeline (Phase 4–9)

```
tick(n):
  1. apply queued player commands (construction, rent changes)   — ordered by sequence
  2. clock advance; schedule triggers (shift starts, meals)
  3. process agent wake-ups due ≤ now (priority queue, stable tie-break by id)
  4. transport systems step (elevators: dispatch, motion, boarding)
  5. economy accrual (hourly/daily postings to ledger)
  6. publish snapshot (positions, car states, dirty rooms) for the renderer
```

## Concurrency (planned)

A single `SimulationHost` owns the world and runs ticks off the main thread. The main
thread only sends commands and receives immutable snapshots. Pure queries
(pathfinding on an immutable navigation graph, statistics) may fan out to a task
group; results are applied in a deterministic order at a tick boundary.
