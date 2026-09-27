# Game Design — Skyline Architect

Working title: **Skyline Architect**. An original vertical city/building management
simulation. Inspiration is the *fantasy* of growing a living tower; mechanics, look,
terminology and interface are our own.

## Pillars

1. **A living cross-section.** A realistic architectural side cutaway in which every
   person is simulated, every room is furnished, and the building visibly works.
2. **Vertical logistics is the puzzle.** Moving thousands of people up and down —
   elevator banks, sky lobbies, stairs, escalators — is the core optimization challenge.
3. **Honest systems.** Every number has a traceable origin: rent comes from tenants
   who chose your building for reasons you can inspect; vacancy emerges from the
   simulation, not from a dice roll.
4. **From one plot to an empire.** Start with a single lot and a foundation; grow to
   multiple towers across cities with different economies.

## Player fantasy & loop

Short loop (minutes): build space → tenants/visitors arrive → watch flows →
spot congestion/complaints → adjust (elevators, amenities, rents).
Mid loop (hours): expand upward/downward, unlock systems, manage cash & loans,
respond to events. Long loop: reputation, new properties, new cities, scenarios.

## Terminology (original to this game)

| Term | Meaning |
|------|---------|
| Plot | A property's buildable land: frontage (columns), basement limit, soil |
| Module | 1 m horizontal placement unit |
| Bay | Structural span, 8 modules; columns sit on bay lines |
| Floor | 4 m storey; 0 = ground (“G”), negative = basements (“B1”…) |
| Grade | Ground level, y = 0 |
| Core | Vertical circulation zone (shafts, stairs) — Phase 2+ |
| Sky lobby | Transfer floor between express and local elevators — Phase 7 |

## Visual direction

Realistic, clean, modern, architectural, detailed; never cartoon. Palette: muted
natural materials (concrete, steel, glass, soil strata), blueprint-cyan grid overlay,
restrained accent colors for UI and warnings. See GRAPHICS.md.

## Construction model (Phase 2+)

Free construction on the grid: floors (slabs spanning columns), walls, corridors,
doors, stairs, escalators, elevator shafts, rooms. Structural rules keep towers
plausible (floors need support below; basement depth limited by plot; foundations
determine achievable height — Phase 10 ties this to structure capacity). No hard floor cap.

## Room categories (data-driven)

Residential, office, retail, food, hotel, entertainment, health/fitness, services,
infrastructure — see the brief. Each room type is a JSON definition: size in modules/
floors, cost, rent range, capacity, schedule profile, noise/prestige emission, utility
demand, furniture layout recipe, unlock requirement. Engine code never switches on
room type ids.

## People

Individually simulated persons with identity, household, job, home, schedule, needs
(energy, hunger, entertainment…), mood, preferences. Far-away people are simulated
at lower fidelity but remain logically correct (SIMULATION.md).

## Economy (Phase 9)

Ledger-based: every transaction has a source entity and a reason. Income: rents,
hotel, parking, entertainment, services. Expenses: construction, wages, maintenance,
utilities, cleaning, security, loans, taxes. Bankruptcy is possible.

## Modes

Sandbox and data-driven scenarios (e.g. 5,000 inhabitants with average elevator
wait < 60 s while profitable).

## Speeds

Pause, 1×, 2×, 4×, 10×. Faster speeds run more fixed simulation ticks per real
second; they never scale the tick length (deterministic across speeds).

## Phase 1 player experience (current)

The player opens the game to a sandbox start: a 48 m lot in the fictional city of
Port Calder. The lot is shown in section: street-level pavement, soil strata down to
bedrock, and a prepared foundation (retaining walls, raft slab, bored piles, grade
slab with starter bars). The player can pan and zoom from a whole-city-block view
down to individual meters, toggle the architectural grid and inspect grid cells.
No construction or simulation yet.

## Phase 2 player experience (current)

The player builds on the prepared foundation with a palette generated from content:
**Floor** (drag across columns; upper floors must rest on the floor below, up to 2 m
cantilever; basements only within the excavation), rooms (lobby, corridor, office,
apartment, mechanical, parking — each with width limits and allowed floors) and shafts
(stairwell, elevator shaft — drag vertically across floors), and **Demolish** (rooms, or an
empty top floor, with a 40 % refund). A live ghost shows green with size and cost, or red
with the reason. Undo/redo, quicksave, load and autosave work. Construction cost is shown
but not yet charged; elevators have shafts but no cars; rooms have finishes but no furniture.

## Phase 3 player experience (current)

Every room the player places is furnished automatically from content layouts that adapt to
the room's width: offices fill with workstations and gain a meeting table when wide enough,
studios get a kitchenette or a full kitchen and (when wide) a bathroom, lobbies a reception
desk, parking levels parked cars. Zoomed out, towers show a glass façade; zooming in reveals
the furnished cutaway. People arrive in Phase 4.

## Phase 4 player experience (current)

Rooms come alive: offices get workers (0.3 per metre of width) and studios two residents
each. A day starts at 06:00; residents leave for work in the morning and return in the
evening, office workers arrive around 08:15, go out for lunch and leave around 17:15 — all
walking in from the street, through the entrance and up the stairwell. The clock runs at
1× (a day ≈ 60 real minutes) up to 10×; Space pauses. Floors without stairs are
unreachable and reported. No money, needs or elevators yet.
