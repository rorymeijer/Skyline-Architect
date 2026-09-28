# Changelog

All notable changes. Versions follow `MARKETING_VERSION` of the app.

## [0.15.0] — Phase 15: Multiple properties & cities

### Added
- **Cities**: Harrowgate (dear, busy, granite) and Saltmere (cheap, quiet, marsh) join Port
  Calder, each with its own market (rent, construction, demand), ground and skyline.
- **Land for sale**: plots with a price and a ready foundation; buying adds the city and
  property (ledger category `land`).
- **Markets per city**: prospects per city, scaled by its demand and reputation; rents and
  construction costs follow the city.
- **Estate panel** (⌥⌘K): all properties with their numbers, switching between them, land
  for sale.
- **Save format 12** (+ migration, legacy plot matching, golden fixture).

## [0.14.0] — Phase 14: Events & emergencies

### Added
- **Fire**:
  - rooms ignite rarely (worn rooms and plant more often);
  - fires grow and spread to neighbouring rooms;
  - the new **fire control room** sprinkles every room within ±15 floors;
  - the fire brigade arrives after 16 minutes.
- **Evacuation**:
  - everybody leaves by the stairs only (no elevators) and nobody enters while it burns;
  - afterwards people return as their schedules say.
- **Aftermath**:
  - repair bill and repair jobs;
  - destroyed units lose their tenants;
  - reputation −8;
  - soot until repaired.
- **Weather incidents**: storm damage, power outages (the electrical plant fails), burst
  pipes in frost.
- **UI**: fire alert with *Show*, incidents panel (⌥⌘I), flames, smoke, sprinkler spray,
  fire engines, Debug "Start a Fire" tool.
- **Save format 11** (+ migration, golden fixture).

## [0.13.0] — Phase 13: Weather

### Added
- **Seasons and weather** from `weather.json`:
  - seven kinds (clear, overcast, rain, storm, snow, heatwave, fog) drawn each morning from the city seed, with a forecast;
  - temperatures per season.
- **Effects**:
  - storms and snow keep prospective tenants away;
  - bad weather wears and dirties the building faster;
  - heating and cooling scale the utilities bill with the temperature.
- **Visuals**:
  - weather colour grade, fog veil;
  - rain and snow particles, lightning;
  - snow on roofs and the street, wet paving;
  - weather chip with the forecast.
- **Save format 10** (+ migration, golden fixture).

## [0.12.0] — Phase 12: Full day/night + lighting

### Added
- **Lighting model** per room type (colour, occupied/empty level, watts, quiet hours) in
  `rooms.json`; homes switch off one by one from 22:30; lights need electricity.
- **Energy**: lighting load metered hourly and billed at the daily closing
  (`Lighting — N kWh`); load and today's meter in the facilities panel.
- **Rendering**: colour grading through the day (rose sunrise, golden hour, amber sunset,
  blue night), coloured room light, façade window panes when zoomed out, city and
  neighbour windows at night, street lamps.
- **Save format 9** (+ migration, golden fixture).

### Fixed
- City lights never shine through the tower or the neighbours.

## [0.11.0] — Phase 11: Progression / reputation

### Added
- **Reputation** per building (0…100), assessed each morning from tenant satisfaction,
  services, elevator waits and occupancy; move-outs cost points; reputation scales how
  many prospective tenants come by.
- **Building classes** C → B → A → Prime with population, reputation and room
  requirements; promotions at the daily closing, never demoted.
- **Standard game**: room types (service elevator, express elevator, sky lobby) and
  building height unlock with the class; premium tenant types wait for it. The sandbox
  keeps everything unlocked.
- **UI**: Standing panel (⌥⌘P), class and reputation in the status pill, locked build tools,
  promotion banner, New Game / New Sandbox in the main menu.
- **Save format 8** (+ migration, golden fixture).

## [0.10.0] — Phase 10: Utilities + maintenance

### Added
- **Utilities** (electricity, water, climate, data) supplied by equipment rooms with
  capacity and floor range; new electrical and telecom rooms; equipment can fail.
- **Upkeep**: wear and cleanliness per room; cleaning and repair jobs.
- **Staff**: janitors and technicians, hired per building, paid daily, working a
  07:00–19:00 shift; they travel to jobs by stairs and elevators, including new
  staff-only **service elevators**.
- **Tenants care**: services criterion in appraisals; units without a utility are unusable.
- **UI**: Facilities panel (⌥⌘F), services overlay (⌥⌘U), utilities and upkeep in the
  inspector, staff coveralls.
- **Save format 7** (+ migration, golden fixture).

### Fixed
- People without a daily schedule (staff) now go through elevator queues correctly.

## [0.9.0] — Phase 9: Economy + basic day/night → M1 First Playable

### Added
- **Ledger** with traceable transactions (category, detail, building/room/tenant), daily
  totals, starting capital.
- **Construction is paid**: cost charged on build, exact refund on undo, refused when cash
  is short (preview shows *not enough money*); demolition refunds 40 %.
- **Daily closing**: rent from every tenant, maintenance, utilities, loan interest;
  bankruptcy after seven days in the red.
- **Loans** (borrow/repay) and **rent level** per building (affects appraisal and demand).
- **Economy panel** (⌥⌘M); cash in the status pill.
- **Day/night**: ambient tint and lit rooms at night.
- **Main menu** (Continue newest save, New Game, Load) and bankruptcy screen.
- **Save format 6** (+ migration, golden fixture).

## [0.8.0] — Phase 8: Tenants + schedules

### Added
- **Tenants**: households and businesses with names, members, agreed rent and
  satisfaction; six tenant types in `tenants.json`; rooms gain rent and noise.
- **Rental market**: hourly prospects appraise vacant units (rent, access with measured
  elevator waits, noise, view), sign or decline with a reason; daily reviews, move-outs.
- **Schedules**: early and late offices, late commuters and retirees — traffic peaks spread.
- **UI**: click a room to inspect it (tenant, criteria, or why a vacancy stays empty);
  tenant names on rooms; Leasing panel (⌥⌘L) with occupancy, rent roll and market log;
  developer "Lease All Vacant Units".
- **Save format 5** (+ migration adopting existing people, golden fixture).

### Changed
- New buildings start empty; rooms are no longer filled automatically.

## [0.7.0] — Phase 7: Advanced elevator queues & dispatch

### Added
- **Elevator banks**: adjacent shafts of a type share hall calls; each call is assigned to a
  car when the person reaches the landing (they walk to that car's doors).
- **Dispatch strategies** per bank: collective (fastest estimated arrival), zoning (a floor
  zone per car), destination (group people going to the same floor).
- **Express shafts** stopping only at their ends, **sky lobby** room type, and the
  `demo-skytower` blueprint (low bank of 3, express to floor 21, upper bank of 2).
- **Patience and abandonment**: people who wait too long take the stairs when that is a
  short walk; counted per car.
- **Statistics** per car and bank: boardings, average/max wait, stops, abandonments,
  passengers per hour.
- **Traffic overlay** (⌥⌘T) with queue badges, car loads and bank labels; **Elevator Banks**
  panel (⌥⌘E) to choose the strategy and read the statistics.
- **Save format 4** (+ migration, golden fixture).

## [0.6.0] — Phase 6: First functioning elevators

### Added
- **Elevator cars**, one per elevator shaft: capacity, speed and acceleration
  (trapezoidal motion), door and boarding times from `elevators.json`.
- **Queues and hall calls**: people walk to the landing, wait in order, board, ride and
  alight; **collective control** dispatch serves calls in the direction of travel.
- **Routing** chooses stairs or elevator by expected time (stairs for 1–2 storeys).
- **Rendering**: moving cabs with sliding doors and hoist rope; people queue at the
  landing doors and stand inside cabs. HUD rows for cars, riders, waiting and longest wait;
  elevator links in the navigation overlay.
- **Save format 3** (+ migration, golden fixture) with cars and waiting/riding people.
- `demo-highrise` blueprint (21 storeys, one full-height elevator) for captures and tests.

### Changed
- The event queue handles cars and people; re-planning after construction covers people
  waiting for or riding a removed elevator.

## [0.5.0] — Phase 5: Navigation / pathfinding

### Added
- **Navigation graph** per building: stair-shaft portals on every served floor, walk links
  along floors, storey links through shafts; deterministic Dijkstra. Routes may **transfer**
  between stairwells (walk across a floor to another shaft).
- **Route cache** keyed by exact trip ends; graph and cache are rebuilt only when floor
  plates or transport shafts change (structure signature). The cache never changes
  outcomes (tested against a cache-less run).
- **Re-planning after construction:** trips through removed stairs or floors continue from
  the traveller's current position; with no route left they leave and are marked unreachable.
- **Developer tools:** navigation overlay (⌥⌘N, Debug builds) with portals, links and live
  routes; HUD rows for path queries, cache hit rate, failures, graph size/builds, unreachable.
- Scale test: 200 floors, 1 194 people, one day at 10× in 68 ms (release).

### Changed
- `RoutePlanner` plans through the graph (replaces the Phase 4 single-stairwell planner).
- Event queue and Dijkstra share one `MinHeap`.

## [0.4.0] — Phase 4: Basic people simulation

### Added
- **Simulation clock and speeds:** 1 tick = 1 game second; pause / 1× / 2× / 4× / 10× run
  0 / 24 / 48 / 96 / 240 ticks per real second; results identical at every speed (tested).
- **People:** workers and residents with generated names, ages, schedules
  (`schedules.json`, `names.json`), homes/workplaces from room occupancy; event-driven
  engine with analytic trips (street → entrance → stairwell → room), unreachable detection.
- **Population sync** after construction and on load (Phase 8 tenants will replace it).
- **Rendering:** procedural person figures (4-frame walk cycle, skin/hair/clothing variety,
  business vs. casual), exact interpolation at fractional ticks, culling, render LOD
  (not drawn below 3.5 pt/m; still simulated).
- **UI:** clock, speed buttons, population pill; Space / 1–4 shortcuts; HUD rows for drawn
  and simulated people and simulation time per frame.
- **Save format 2** with v1→v2 migration and a v2 golden fixture with people mid-trip.
- `skyline-snapshot --time HH:MM` simulates before rendering and draws people.

## [0.3.0] — Phase 3: First furnished rooms

### Added
- **Data-driven furniture:** `materials.json` (60 materials), `furniture.json` (31 vector
  recipes: workstation desk, monitor, office chair, filing cabinet, meeting set, whiteboard,
  printer, doors, kitchen, kitchenette, fridge, double bed, nightstand lamp, sofa, TV unit,
  bathroom pod, wardrobe, floor lamp, reception desk, lobby sofa, directory, bench, fire
  extinguisher, plants, AHU, pump set, electrical panel, parked cars with colour variants …).
- **Interior layouts** (`interiors.json`) for offices, studio apartments, lobbies, corridors,
  mechanical rooms and parking; deterministic `LayoutResolver` (anchors, width conditions,
  repeat groups, collision avoidance, seeded variants). Mods can add furniture/layouts.
- **Exterior façade LOD:** curtain-wall façade below 6 px/m, furnished cutaway above,
  via per-item detail bands (`DrawItem.maxDetail`).
- `Documentation/ASSET_REQUIREMENTS.md`.

### Fixed
- Placeholder plant boxes no longer drawn in furnished mechanical rooms.

## [0.2.0] — Phase 2: Construction + saves

### Added
- **Construction model:** floor plates per building (setbacks), rooms and vertical shafts as
  one entity type, `BuildCommand`s validated by a data-driven `ConstructionEngine`
  (footprint, excavation, support/cantilever, width/height/level limits, overlap), costs and
  refunds, demolition of rooms and empty top floors; no floor limit (300-storey test).
- **Undo/redo** via inverse commands (⌘Z / ⇧⌘Z), session construction cost (not charged
  until the economy phase).
- **Content:** `rooms.json` (lobby, corridor, stairwell, elevator shaft, small office, studio
  apartment, mechanical room, parking level), `build-rules.json`, `blueprints.json`
  (demo tower); the build palette is generated from content.
- **Persistence module:** versioned save envelope, migration harness, integrity-checked
  loading (inconsistent saves are refused), atomic save store, quicksave (⌘S), Load Game
  sheet (⌘O), rotating autosaves every 2 minutes; golden format-1 fixture test.
- **Rendering:** layered composition (site + buildings), dirty-rect tile invalidation with
  stale tiles kept until replaced; storey shells, slabs, columns, end façades with glazing,
  roofs with parapets, basement retaining walls, per-appearance room finishes (lights,
  doors, skirting, stone panels, plant, parking markings), stairwells with flights and
  landings, hoistways with rails and landing doors; room labels.
- **Interaction:** build palette, drag placement with live green/red/amber ghost and a
  label (name · size · cost or the refusal reason), F/X/Esc keys, iPad tap/drag placement.
- **CI:** scripted capture of 8 construction/save/undo scenarios; latest captures are
  committed as JPEGs to development branches (`Development/Screenshots/_ci-latest`).

## [0.1.0] — Phase 1: Renderer, camera, architectural grid

### Added
- **Phase 0 bootstrap:** multiplatform Xcode project (macOS + iPadOS) with a local
  `SkylineKit` package, documentation set, decision log, roadmap, CI (Linux + macOS).
- **Core model:** `GameWorld` → `City` → `Property` (plot, soil strata) → `Building`
  (footprint, foundation) with validated references, typed IDs, insertion-ordered stores,
  JSON round-trip; architectural grid (1 m modules, 4 m floors, 8-module bays, no floor limit).
- **Content:** base content pack (`Port Calder`, `Quay Street Lot`, sandbox start) with
  validation of ids, references and format version; `NewGameFactory`.
- **Camera:** smooth zoom toward cursor/anchor (log-space, frame-rate independent),
  drag pan with inertia, trackpad pan/pinch, mouse wheel, keyboard (WASD/arrows, Q/E),
  zoom limits 0.35–96 pt/m, bounds clamping, presets (⌘1–⌘4, ⌘0).
- **LOD:** five detail bands with hysteresis; tile level follows zoom × backing scale;
  per-item detail thresholds hide fine grain when zoomed out.
- **Rendering:** drawing IR + spatial index; background CoreGraphics tile rasterization
  (512 px, 1 px bleed, LRU cache, fallback levels); world-anchored sky gradient.
- **Procedural art:** soil strata with undulating interfaces and per-material grain,
  paved grade, foundation section (diaphragm walls, raft with rebar, bored piles,
  basement back wall with pour lifts and tie holes, grade slab, starter bars),
  neighbouring buildings, distant skyline.
- **Architectural grid overlay:** density-adaptive module/bay/floor lines, grade line,
  dashed plot boundary, floor labels (G, 1…, B1…), hover cell highlight.
- **Developer HUD:** FPS, frame/update time, nodes, tiles, raster time, memory, zoom,
  LOD, camera, cursor cell (⌥⌘D).
- **Tools:** `skyline-snapshot` SVG design previews; Debug-only in-app screenshot
  capture (`--capture-screenshots`), run by CI.
