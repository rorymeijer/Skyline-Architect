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

