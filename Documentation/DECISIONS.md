# Decision Log

Format: DATE · DECISION · CONTEXT · ALTERNATIVES · REASON · CONSEQUENCES.

---

## D-001 — Xcode app project + local Swift package
- **Date:** 2026-09-26
- **Decision:** One Xcode project (`SkylineArchitect.xcodeproj`) with a single multiplatform app target (macOS + iPadOS). All engine code lives in a local Swift package `Packages/SkylineKit` split into modules.
- **Context:** Must be buildable/editable in Xcode; engine must be testable without rendering; macOS + iPadOS share engine code.
- **Alternatives:** (a) package-only (Xcode can open it, but SPM cannot produce a proper app bundle with Info.plist/iPad settings); (b) separate app targets per platform; (c) XcodeGen/Tuist (third-party tooling).
- **Reason:** Module boundaries are enforced by the compiler; package tests run with `swift test` anywhere; one multiplatform target avoids duplicated build settings while allowing `#if os(macOS)` platform-specific interaction files.
- **Consequences:** Platform-specific UI code lives in `App/` behind `#if os(...)`. If macOS and iPad UIs diverge a lot later, split into two targets sharing `App/Shared`.

## D-002 — Engine modules import only Foundation and build on Linux
- **Date:** 2026-09-26
- **Decision:** `SkylineCore`, `SkylineContent`, `SkylinePresentation`, `SkylineSnapshot` must not import Apple UI/graphics frameworks and must build/test on Linux.
- **Context:** Hard separation of model/simulation from rendering/UI (brief §30); development partially happens in a Linux container; CI Linux runners are cheap and fast.
- **Alternatives:** Allow CoreGraphics types (CGPoint/CGRect) in the model.
- **Reason:** Own `Vec2`/`Rect` types remove ambiguity (CGFloat vs Double), keep the model portable and make the boundary compiler-enforced.
- **Consequences:** Small conversion code in the App layer (`Vec2` ↔ `CGPoint`).

## D-003 — Drawing IR + tiled rasterization for static art
- **Date:** 2026-09-26
- **Decision:** Procedural art is produced as a platform-neutral vector drawing IR (`Drawing`: rects, polygons, polylines, ellipses; solid/linear-gradient paints; per-item minimum detail) in `SkylinePresentation`. The App rasterizes it with CoreGraphics into quadtree tiles (512 px + 1 px bleed) shown as `SKSpriteNode`s. `skyline-snapshot` renders the same IR to SVG.
- **Context:** Need realistic, detailed, *scalable* rendering of huge buildings; SKShapeNode is slow and aliasing-prone at scale; art must be testable and previewable headlessly.
- **Alternatives:** (a) SKShapeNode per primitive; (b) hand-built SKSpriteNodes per element; (c) Metal shaders directly; (d) pre-made bitmap assets only.
- **Reason:** Tiles bound GPU cost by screen area rather than building size, give automatic LOD (detail thresholds per tile level), and cache well. IR keeps art logic testable and moddable. Bitmap sprites/sheets remain possible later for characters/animation (AssetPipeline).
- **Consequences:** Static changes (construction) must invalidate affected tiles (Phase 2: dirty-rect invalidation). Animated/dynamic elements (people, elevator cars) will be sprites, not tiles.

## D-004 — Scene = viewport; camera transform on a `worldRoot` node
- **Date:** 2026-09-26
- **Decision:** The SKScene size equals the view size in points. The camera is applied as scale/position of a `worldRoot` node instead of `SKCameraNode`.
- **Context:** Screen-space overlays (grid, labels, HUD) and in-app screenshot capture.
- **Alternatives:** SKCameraNode with overlay nodes as camera children.
- **Reason:** Scene coordinates are screen points ⇒ `SKView.texture(from: scene)` captures exactly what the player sees; conversion math lives in the tested `Camera2D`.
- **Consequences:** Parallax, if added, is done by offsetting layer nodes manually.

## D-005 — Flat, insertion-ordered entity stores with typed 32-bit IDs; per-property coordinates
- **Date:** 2026-09-26
- **Decision:** `GameWorld` stores cities, properties, buildings in `EntityStore<ID, Value>` (array + index), with back references for the hierarchy. IDs are `EntityID<Tag>` (UInt32) from a world counter. Each property has its own local meter coordinate space.
- **Context:** Multiple buildings/properties/cities; determinism; save size; scale.
- **Alternatives:** Deeply nested value types; dictionaries; UUIDs; one global coordinate space.
- **Reason:** Deterministic iteration (Swift dictionaries are randomly ordered per process), compact IDs, simple mutation, stable save output.
- **Consequences:** Referential integrity is validated by model methods and tests.

## D-006 — Swift 6 language mode for the package, Swift 5 mode for the app target
- **Date:** 2026-09-26
- **Decision:** Package: Swift tools 6.0, Swift 6 language mode (strict concurrency). App: `SWIFT_VERSION = 5.0`.
- **Context:** SpriteKit/AppKit/UIKit are main-thread frameworks whose concurrency annotations vary across SDK versions; overriding `SKScene.update(_:)` etc. from `@MainActor` types produces SDK-dependent errors.
- **Alternatives:** Swift 6 everywhere.
- **Reason:** Strict checking where our threading logic lives (engine, future simulation host); pragmatic stability for the thin UI shell.
- **Consequences:** Revisit when Apple frameworks are fully annotated. App code must still marshal background work (tile rasterization) explicitly to the main queue.

## D-007 — Content as declarative JSON packs from Phase 1
- **Date:** 2026-09-26
- **Decision:** Cities, plots and game starts are defined in JSON inside a base content pack (package resource). Loader validates ids and references.
- **Context:** Brief §8, §27: data-driven content, future mods, no giant switches.
- **Alternatives:** Swift literals now, JSON later.
- **Reason:** Cheap to start now; prevents engine code from growing content assumptions.
- **Consequences:** Every new content type needs a definition struct + validation + tests.

## D-008 — Verification through GitHub Actions (Linux + macOS), in-app screenshot capture
- **Date:** 2026-09-26
- **Decision:** CI runs package tests on Linux and macOS, builds the app for macOS and iPad Simulator, then launches the macOS app with `--capture-screenshots` which renders deterministic camera presets and writes PNGs uploaded as artifacts.
- **Context:** Development sessions may run in a Linux container without Xcode; the brief mandates real screenshots of the running game.
- **Alternatives:** Only local screenshots by the developer; XCUITest screenshots; `screencapture` (needs Screen Recording permission).
- **Reason:** In-app capture of the SKView (scene = viewport, D-004) needs no OS permission and captures real rendered output. The SwiftUI HUD is composited on top from the real view via `ImageRenderer`.
- **Consequences:** Capture code is Debug-only. The HUD in captures is rendered separately from the window server (documented in each screenshot README).

## D-009 — Roadmap re-ordering
- **Date:** 2026-09-26
- **Decision:** Local saves → Phase 2; sim clock/speeds → Phase 4; basic day/night → Phase 9; M1 First Playable at end of Phase 9. See ROADMAP.md.
- **Reason:** The first playable milestone and visual vertical slice require these earlier than the original numbering.

## D-010 — Xcode 16 synchronized folders (project objectVersion 77)
- **Date:** 2026-09-26
- **Decision:** `App/` is a `PBXFileSystemSynchronizedRootGroup`.
- **Reason:** Files added to `App/` join the target automatically; the project file stays tiny and merge-friendly, and can be edited without Xcode.
- **Consequences:** Requires Xcode 16 or newer.

## D-011 — Swift Testing for automated tests
- **Date:** 2026-09-26
- **Decision:** Use the Swift Testing framework (`import Testing`) for package tests.
- **Reason:** Ships with Swift 6 toolchains on macOS and Linux; parameterized tests suit simulation cases.

## D-012 — SwiftUI-drawn chrome controls
- **Date:** 2026-09-26
- **Decision:** Floating game controls use custom `ButtonStyle`s and plain SwiftUI shapes instead of platform-styled `Button`/`Menu`/materials.
- **Context:** The first CI capture showed AppKit-backed controls as placeholders in `ImageRenderer` output.
- **Alternatives:** Capture the window through ScreenCaptureKit (needs Screen Recording permission, unavailable on CI).
- **Reason:** Captures must show what the player sees; a consistent game-styled HUD is also the desired look.
- **Consequences:** Native macOS menus remain for app-level commands; in-world chrome is custom-drawn.

## D-013 — Undo by inverse commands
- **Date:** 2026-09-27
- **Decision:** `ConstructionEngine.apply` returns an inverse `BuildCommand`; `ConstructionHistory` keeps inverse/redo stacks.
- **Context:** Session undo/redo for construction.
- **Alternatives:** World snapshots per step.
- **Reason:** Snapshots would also roll back simulation state once people, elevators and money exist; inverse commands touch only what the command changed and cost little memory.
- **Consequences:** Every new command kind needs an exact inverse and a round-trip test (see `HistoryTests`).

## D-014 — Walls, partitions, doors and façades are derived, not placed
- **Date:** 2026-09-27
- **Decision:** The player places floor plates and rooms/shafts; the art derives end façades with glazing, partitions between rooms, doors, retaining walls and roofs.
- **Context:** Brief §5 lists walls/doors/corridors as buildable. In a side cutaway, walls are fully determined by room boundaries and plate edges.
- **Alternatives:** Separate wall/door entities placed by hand.
- **Reason:** Removes tedious micro-placement and whole classes of invalid states (rooms without walls, doors to nowhere) without losing expressiveness; corridors are placeable room types.
- **Consequences:** If gameplay later needs explicit doors (security, fire doors), they become room attributes or edge entities derived from adjacency — revisit in Phase 5 (navigation) and Phase 14 (fire).

## D-015 — Layered composition with dirty-rect tile invalidation
- **Date:** 2026-09-27
- **Decision:** `SiteComposition` = static `site` layer + `buildings` layer recomposed after construction; tiles intersecting the command's dirty rect are marked stale and re-rendered in place.
- **Context:** Construction changes small regions; recomposing terrain grain every edit is wasteful and re-rasterizing all tiles would flash.
- **Reason:** Recomposing the buildings layer is cheap (thousands of items); only a handful of tiles re-render per edit.
- **Consequences:** Art must stay inside the dirty margin of the cells it belongs to (1 module / 1 floor), or the dirty rect must grow.

## D-016 — Persistence in its own module with a migration harness and golden fixtures
- **Date:** 2026-09-27
- **Decision:** `SkylinePersistence` (Foundation only) owns the save envelope, versioning, migrations and file store; format-1 golden fixture is committed and must always load.
- **Reason:** Keeps file formats out of the model, makes migrations testable on the untyped JSON tree, and guarantees old saves stay loadable or are refused explicitly.

## D-017 — Visual content types live in SkylinePresentation; SkylineContent depends on it
- **Date:** 2026-09-27
- **Decision:** `FurnitureDefinition`, `InteriorLayout`, `ArtCatalog` are defined in `SkylinePresentation`; `SkylineContent` decodes and validates them from the pack.
- **Context:** Furniture and layouts are content (moddable JSON) but purely visual; the model (`SkylineCore`) must not know about them.
- **Alternatives:** Put them in Core (pollutes the model); a separate art-content module (overkill now); let Presentation load JSON itself (duplicate loader/validation).
- **Reason:** One loader and one validation path for all content; the model stays free of visual data. No cycle: Presentation → Core, Content → Core + Presentation.
- **Consequences:** When simulation needs furniture semantics (e.g. desks = workplaces, beds = residents), capacity belongs in `RoomSpec` (Core), not in the visual recipe.

## D-018 — Level of detail through per-item detail bands
- **Date:** 2026-09-27
- **Decision:** `DrawItem` has `minDetail` and `maxDetail`; alternatives (exterior façade vs. cutaway) are drawn into the same composition with complementary bands; tiles pick items by their raster density.
- **Alternatives:** Separate compositions per LOD; switching node trees in SpriteKit by zoom.
- **Reason:** LOD becomes automatic per tile level, needs no renderer logic, and works identically in the SVG preview tool and tests.
- **Consequences:** The switch point depends on pixel density (Retina switches at lower zoom). Items must not straddle both bands unintentionally.

## D-019 — Analytic trips instead of per-tick movement
- **Date:** 2026-09-27
- **Decision:** A person's trip is stored as legs with absolute start/end ticks; position is a pure function of time. Only arrivals and schedule goals are events.
- **Alternatives:** Integrate every agent every tick; snapshot buffers for rendering interpolation.
- **Reason:** Thousands of walking people cost nothing between events; rendering gets exact sub-tick positions; saves capture motion exactly; determinism is easy to prove.
- **Consequences:** Anything that changes a trip mid-way (construction, elevators waiting) must re-plan explicitly — Phase 5/6 add re-planning and queue waits as events.

## D-020 — 1 tick = 1 game second; speed = ticks per real second
- **Date:** 2026-09-27
- **Decision:** 24 ticks per real second at 1× (a game day lasts 60 real minutes); faster speeds only run more ticks per frame (max 480 per frame).
- **Reason:** Second resolution suffices for walking and (later) elevator stops; batch independence makes speeds deterministic.
- **Consequences:** At 10× the engine runs 240 ticks/s — fine while event-driven; profile again with thousands of people (Phase 19).

## D-021 — Phase 4 population sync and single-stairwell routing are stand-ins
- **Date:** 2026-09-27
- **Decision:** Rooms are occupied automatically from `RoomSpec.occupancy`; routes use one stairwell between two floors.
- **Reason:** Delivers visible, believable traffic now without pre-empting Phase 5 (navigation graph) and Phase 8 (tenant choice, rent, vacancy).
- **Consequences:** Both are replaced, not extended; their tests describe behaviour the replacements must keep (occupancy counts, reachability).

## D-022 — SwiftUI does not observe the live world
- **Date:** 2026-09-27
- **Decision:** `AppModel.world` is `@ObservationIgnored`; views read clock/population summaries refreshed at 4 Hz.
- **Reason:** The simulation mutates the world up to 240 times per second; observing it would re-evaluate SwiftUI views every frame.

## D-023 — Navigation over a portal graph; floors are implicit
- **Date:** 2026-09-27
- **Decision:** The graph's nodes are vertical-transport landings (portals), one per shaft and served floor; floors are not rasterized into walk cells. Portals on a floor are chained in x order. Dijkstra runs with a virtual source/target, ties broken by node index. Replaces the Phase 4 single-stairwell planner (D-021).
- **Alternatives:** Grid/cell A* per floor; a full two-level hierarchy with per-floor subgraphs and precomputed floor-to-floor tables.
- **Reason:** A floor plate is one contiguous 1-D walking surface, so walking between two points is exact and needs no search. The graph size is proportional to shafts × floors (209 portals for a 200-floor tower with 10 stair segments), cheap to rebuild on every structural change. Elevators slot in as a new edge kind.
- **Consequences:** Interior walls and doors do not obstruct walking (walls are derived art, D-014). If obstacles or partial plates appear later, floors gain their own segments without changing the vertical level.

## D-024 — Exact-key route cache; re-plan only invalidated trips
- **Date:** 2026-09-27
- **Decision:** Routes are cached by the exact positions (bit patterns) of both ends and store portal sequences; graphs and caches are dropped when the building's structure signature (plates + transport shafts) changes. After construction only trips whose remaining legs became invalid are re-planned, from the traveller's current position; with no route they leave the building.
- **Alternatives:** Quantized keys (more hits, but results would depend on which query came first — breaking determinism across save/load); re-planning every traveller after any change.
- **Reason:** The cache must never change outcomes (saves do not store it). Personal standing spots are fixed, so exact keys still hit on every repeated daily trip. Re-planning valid trips would make construction visibly jolt unrelated people.
- **Consequences:** The first day of a large building is mostly misses (45 % hits in the 200-floor test day; higher on later days). The signature is recomputed every simulation step (O(rooms of the building)); fine at current scale, revisit with a construction revision counter if profiling shows it (Phase 19).

## D-025 — Elevator cars are event-driven with analytic motion
- **Date:** 2026-09-27
- **Decision:** One `ElevatorCar` per shaft is saved state. It acts only at events (arrival, doors closed, a call waking an idle car) in the same event queue as people; cars act before people at equal ticks. Position between events is a trapezoidal profile evaluated analytically. Queues are not stored separately: they are the people in `waiting` state at a landing, ordered by (since, id).
- **Alternatives:** Per-tick car integration; stored hall-call lists.
- **Reason:** Consistent with D-019 (analytic trips): cheap at scale (60 floors, 354 workers, 5 h of rush in 14 ms release), exact rendering, deterministic across batch sizes; derived queues can never disagree with people's states.
- **Consequences:** Calls that arrive while a car is moving wait for its next stop (no mid-trip re-targeting). Multi-car banks (Phase 7) add a bank dispatcher that assigns calls to cars; car state stays the same.

## D-026 — Route planning assumes a constant elevator wait
- **Date:** 2026-09-27
- **Decision:** The boarding edge costs `expectedWaitSeconds` from content, not the live queue.
- **Alternatives:** Queue-dependent costs.
- **Reason:** Keeps routes a pure function of structure, so the exact-key route cache stays valid (D-024) and results do not depend on cache state.
- **Consequences:** People do not switch to the stairs when a queue is long. Phase 7 can add a separate, deterministic decision at the landing (e.g. patience → take the stairs) without touching the cache.

## D-027 — Banks are derived; calls are assigned to a car when people reach the landing
- **Date:** 2026-09-27
- **Decision:** A bank is computed from adjacency (same type, touching, overlapping floors), not stored. When a person reaches a landing, the bank's strategy assigns one car (`Ride.assigned`); the person walks to that car's doors and queues there. Cars keep running collective logic over their own queues. The strategy is stored on every car of the bank.
- **Alternatives:** Stored bank entities; a shared bank queue polled by all cars (late assignment).
- **Reason:** Nothing to keep in sync when shafts are built or demolished; immediate assignment makes all three strategies one mechanism (only the choice differs) and keeps each car's decisions local and deterministic.
- **Consequences:** An assignment is not revised if another car becomes free sooner. Estimated arrival is a heuristic (sweep distance + dwells); a smarter re-assignment can be added without changing saved state.

## D-028 — Patience: stairs only when the detour is short
- **Date:** 2026-09-27
- **Decision:** Queuing people get a personal patience (content value ± 50 % by traits). When it expires they take a route without elevators if it takes ≤ 5 minutes, otherwise keep waiting. Elevator-free routes are cached under their own key.
- **Reason:** Visible, measurable reaction to bad service (abandonment statistic) without breaking the static-cost routing of D-026; nobody climbs 30 storeys out of impatience.
- **Consequences:** Queue length still does not affect the initial route choice.

## D-029 — A deterministic hourly rental market with explainable appraisals
- **Date:** 2026-09-27
- **Decision:** Prospects are drawn hourly per tenant type from a seeded generator (city seed, hour, type). Each appraises vacant units on four 0…1 criteria (rent, access incl. measured elevator waits, noise, view) with content weights; it signs the best unit above its threshold or declines with its weakest criterion. Tenants review daily and leave after three bad reviews.
- **Alternatives:** Aggregate demand curves (occupancy as a number); utility with randomness per decision.
- **Reason:** Individual, inspectable decisions ("declined: too noisy") serve pillar 3 (honest systems) and connect construction and elevator service to vacancy; seeded draws keep runs reproducible and batch-independent.
- **Consequences:** Appraisal routes through the navigation cache; many vacancies × prospects cost route plans (cached per exact spot). Balancing happens in data.

## D-030 — Rooms are no longer filled automatically
- **Date:** 2026-09-27
- **Decision:** Room `occupancy` moved into tenant types; `PopulationSync` only ends leases of demolished units and adopts people of older saves into tenants. Tests and the developer menu use `Leasing.fillAll`.
- **Reason:** Replaces the Phase 4 stand-in (D-021) as planned instead of layering on it; keeps old saves playable without inventing data (adoption is based on who is already there).
- **Consequences:** A new building starts empty and fills over the first game days.

## D-031 — Money moves only through the ledger; construction is settled by the history
- **Date:** 2026-09-27
- **Decision:** Every change of cash is a posted `Transaction` with category and attribution. Construction is charged in `ConstructionHistory` (not in `ConstructionEngine`): perform posts the plan cost, undo posts its exact reversal, redo charges again; insufficient cash refuses the command before the world changes.
- **Alternatives:** Charging inside `ConstructionEngine.apply` (undo would then pay the inverse command's price, e.g. a demolition refund instead of the full cost).
- **Reason:** Keeps construction commands pure and exactly invertible (rule 16) while making undo financially neutral; traceability is pillar 3.
- **Consequences:** Commands applied directly through the engine (tests, fixtures) are free; the app always goes through the history.

## D-032 — One game day bills one rent month
- **Date:** 2026-09-27
- **Decision:** Rents are quoted monthly but collected in full at each daily closing (`rentDaysPerMonth: 1` in content).
- **Reason:** A game day lasts an hour at 1×; monthly billing would make income invisible for 30 hours of play. The factor is data, so scenarios can choose otherwise.
- **Consequences:** Costs are daily amounts sized against that income; balancing continues with Phase 10 costs.

## D-033 — Day/night is presentation only (for now)
- **Date:** 2026-09-27
- **Decision:** Daylight, ambient tint and lit rooms are computed in Presentation from the clock and people's places; the simulation does not depend on light.
- **Reason:** Delivers the M1 visual requirement cheaply; energy use and light sources belong to Phase 12, where lighting becomes simulation input.

## D-034 — Utilities are derived; upkeep lives beside rooms
- **Date:** 2026-09-27
- **Decision:** Utility supply is recomputed from equipment rooms, ranges and upkeep whenever needed (never saved). Wear and cleanliness are an `Upkeep` store keyed by room id, not fields of `Room`.
- **Alternatives:** Pipe/cable networks as placed entities; utility state saved per room; upkeep inside `Room`.
- **Reason:** Abstract distribution gives the planning challenge (capacity, plant floors) without network editing; derived data cannot go stale. Keeping upkeep out of `Room` keeps construction commands and their exact inverses independent of simulation state (rule 16).
- **Consequences:** Allocation runs per appraisal and per UI refresh (cheap at current sizes; cache if profiling says so).

## D-035 — Staff share people, navigation and elevators; route modes
- **Date:** 2026-09-27
- **Decision:** Staff are `Person`s with roles janitor/technician and a `JobAssignment`; their behaviour is event-driven like everyone's, and they route with mode `staff` (service elevators allowed). Tenants route `public`; impatient people `stairsOnly`. The mode is part of the route cache key.
- **Reason:** One movement system (queues, cars, re-planning) for everybody; service elevators are a data flag, not a new transport type.
- **Consequences:** Queue mechanics had to stop assuming everyone has a schedule (fixed in this phase).

## D-036 — Building classes only rise; unlocks are checked at placement
- **Date:** 2026-09-27
- **Decision:**
  - Buildings are promoted one class at a time when they meet every requirement of the next class, and are never demoted. Reputation keeps moving and drives demand.
  - Room-type and height locks are validated in `ConstructionEngine` for new placements only. Restore commands (undo/redo) are exempt.
  - The unlock mode belongs to the world, set by the start: sandbox or standard.
- **Alternatives:** A class that follows reputation up and down (unlocked rooms would become illegal, or undo would break); gating in the UI only.
- **Reason:**
  - Unlocks must stay stable, and every command needs an exact, always-valid inverse (rule 16).
  - Gating in the engine keeps the rule authoritative whatever the input device.
- **Consequences:**
  - A badly run building keeps its class but loses tenants through lower demand.
  - Old saves load as sandbox games.

## D-037 — One lighting model for energy and rendering; static night emission
- **Date:** 2026-09-28
- **Decision:**
  - Room lighting levels come from `Lighting.level` in Core, with content specs. The simulation meters them hourly at market events and bills them daily. The renderer draws the same levels scaled by darkness.
  - Static night lights (city, neighbours, lamps) are a composition layer, rendered as additive tiles above the grade with the tower's silhouettes cleared.
- **Alternatives:** A separate visual-only lighting rule (the bill and the picture could disagree); shading the backdrop per frame (thousands of sprites); a runtime mask node (inverse masks are awkward in SpriteKit).
- **Reason:** Rule 4 (no game rules in the renderer) and pillar 3 (traceable numbers): what you see lit is what you pay for.
- **Consequences:**
  - Metering hourly is an approximation of the integral (within one hour of occupancy change).
  - The emission layer's tiles are redrawn where construction changes the silhouette.

## D-038 — Daily weather as saved state, drawn from the seed; visuals derived
- **Date:** 2026-09-28
- **Decision:**
  - The simulation keeps `WeatherState` (yesterday, today, forecast, temperature) and advances it at the 06:00 closing with a pure draw from the city seed, the day and the previous kind.
  - Effects are content multipliers.
  - The renderer derives the look (grade, fog, particles, snow cover, lightning) from the state and the game time.
- **Alternatives:** Hourly weather (more state, more events); weather only as visuals; storing the whole year up front.
- **Reason:**
  - One change per day matches the daily economy (bills, wear, reviews) and gives the player a forecast to plan with.
  - Saving three kinds keeps the format small, and determinism holds (rule 7).
- **Consequences:**
  - Particles run in real time and are not reproducible; they are decoration.
  - Lightning is deterministic in game time.

## D-039 — Fire as a stepped incident; evacuation through the normal movement system
- **Date:** 2026-09-28
- **Decision:**
  - A fire is saved state (burning rooms with intensities, brigade arrival, next step), stepped every 60 game seconds as its own event target in the simulation queue.
  - Evacuation is not a separate mover: people get ordinary trips out with `stairsOnly` routing. While their building burns, one hook in the person loop keeps them out.
  - They return to wherever their schedule says when they next check.
  - Nobody is harmed: the game models damage, cost and reputation, not casualties.
- **Alternatives:** A cellular fire grid per module (finer, costlier, harder to read in the cutaway); a scripted evacuation animation; responders as simulated people.
- **Reason:**
  - The room is the unit players build and inspect.
  - Events keep fires deterministic and independent of batch size (rule 7).
  - Reusing trips and navigation gives stairs congestion and elevator blocking for free.
- **Consequences:**
  - Fire brigade suppression is abstract (the engine parks at the kerb).
  - Smoke is visual only.

## D-040 — Cities carry their market in the save; one market per city
- **Date:** 2026-09-28
- **Decision:**
  - A city's economy (rent, construction and demand multipliers) is copied from content into `City` when the city joins the estate.
  - Construction and the market read it from the world.
  - The rental market runs per city: its own random stream from the city seed, its own vacancies, and demand from its own buildings.
  - Land purchases are ledger transactions (`land`), not construction commands.
- **Alternatives:**
  - Looking the city up in content at run time: Core and Simulation do not know content, and a content update would silently change running games.
  - One global market choosing among all cities' units.
  - Purchases as undoable commands.
- **Reason:**
  - Saves stay self-contained and deterministic.
  - A tenant looking for an office in Harrowgate should not be offered Saltmere.
  - Buying land is a financial decision like a loan, not an edit.
- **Consequences:**
  - A one-city game keeps exactly its earlier market draws.
  - Older saves get their city market applied once on load (`Estate.adoptLegacy`).

## D-041 — Scenarios as copied objectives decided at the daily closing
- **Date:** 2026-09-28
- **Decision:**
  - A scenario is content: a start, optional cash, a number of days, `holdDays` and objectives over a fixed set of estate-wide metrics.
  - Starting one copies the objectives and the deadline into `GameWorld.scenario`.
  - The simulation measures them at every daily closing and decides the result once: won after `holdDays` closings in a row with every objective met; lost on bankruptcy or when the deadline closing passes.
  - After the result the game continues as free play.
- **Alternatives:**
  - Evaluating continuously (every tick or hour).
  - Scripted objectives or conditions (expressions in content).
  - Ending the game at the result.
- **Reason:**
  - The closing is when the day's numbers are settled (rent, costs, reputation), so a win cannot hinge on a lucky hour.
  - Checking once a day keeps the check cheap, and deterministic and batch-independent (rule 7).
  - A fixed metric list keeps mods declarative (rule 15) and every objective explainable in the UI.
  - Copying keeps saves self-contained, as with city markets (D-040).
- **Consequences:**
  - New kinds of objectives need engine code (a metric case) and a documented definition.
  - The live panel can show an objective as met during the day that the closing then misses.

## D-042 — Mods overlay the base pack by id; each mod is validated on top of the others
- **Date:** 2026-09-28
- **Decision:**
  - A mod is a content pack in the same format as the base pack.
  - Packs are read (decoded only), then laid over each other in the player's load order: list entries replace by id in place or are appended; single-file kinds replace the file; materials merge per key.
  - After each mod the merged content is validated with the base rules. A failing mod is skipped and reported with the error attributed to it.
  - Saves list their pack ids. The enabled list is an app setting (UserDefaults), not game state.
  - Changing mods reloads all content and starts a fresh game.
- **Alternatives:**
  - An explicit `"override": true` flag.
  - Field-level patches (JSON merge patch).
  - Rejecting the whole mod set on any error.
  - Hot-swapping content under a running game.
- **Reason:**
  - Replace-by-id is predictable and matches how content is keyed everywhere.
  - Validating each step keeps the base game safe and points at the guilty mod.
  - A running world's rooms, tenants and cities reference content ids, so swapping content under it could break invariants. A fresh game (or loading a save made with the same packs) never does.
- **Consequences:**
  - A mod that wants to change one field copies the whole entry.
  - Base entries cannot be removed yet.
  - A save made with a mod needs that mod (by id; versions are recorded but not enforced).

## D-043 — Save sync as folder-to-folder logic with keep-both conflicts
- **Date:** 2026-09-28
- **Decision:**
  - Saves sync between the local save folder and the app's iCloud Drive container.
  - The logic is platform-independent (`SaveSync`), compares file fingerprints with a per-device record of the last synced version, and runs at fixed moments (launch, save, panel, Sync Now).
  - Conflicts keep both versions under a new name; a deletion propagates only over an unchanged copy; placeholders are left alone; autosaves stay local.
  - The iCloud entitlement is a documented setup step, not part of the checked-in project.
- **Alternatives:**
  - `UIDocument`/`NSDocument` with iCloud versions.
  - CloudKit records.
  - Newest-wins by modification date.
  - Syncing autosaves.
- **Reason:**
  - Saves are single files already, so folder sync is the smallest robust step.
  - Fingerprints and a per-device base decide "who changed" without trusting clocks across devices.
  - Keep-both is the only rule that can never lose a player's game.
  - A pure-Swift core is testable on Linux (two simulated devices).
  - An iCloud entitlement would break local ad-hoc builds for anyone without a team.
- **Consequences:**
  - The iCloud connection is unverified until someone builds with a team.
  - No live updates: another device's save appears at the next sync moment.

## D-044 — Scale by caching derived state per structure; the simulation stays on the main thread for now
- **Date:** 2026-09-28
- **Decision:**
  - Profile a generated stress tower (`skyline-bench`, callgrind) and fix what it shows:
    - one utility allocation per building per market hour and per daily review;
    - elevator banks cached with the navigation graph (dropped by the same structure signature; strategies read fresh);
    - a larger route cache;
    - spec lookups only for real neighbours.
  - Every cache returns exactly what a fresh computation would, which is tested, so determinism and batch independence hold (rule 7).
  - Moving the simulation to a background actor is postponed.
- **Alternatives:**
  - A background `SimulationHost` actor publishing snapshots now.
  - Incremental utility allocation.
  - An LRU route cache.
- **Reason:**
  - After the fixes a 211-floor, 950-person tower costs about 0.3 % of a core at 10× speed, and one `advance` call about 0.6 ms at 400 floors.
  - Only the once-a-day closing (about 100 ms) would benefit from a thread, while snapshots would cost a full world copy per publish and complicate every UI action that edits the world.
- **Consequences:**
  - The daily closing is a visible hitch of a few frames at 10× on very large towers.
  - Revisit threading when real play at larger scale shows it, together with incremental utility allocation.

## D-045 — Polish stays procedural; the icon is generated from code
- **Date:** 2026-09-28
- **Decision:**
  - The app icon is drawn by `IconArt` in the drawing IR and rendered by a script into the asset catalog.
  - Clouds are a deterministic presentation function of city seed, game time and weather.
  - UI chrome stays plain SwiftUI (no AppKit-backed containers), so captures show exactly what the window shows.
  - The version stays 0.20.0 rather than 1.0.
- **Alternatives:**
  - A hand-painted icon.
  - Particle clouds.
  - Scroll views for long panels.
  - Calling this 1.0.
- **Reason:**
  - The rules forbid copied assets. Code-drawn art is original, reproducible and matches the game's look.
  - Deterministic clouds keep captures and tests stable.
  - A scroll view vanished from captures before (Phase 17).
  - No human has played the game yet, and iCloud, the iPad and real Macs are unverified: 1.0 would overclaim (rule 10).
- **Consequences:**
  - Changing the icon means editing `IconArt` and running `Scripts/make-icon.sh`.
  - Tall panel stacks can exceed small windows (a known issue; fixed by tabs, D-047).

## D-060 — F5: the iPhone as a compact layout of the same chrome
- **Date:** 2026-09-29
- **Decision:**
  - The iPhone runs the same app target (device family iPhone and iPad), in landscape only.
  - No separate phone UI. The existing views fall back to compact forms where they do not
    fit, mostly with `ViewThatFits`:
    - the build palette groups its tools under five categories and shows one category's
      tools at a time;
    - the view controls put the panel and overlay toggles behind one button (a picker);
    - the main menu uses two columns;
    - the manual shows its contents in place of the page;
    - the tutorial panel drops its step list.
  - Where the fallback depends on the device rather than the space (the cash readout beside the
    view controls, the narrow view controls), `Device.isPhone` decides. It reads the
    device idiom, because captures render outside the window and get no size class.
  - Panels are drawn above the build palette.
  - CI launches the iPhone build in an iPhone simulator with the same capture script
    (`Scripts/capture-simulator.sh iphone`).
- **Alternatives:**
  - A separate phone interface (a second UI to keep in step).
  - Portrait (a tower is tall, but the palette, the panels and the time bar need width).
  - Size classes (not available to the capture renderer).
- **Reason:** Every view already existed and worked; a compact fallback per view is the
  smallest change, and the Mac and iPad keep their layout because the full form still fits
  there.
- **Consequences:**
  - On a phone the panels cover much of the building; one or two at a time is practical.
  - Touch on a real iPhone has not been tried by a person (OPEN_ITEMS V2).

## D-059 — F4: text size on the chrome, Esc as "close", the iPad in CI
- **Date:** 2026-09-29
- **Decision:**
  - Larger text is `.dynamicTypeSize` on the whole chrome. On an iPad it follows the
    system's Dynamic Type unless the player picks a size. On a Mac, whose system has no
    Dynamic Type, the player picks one (View ▸ Text Size, main menu).
  - Esc closes one thing per press, in a fixed order: tool, tip, full-screen view, selection,
    panels from the bottom.
  - Keyboard focus uses the system's own navigation (Keyboard navigation or Full Keyboard
    Access), plus a focus ring drawn on every custom button.
  - The iPad build runs in CI in an iPad simulator with the same capture script as the Mac.
    Captures are written inside the app's container and copied out.
  - The iPad gets the game's menu commands with a keyboard, and Save and Main Menu buttons
    for touch.
- **Alternatives:**
  - Scaling fonts by hand with our own factor (every view would change).
  - An in-app focus system with arrow keys.
  - Only building the iPad app, as before.
  - XCUITest for the iPad (a second test target to maintain, and slower).
- **Reason:**
  - Text styles were already used almost everywhere, so one modifier scales them.
  - The system's keyboard navigation is what keyboard users already have turned on.
  - The capture script already worked on both platforms, so launching it in the simulator
    was the smallest way to see the iPad at all.
- **Consequences:**
  - The icons of the palette and the view controls keep their size.
  - Tab focus and the iPad keyboard compile and are wired, but only a person with a
    keyboard can confirm they work (OPEN_ITEMS).
  - CI takes about 8 minutes longer: the simulator boots.

## D-058 — F3: one manual for game and website; tutorial steps are guidance
- **Date:** 2026-09-29
- **Decision:**
  - The manual is Markdown in `SkylineContent/Resources/Manual`, outside the base pack. The
    game renders it natively; `skyline-website` renders the same chapters to
    `Website/manual/`, and a test fails when the generated pages are stale.
  - Tutorial steps are an optional list on a scenario, with conditions measured on the live
    world. They are not saved.
  - First-time tips are content (`hints.json`); the app decides when each fires and remembers
    per device which were seen.
  - The website is plain static HTML with one stylesheet, in English like the game, and is
    not deployed automatically.
- **Alternatives:**
  - The manual written twice, once in the app and once as HTML.
  - A web view in the app.
  - Saving tutorial progress, which needs a save format change.
  - A static site generator, a third-party dependency.
  - Publishing through a GitHub Pages workflow now.
- **Reason:**
  - One source cannot drift, and the test enforces it.
  - Native text keeps VoiceOver, Dynamic Type later (F4) and the app's look.
  - Measuring steps on the world needs no new state and survives save/load for free.
  - Publishing to a domain is the owner's decision, and the host is not chosen yet.
- **Consequences:**
  - A manual change needs `swift run skyline-website ../../Website`.
  - A tutorial step can go back to undone when the player demolishes what it asked for; the
    panel then shows it again, which is honest.
  - Mods can add tutorial steps to their scenarios but cannot change the manual.

## D-057 — F2: 500 floors by profiling, not by threads
- **Date:** 2026-09-29
- **Decision:**
  - Tall towers are made fast by removing measured hot spots:
    - staff rooms are looked up once per `advance` call;
    - elevator cars have graph nodes only at their stops;
    - routes are found with A* search;
    - breakdowns no longer rebuild the navigation graph;
    - the route cache is warmed when a world is loaded.
  - Zoomed far out at night, lit windows are one strip per storey.
  - The simulation stays on the main thread; the cache is warmed synchronously.
  - Elevator shafts may span 1 000 floors.
- **Alternatives:**
  - A background simulation actor (D-044).
  - Warming the route cache on a background queue.
  - Tiling the night panes into textures.
- **Reason:**
  - The profile showed that two hot spots took 70 % of a day. With those fixed, the worst
    step at 526 floors is 134 ms (once, on the first morning) and the daily closing is
    65 ms.
  - `SimulationEngine` and its caches are not thread-safe. Warming the cache in the
    background would race with the frame loop.
  - Strips cut the sprites four-fold with no new texture work.
- **Consequences:**
  - Loading a 500-floor world takes about 0.25 s longer (warming the cache).
  - Routes and outcomes are unchanged (same event count).
  - A* depends on a lower bound per storey, taken from the content (stairs and car speeds).

## D-056 — F1: balance by a bot; budgets pay the height premium
- **Date:** 2026-09-29
- **Decision:**
  - A headless balance bot (`SkylineBot`, `skyline-balance`) plays every scenario through
    the construction engine and the market, and writes BALANCE.md.
  - Tenant budgets rise with the same +1 %/storey premium as asking rents.
  - Class A needs 100 people and Prime 250.
  - The scenario targets were set from the bot's results.
- **Alternatives:**
  - Tuning by hand without a player.
  - Removing the height premium (tall towers would earn nothing extra).
- **Reason:**
  - The bot turned up two blockers that no test had found: high offices could not be let,
    and Class A was out of reach.
  - It also found a crash in elevator repair.
- **Consequences:**
  - Tall towers can be let at every height, and they earn more per unit the higher they go.
  - Balance is reproducible: re-run the bot after changing content.
  - The bot is a lower bound; a human play test (V1) is still open.

## D-055 — Phase C: scenario scripts live in the save; records on the device
- **Date:** 2026-09-29
- **Decision:**
  - Scenario restrictions, events and scoring are copied into `ScenarioState` at the start,
    like the objectives, so a save keeps its rules.
  - Events fire at market hours, once each, recorded by index.
  - Demand shocks multiply prospect chances.
  - Grants and fines use objectives as conditions.
  - Scores are stars plus points (the player's choice).
  - The completion record is a separate JSON file on the device, next to the saves and
    merged when syncing (the player's choice).
  - Restrictions are enforced where the action is validated: the construction engine,
    `Economy`, and hiring.
- **Alternatives:**
  - Events as code (rejected: content is data).
  - The record inside saves (rejected: lost with the save, not global).
  - Summing counts on merge (rejected: a play synced from both sides would count twice).
- **Reason:** It is deterministic and data-only, and old saves stay valid.
- **Consequences:**
  - Save format 18 (all new fields optional).
  - `dailyProfit` now also counts turnover, taxes and waste.
  - A new hard scenario, Lean Tower.

## D-054 — Phase E: operating costs reuse the closing, upkeep and navigation
- **Date:** 2026-09-29
- **Decision:**
  - **Taxes:** property tax on the assessed value (the build cost) per closing, and profit tax
    on the closing's result, measured as the change in the day's ledger totals.
  - **Energy:** a mean-reverting daily energy price per city scales utilities and lighting.
  - **Waste:** collection is billed for what waste rooms take; the overflow dirties the building.
  - **Staff rooms** cap hiring, and set where idle staff wait and how far their work reaches
    (the player chose "needed + range").
  - **Elevators** wear their shaft's `Upkeep` per stop and may break down. The player chose
    moderate outages: one car, riders get out, a technician repairs it (about an hour).
  - **Unit rent** is a factor on the building's level, in the inspector's steps (the player's choice).
- **Alternatives:**
  - Separate wear state on cars.
  - Removing broken cars.
  - Profit tax from the journal, which is truncated at 400 entries.
  - Live energy markets.
- **Reason:**
  - Everything reuses systems that are already tested: the ledger, the facilities jobs, the
    `Upkeep` of rooms, and graph rebuilding by signature (a broken car changes the signature).
  - Every result stays deterministic.
- **Consequences:**
  - Save format 17.
  - The demo tower and highrise gained a waste room (a narrower basement plant room), and the
    plaza gained a staff room and a waste room.
  - The game's own hiring needs a staff room.

## D-053 — Amenities are rented; visitors are transient; seats by share
- **Date:** 2026-09-28
- **Decision:**
  - Amenity rooms are leased like other units: an operator tenant pays rent. The landlord
    also gets a content-defined share of the takings at the daily closing (the player
    chose "rent + turnover share").
  - Street visitors are `Person`s with the role `visitor`. They are spawned hourly per open
    venue and removed hourly once they have left.
  - Occupants visit with a probability of seats ÷ occupants instead of a live seat count.
  - Visitors come from the street and from the building itself (the player's choice).
- **Alternatives:**
  - The player operating amenities, with stock and staff.
  - Visitors as aggregate numbers only, without people.
  - Live seat counting.
- **Reason:**
  - Leasing reuses the whole market (appraisal, satisfaction, labels, sales rules).
  - Real visitor people load the lobby and elevators, which is the point of amenities in a
    vertical building.
  - The share formula keeps visits deterministic and O(1) per event, where live counting
    would need a scan per event.
- **Consequences:**
  - The save format is 16: visitor role, lunch, leisure and visit goals, `Tenant.sales`,
    and the `turnover` ledger category.
  - Schedules may carry `chance` on lunch and leisure events.
  - A venue can be briefly over-full.
  - Takings do not yet affect the operator's satisfaction.

## D-052 — No pile height limit in the base game
- **Date:** 2026-09-28
- **Decision:** The base `build-rules.json` no longer sets `storeysPerPileMeter`, so piles
  do not limit how high a tower rises. The rule stays in the engine for mods. Supersedes
  the base-game part of D-051.
- **Alternatives:** A much looser ratio (e.g. 10 storeys per meter); a limit from soil strata.
- **Reason:** The player builds towards 500 storeys; at 2 storeys per meter that needs
  250 m piles, which the player found unplayable. Any ratio is a chore at that scale.
- **Consequences:** Longer piles have no gameplay effect in the base game for now (they
  cost money and deepen the ground section). A later phase may give them one (e.g.
  settlement or wind load) if the player wants it.

## D-051 — Foundations grow; piles carry the height
- **Date:** 2026-09-28
- **Decision:**
  - A building's foundation grows through `extendFoundation`: a wider footprint within the
    plot, more basement levels up to the plot's limit, and longer piles.
  - It never shrinks; the exact inverse is `restoreFoundation`.
  - With `storeysPerPileMeter` (2 in the base game), piles limit the storeys above grade.
- **Alternatives:**
  - Separate commands per dimension.
  - Piles as decoration only.
  - A height limit from soil strata.
- **Reason:** The player asked for all three extensions. One command with the target
  groundwork keeps undo and costs uniform. A pile limit gives longer piles a purpose
  without new systems: the starting piles carry 40 storeys, so rising past that (Class A
  allows 45 floors, Prime more) takes longer piles.
- **Consequences:**
  - Towers above 40 storeys need longer piles first; the skytower blueprint does that.
  - Existing buildings are not checked retroactively.
  - When the groundwork changes, the app composes the site anew, because the ground
    section follows the deepest pile.

## D-050 — Flats for sale: one-off price, then service charges
- **Date:** 2026-09-28
- **Decision:** Tenure is per unit (`Room.tenure`: rent / forSale / owned), chosen by the
  player for vacant flats in the inspector. A sale pays asking rent × `saleMonths` once;
  the owner then pays `serviceChargeShare` of the rent monthly and moves out only after
  `ownerPatience` bad reviews. A sold flat never returns to the player: an owner who leaves
  is followed by a private resale. Only households buy.
- **Alternatives (offered to the player):** sale only, with no income afterwards; sale with
  buy-back; a per-building share for sale.
- **Reason:** The player chose a sale plus service charges, set per flat. Keeping sold flats
  private closes the loop of selling the same flat twice, and the monthly service charges
  keep the building's economy running.
- **Consequences:** Save format 15. Selling trades future rent for cash now: a sold studio
  brings about 100 days of rent at once, then a quarter of the rent. The balance is
  first-pass and needs a play test.

## D-049 — Shafts make rooms give way; shafts can be resized
- **Date:** 2026-09-28
- **Decision:** A shaft placed or extended over rooms trims them: each loses the shaft's
  columns (on all its floors) and keeps its wider side; the other side becomes a new room of
  the same type if it is at least the minimum width. A room left narrower than its minimum
  blocks the shaft; so does another shaft. Shafts get `resizeRoom` (same columns, new
  floors). Changes to several rooms undo through a `batch` command; `restoreRoom` updates an
  existing room in place.
- **Alternatives:** shafts drawn in front of rooms without changing them (two things in one
  cell breaks the grid model and navigation); demolishing rooms in the way (loses tenants);
  resize as demolish-and-rebuild (loses the car's statistics and 60 % of the cost).
- **Reason:** The player asked for rooms to shrink automatically and for taller/shorter
  lifts. Trimming keeps the one-room-per-cell model, keeps tenants, and is exactly
  reversible.
- **Consequences:** A tenant keeps its rent after its unit shrinks until the market reviews
  it. A shortened shaft stops its car at the nearest served floor and lets riders out to be
  re-planned.

## D-048 — No cantilevered floors in the base game
- **Date:** 2026-09-28
- **Decision:** `maxCantileverModules` is 0: every floor lies within the floor below.
  Refused floors report "Cannot be wider than the floor below" (`ConstructionError.overhang`).
- **Alternatives:** keep a small allowance but measure it from the ground floor, so it
  cannot add up floor by floor.
- **Reason:** The player found towers that widen as they rise (2 m more per side on every
  floor) and asked for this to be impossible. Zero is the simplest rule that reads right.
- **Consequences:** Existing saves keep any overhanging floors (no retroactive check).
  Mods can set an allowance, which still applies per floor.

## D-046 — One account for the whole estate
- **Date:** 2026-09-28
- **Decision:** Cash, loans and bankruptcy stay estate-wide: the player runs one company
  with one account. Buildings and cities keep their own markets, rents and costs, and
  every transaction still names its building where it has one. The estate overview shows
  the last 24 hours split into money booked to buildings and estate money (loans, interest,
  land, grants).
- **Alternatives:** a ledger per city, with loans, bankruptcy and transfers per city.
- **Reason:** One account is how a property company works and keeps the game readable.
  Separate purses would touch the save format, the economy, scenarios (their cash
  objectives) and the UI, for little gameplay. The player confirmed this choice.
- **Consequences:** A struggling city is carried by the others; the overview makes the
  split visible instead.

## D-047 — Known-bug fixes after Phase 20 (0.20.1)
- **Date:** 2026-09-28
- **Decision:**
  - Weather belongs to each city (save format 14). The first city keeps the old weather on
    migration, so its days continue unchanged.
  - Saves record a content hash (FNV-1a over the pack files) next to each pack's version.
    A changed pack is reported on load, not refused.
  - The camera may look `bottomInset` points below the ground, so the street can always be
    moved above the build bar; presets frame above it.
  - Side panels that do not all fit become tabs (one in full, `ViewThatFits`), still plain
    SwiftUI so captures show them.
  - Rain and snow scale with the zoom; city windows follow the hour as a whole layer, with
    street lamps split into their own layer.
- **Alternatives:**
  - A cryptographic hash (needs a dependency on Linux; change detection does not need it).
  - Refusing saves whose packs changed (too strict: a mod update would lock the player out).
  - A scroll view for panels (vanished from captures before).
  - Per-window lights-out times (needs re-rasterizing tiles through the night).
- **Reason:** Each fix is the smallest change that removes the problem without a new
  system; all are deterministic and tested.
- **Consequences:** One more small tile layer (lamps). Which city windows are lit does not
  change during the night, only how many show.

