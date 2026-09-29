# Open Items

Everything that is still open after Phase 20 and the 0.20.1 bug fixes, in one place. It is collected
from `Development/STATUS.md`, the PLANNED, Limits and "Not yet" sections of every system
document, `ROADMAP.md` and `PERFORMANCE.md`. Those documents stay the source of detail. This
page is the checklist.

Status vocabulary: PLANNED / SCAFFOLDED / FUNCTIONAL / POLISHED (see CLAUDE.md).

## 1. Verification gaps

These parts are built and tested in code, but they have never been checked in the setting
where they matter.

| # | Item | Why it is open | Source |
|---|------|----------------|--------|
| V1 | Human play test | Nobody has played a full session: only scripted captures and tests have run. | STATUS |
| V2 | iPad | Since F4 the iPad build runs in the iPad simulator in CI, with captures (`_ci-latest/ipad/`). It has not run on a real iPad, and touch, the on-screen keyboard and a hardware keyboard have not been tried by a person. | STATUS, ACCESSIBILITY |
| V3 | iCloud sync | It needs a signing team and an iCloud container. Sync between two devices has never been verified. | SAVE_FORMAT, ROADMAP Phase 18 |
| V4 | Real hardware performance | The figures come from CI runners (macOS VM) and Linux callgrind. Nothing was measured on a user's Mac or iPad. | PERFORMANCE |
| V5 | VoiceOver | Checked by code review only, never with VoiceOver on a device. | ACCESSIBILITY, STATUS |

## 2. Known bugs and UI issues

All eight were addressed in 0.20.1 (DECISIONS D-046, D-047). Kept here for the record;
new bugs go at the bottom of the table.

| # | Item | Outcome | Checked by |
|---|------|---------|------------|
| B1 | Stacks of tall panels could be taller than a small window. | Fixed: panels that do not all fit become tabs. | Capture `02-panel-tabs` |
| B2 | The wide sky views could not pan below the street, so the build bar covered it. | Fixed: the camera may look 150 pt below the ground; presets frame above the bar. | Tests, capture `01-skyline-street` |
| B3 | Weather was shared by the whole estate. | Fixed: weather per city (save format 14). | Tests, capture `03-estate-two-cities` |
| B4 | Cash and loans are estate-wide. | Kept by design (D-046): one account; the overview shows the split. | — |
| B5 | Saves did not notice a changed mod with the same id and version. | Fixed: a content hash per pack; changes are reported on load. | Tests |
| B6 | The estate overview's 24-hour figure missed loans, interest and land. | Fixed: buildings + estate = total. | Tests, capture `03-estate-two-cities` |
| B7 | Weather particles looked the same at every zoom. | Fixed: size, speed, density and opacity follow the zoom. | Tests, captures `04-rain-close`, `05-rain-far` |
| B8 | City lights did not follow the time of night. | Fixed: windows go out through the night; lamps stay on. | Tests, captures `06-city-evening`, `07-city-small-hours` |

## 3. Balancing

The balance bot (F1, BALANCE.md) now checks every scenario and led to fixes for high-floor
leasing, class thresholds and scenario targets. Everything below is still not play-tested by a
human (V1).

* Scenario targets and time limits (Opening Day … Skyline).
* Tenant budgets and rent levels per city. Harrowgate was fixed once already.
* Construction and running costs, loans and interest.
* Reputation thresholds and building-class unlocks.
* Fire, storm and equipment-failure frequencies.
* Elevator patience and walking tolerance.

## 4. Performance and technical debt

| # | Item | Measured | Source |
|---|------|----------|--------|
| P1 | The daily closing is a single spike on very large towers. | ~100 ms (6 frames) at 400 floors | PERFORMANCE, STATUS |
| P2 | The simulation runs on the main thread. A background actor is planned for when the play test shows a hitch (D-044). | — | PERFORMANCE, DECISIONS |
| P3 | Utility allocation is a full recomputation, O(rooms × plant). It is not incremental. | ~4–5 ms at 400 floors, hourly | PERFORMANCE |
| P4 | Night window panes are separate SpriteKit nodes. They could be batched into tiles. | 1 845 nodes, 4.6 ms at 211 floors | PERFORMANCE |
| P5 | The fixed per-call cost grows with rooms and people: the heap is rebuilt and signatures are checked on every call. | — | PERFORMANCE |
| P6 | The first day's move-in wave plans about 1 000 routes. | 40–50 ms steps | PERFORMANCE |
| P7 | People sprites. | ~1 ms at 400 floors | PERFORMANCE |

## 5. Accessibility

* ~~Full keyboard navigation inside panels~~ and ~~Dynamic Type / text size~~ (F4, 0.28). Tab focus and the iPad keyboard still need a person with a keyboard to confirm them.
* An increased-contrast panel style.
* VoiceOver descriptions of the building itself. The SpriteKit world is not exposed to it.
* A VoiceOver pass on a device (V5).

## 6. Planned features per system

### Simulation and people (SIMULATION, TENANTS)
* Needs (hunger, energy …) and moods.
* ~~Visitors (shoppers, guests), together with amenities and retail room types.~~ Done in 0.22 (Phase B, AMENITIES.md). Follow-ups: operators weighing their takings; visitors with more than one stop.
* Live queue length in route choice. Today patience is the only reaction to queues.
* Congestion on stairs.

### Elevators (ELEVATORS)
* Freight cars. Staff-only service cars exist since Phase 10.
* Re-targeting a car mid-trip.
* Queue-aware route choice (same as above).
* Jerk-limited motion.

### Economy and facilities (ECONOMY, FACILITIES)
* ~~Taxes.~~ ~~Per-unit rents instead of one rent level.~~ ~~Waste and energy prices.~~
  ~~Staff rooms.~~ ~~Elevator wear and outages.~~ Done in 0.23 (Phase E, D-054).
* Events that affect demand.
* Staff skills.

### Progression (PROGRESSION)
* City-wide reputation across several properties.

### Environment (WEATHER, LIGHTING)
* Weather within a day (hourly changes).
* Seasonal day length. Today every day has summer daylight.
* Wind acting on elevators and façades.
* Flooding.
* Commuters reacting to rain.
* Player lighting policies (timers, sensors).
* Real light falloff and shadows.

### Emergencies (EMERGENCIES)
* Security incidents and medical calls.
* Responders walking through the building. Today suppression is abstract: the engine parks at the kerb.
* Smoke spreading through the stairs.
* Fire doors and compartments as buildable elements.
* Insurance.

### Estate (ESTATE)
* Selling land.
* More than one building per plot.
* City-specific tenant types, taxes and events.
* A map view of the estate.

### Scenarios (SCENARIOS)
* Objectives on specific buildings or cities.
* Optional bonus goals.
* ~~Scores or ratings; scripted events; restrictions on rooms, loans and rent levels; a
  record of completed scenarios.~~ Done in 0.24 (Phase C, D-055).

### Modding (MODDING)
* Removing base entries.
* Images and sprite sheets in mods.
* Hot reload without starting a new game.
* Sharing mods through a catalogue.

### Saves and sync (SAVE_FORMAT)
* File coordination (`NSFileCoordinator`).
* Live change notifications (`NSMetadataQuery`). Today sync runs at fixed moments.

## 7. Art (ASSET_REQUIREMENTS)

All art is procedural programmer art. A release needs these hand-made assets:

1. **Required:** people sprite sheets (body types, clothing, animations).
2. **Recommended:** furniture close-ups.
3. **Recommended:** elevator cars and doors.
4. **Optional:** façade materials.
5. **Required for release:** weather and effect art.
6. **Optional:** UI iconography.

A hand-tuned art pass on people and furniture is also listed as "not yet" for Phase 20.

## 8. Documentation housekeeping

Some PLANNED lists in the system documents still name work that later phases delivered:

| Document | Stale entries in its PLANNED list |
|----------|-----------------------------------|
| PROGRESSION | scenario goals (Phase 16) and reputation events (Phase 14) |
| TENANTS | rent charged (Phase 9) and reputation effects (Phase 11) |
| ECONOMY | wages and staff (Phase 10) and reputation (Phase 11) |
| ELEVATORS | the "Model (planned)" heading, although most of that model is FUNCTIONAL |
| GRAPHICS | its Phase 1 limitations still say "no lighting model yet" |

Update these lists when their systems are next touched.

## 9. Suggested order

1. **Play test and fix (V1).** A human session on a Mac and then an iPad (V2). Fix what it shows first.
2. **Balancing pass (section 3).** Use the play-test notes.
3. **Signed build with iCloud (V3).** Verify sync between two devices, and add file coordination.
4. **Accessibility (section 5).** ~~Keyboard navigation in panels, Dynamic Type~~ (F4). Still to do: a VoiceOver pass on a device.
5. **Performance (P1, P2).** Build the background simulation actor only if the play test shows the daily-closing hitch.
6. **Features by player value.** ~~Visitors, amenities and retail~~ (0.22). ~~Scenario scores and a completion record~~ (0.24).
7. **External art (section 7).** Before any release.
