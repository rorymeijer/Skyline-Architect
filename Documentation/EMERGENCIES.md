# Emergencies — Fire and Incidents

Status: **FUNCTIONAL (Phase 14)**. Implemented:

* **Fire:** ignition, growth, spread, sprinklers, the fire brigade, stairs-only evacuation, damage, repairs and the reputation hit.
* **Weather incidents:** storm damage, power outages, burst pipes.
* **Fire control room.**
* **Player feedback:** alerts, the incidents panel, and fire visuals.

**PLANNED:**

* security incidents and medical calls;
* scenario events (Phase 16);
* insurance;
* fire doors and compartments as buildable elements;
* smoke spreading through the stairs;
* casualties (not planned: people always get out in this game).

| Area | Code |
|------|------|
| Model | `SkylineCore/Incidents.swift` (`Incident`, `Fire`, `IncidentState`) |
| Fire | `SkylineSimulation/Fire.swift` (safety coverage, ignition, evacuation) |
| Stepping and weather incidents | `SkylineSimulation/Incidents.swift` |
| Rules | `EventRules.swift` |
| UI data | `IncidentReports.swift` |
| Visuals | `SkylinePresentation/Art/FireArt.swift`; app `FireLayer.swift`, `IncidentViews.swift` |
| Content | `events.json`; `fireProtection` in `rooms.json` (fire control room) |

## Fire

**Ignition.** Every hour, each room (not shafts: they are fire compartments) of a building
without a fire may ignite:

* base chance `ignitionPerRoomPerDay / 24` (0.0015 per room per day);
* × 4 for worn rooms (condition < 0.45);
* × 3 for plant (rooms with a utility supply);
* × 0.5 under sprinklers.

A building has at most one fire at a time. The Debug build can also start one on purpose
(developer tool).

**Steps.** A fire is stepped every 60 game seconds as its own event in the simulation queue
(`EventTarget.fires`), so the result does not depend on how time is batched. Each burning
room:

* **Growth:** +0.05 per step.
* **Sprinklers:** −0.09 per step if the room is covered.
* **Fire brigade:** −0.08 per step once the brigade has arrived, 16 min after ignition.
* **Damage:** the room loses `0.045 × intensity` condition per step, and 1.5× that in
  cleanliness.
* **Spread:** from 0.45 intensity, each neighbour catches fire with chance
  `0.035 × intensity` per step, × 0.2 into a covered room. Neighbours are the rooms side by
  side on a shared floor, or directly above or below. A room that has already burnt out
  does not re-ignite.

The fire is over when nothing burns any more.

**Sprinklers.** A working fire control room (condition above the equipment failure
threshold) covers the rooms whose floor is within ±15 floors of its own. In the tests, the
same office fire burns for 45 min unprotected (3 rooms, 1 tenant lost, $19,800), but only
4 min under sprinklers.

**Evacuation.** On ignition, everybody in the building heads out, by the **stairs only**:

* people in rooms move after a 20–120 s reaction time;
* people walking to or queuing for an elevator turn to the stairs at once;
* riders finish their ride and leave from where they get out.

While the fire lasts, nobody enters. Anyone whose event comes up in a burning building
goes out, and anyone outside checks again every 10 min, wanting to be where their schedule
says at that time. When the fire is out:

* workers go back to work, unless it is after hours;
* residents go home;
* staff pick up their jobs again (their job returns to the list during the fire).

Test `everybodyLeavesByTheStairsAndNobodyGoesIn`: 24 people inside, 0 after 12 min, and
no elevator boarding.

**Aftermath.**

* **Repairs:** a `Fire damage repairs` maintenance line is posted at $900 per module per
  floor of every room the fire reached, and repair jobs are opened for those rooms (the
  technicians do the work).
* **Lost tenants:** units whose condition ends below 0.25 are unusable, and their tenants
  move out.
* **Reputation:** the building loses 8 points.
* **Soot:** damaged rooms show soot until they are repaired.

## Weather incidents

`events.json` → `incidents`. These are checked hourly per building while today's weather
matches; the chance is `chancePerDay / 24`.

| Incident | Weather | Chance / day | Target | Effect |
|----------|---------|--------------|--------|--------|
| Storm damage | storm | 0.45 | any room | condition −0.35, cleanliness −0.4, $4,000 |
| Power outage | storm, heatwave | 0.20 | electrical plant | condition → 0: the plant fails, the tower loses power and light until repaired; reputation −2 |
| Burst pipe | snow, ≤ 0 °C | 0.35 | water plant | condition −0.6, cleanliness −0.5, $2,500; reputation −1 |

Repair and cleaning jobs are opened at once (not at the next 06:00 round). Every incident
is logged.

## UI

* **Alert banner** above the status pill:
  * while a fire burns: *"🔥 Fire in Small Office, 2 — 2 rooms burning, fire brigade in 9 min, building evacuated"*, with **Show**, which moves the camera to the fire;
  * other incidents raise a one-off alert.

  A dismissed fire alert stays dismissed.
* **Incidents panel** (⌥⌘I, flame button): fires in progress and the last 12 incidents.
* **Visuals:**
  * flames glow up from the floor and smoke gathers under the ceiling, both flickering in game time;
  * covered rooms show sprinkler spray;
  * a fire engine stands at the kerb once the brigade is there;
  * damaged rooms show soot until repaired.

## Save format

Format 11 adds `world.incidents` (the log, fires in progress, the id counter). See
SAVE_FORMAT.md.
