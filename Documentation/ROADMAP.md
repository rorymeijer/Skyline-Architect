# Roadmap

Every phase ends BUILDABLE, TESTABLE, RUNNABLE, with screenshots inspected and
documentation updated (quality gates: see CLAUDE.md). Status per phase is tracked in
`Development/STATUS.md`.

## Changes vs. the original phase list (and why)

| Change | Reason |
|--------|--------|
| Versioned **local save/load moves to Phase 2** (iCloud stays Phase 18) | The first playable milestone requires save → quit → reload. Save format versioning must exist from the start, and it is cheapest to establish while the model is small. |
| **Simulation clock + speed controls move to Phase 4** | People are the first system that needs time; construction is instantaneous. Speed controls must exist before elevators so determinism across speeds is tested early. |
| **Basic day/night lighting moves into Phase 9** (full lighting stays Phase 12) | The visual vertical slice (§39) requires a day/night difference and lit windows. Phase 12 then becomes the full lighting system (interior light sources, sunrise/sunset grading, energy link). |
| **New milestone M1 “First Playable” = end of Phase 9** | Phases 2–9 are the vertical slice; nothing after M1 starts before M1 passes its checklist. |
| **Performance budgets are checked every phase**, Phase 19 is the dedicated deep pass | Scale is a first-class requirement; waiting until Phase 19 risks unfixable architecture. |
| Modding (Phase 17) is data-driven **from Phase 1** | Content already loads from JSON packs; Phase 17 adds pack merging, overrides, validation UI. |

## Phases

### Phase 0 — Project bootstrap ✅ (2026-09-26)
Xcode project (multiplatform app target) + `SkylineKit` package; documentation set;
CI (Linux package tests, macOS app build, iPad simulator build, screenshot capture).

### Phase 1 — Renderer, camera, architectural grid ✅ (2026-09-26)
Window, SpriteKit world, camera (smooth zoom toward cursor, pan, inertia, limits,
trackpad/mouse/keyboard, iPad pinch/pan), LOD bands, tile-based static rendering with
culling, plot with soil cross-section, first foundation (retaining walls, raft, piles,
grade slab, starter bars), architectural grid with adaptive density, developer HUD,
screenshot capture. **No construction, no simulation.**

### Phase 2 — Construction + saves ✅ (2026-09-27)
Command-based construction (floors, slabs, walls, corridors, doors, stairs shafts, room
shells, basements) with validation from data (build rules), demolition, undo for the
current session. Cost preview (not yet charged). Versioned local save/load + autosave
skeleton, migration test harness. Room definitions from JSON.

### Phase 3 — First furnished rooms ✅ (2026-09-27)
Procedural art pipeline expansion: façade, windows, doors, interior walls, furniture
recipes (apartment: bed, sofa, kitchen, bath; office: desks, chairs, computers, meeting
table, cabinets). Room interior composition from data (furniture layouts per room
definition). LOD: exterior façade when zoomed out, cutaway interiors when zoomed in.
Asset Requirements document for art that procedural generation cannot reach.

### Phase 4 — Basic people simulation ✅ (2026-09-27)
Simulation clock (fixed tick, pause/1×/2×/4×/10× by running more ticks, never by
scaling dt), `SimulationHost`, agents with identity/needs/schedule skeleton, spawn at
lobby, walk on floors, enter/leave rooms. Render snapshots + interpolation, agent
sprites with simple animation, render LOD for agents.

### Phase 5 — Navigation / pathfinding ✅ (2026-09-27)
Hierarchical graph: per-floor walk graphs + vertical transport graph (stairs now,
elevators next); route cache with invalidation on construction; path debug overlay.

### Phase 6 — First functioning elevators ✅ (2026-09-27)
Shafts, cars, served floors, capacity, speed/acceleration, doors & boarding time,
hall calls, queues on floors, visible boarding/riding/leaving. One simple dispatch
strategy (collective control).

### Phase 7 — Advanced elevator queues & dispatch ✅ (2026-09-27)
Delivered: banks, strategy per bank (collective, zoning, destination), express/local with sky-lobby
transfers, statistics, traffic overlay, patience. Deferred: service/freight cars → Phase 10 (they
need staff); jerk-limited motion and mid-trip re-targeting → Phase 19/20.

Strategy interface with several algorithms (collective, zoning, destination dispatch),
banks, express/local, sky lobbies/transfers, service/freight cars, statistics (avg/max
wait, passengers/hour, abandonment), elevator traffic overlay.

### Phase 8 — Tenants + schedules ✅ (2026-09-27)
Delivered: tenant types, deterministic market (rent, access with measured elevator waits, noise,
view), reviews and move-outs, varied schedules, inspector and leasing panel. Amenities arrive with
retail/services room types; rent is charged in Phase 9.

Households and businesses choose space (rent, accessibility, elevator wait, noise,
amenities); daily schedules generate traffic (morning up-peak, lunch, evening down-peak).

### Phase 9 — Economy + basic day/night → **M1 First Playable** ✅ (2026-09-27)
Delivered: ledger, charged construction, daily closing, loans, rent level, bankruptcy, economy panel,
basic day/night, main menu. M1 checklist: see `Development/STATUS.md`.

Ledger with traceable transactions (rent, wages, utilities, maintenance, loans,
interest, taxes), configurable rents, demand from city data, bankruptcy, economy panel.
Basic day/night: sky, sun/ambient tint, lit windows at night. Main menu (new game,
continue, load). **M1 checklist = §38 of the brief (launch → … → reload & continue).**

### Phase 10 — Utilities + maintenance ✅ (2026-09-27)
Delivered: utilities with capacity/range/failure, wear and cleanliness, jobs, janitors and technicians
who travel (service elevators), wages, services criterion, panel and overlay. Waste and energy prices
later.

Abstracted distribution (electricity, water, HVAC, waste, internet) with capacity,
equipment rooms, failures; wear, cleanliness, repair jobs with staff who travel.

### Phase 11 — Progression / reputation ✅ (2026-09-27)
Delivered: reputation (daily assessment, demand), building classes C/B/A/Prime with requirements,
unlocks of room types, height and tenant types by class in the new standard game (sandbox keeps
everything), standing panel, promotion banner, locked tools. Scenario goals follow in Phase 16.

Levels + reputation unlocking systems in order of simulation complexity.

### Phase 12 — Full day/night + lighting ✅ (2026-09-28)
Delivered: lighting model per room type (content), energy metered and billed, lights need power,
colour grading, coloured room light, façade window panes, night emission layer (city, neighbours,
street lamps). Player lighting policies and real falloff/shadows later.

Interior light sources, window emission, sunrise/sunset grading, energy link.

### Phase 13 — Weather
Rain, storms, snow, heat, fog; visuals + effects on energy, visitors, maintenance.

### Phase 14 — Events & emergencies (incl. fire)
Data-driven events; fire origin/spread/smoke, alarms, evacuation via stairs, blocked
elevators, suppression, responders using the shared navigation.

### Phase 15 — Multiple properties & cities
Property purchase, city selection, per-city economy variables, empire overview.

### Phase 16 — Scenarios
Data-driven objectives, win/lose conditions, scenario browser.

### Phase 17 — Modding / content system
Pack discovery, merge/override rules, validation reporting, mod manager UI.

### Phase 18 — iCloud persistence
Optional iCloud Drive save sync with conflict handling.

### Phase 19 — Large-scale performance
Profiling pass against targets (hundreds of floors, thousands of rooms/people).

### Phase 20 — Visual polish
Art pass, animation, particles, UI polish, accessibility.
