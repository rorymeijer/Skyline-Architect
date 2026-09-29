# Scenarios

Status: **FUNCTIONAL (Phase 16)**. Implemented:

* scenarios as content (`scenarios.json`): a start, starting cash, a time limit and objectives;
* objectives measured over the whole estate at every daily closing;
* winning (every objective held for the required closings in a row) and losing (bankruptcy, or the deadline passing);
* the scenario browser, the objectives panel (⌥⌘O) and the result screen;
* free play after the result;
* save format 13.

**PLANNED:**

* objectives on specific buildings or cities;
* optional bonus goals and scores or ratings;
* events scripted by a scenario (a storm on day 5, …);
* restrictions (rooms, loans, rent levels);
* a record of completed scenarios.

| Area | Code |
|------|------|
| Model (saved) | `SkylineCore/Scenario.swift` (`ScenarioState`, `ScenarioObjective`, `ScenarioMetric`, `ScenarioResult`) |
| Measuring and deciding | `SkylineSimulation/Scenarios.swift` (`Scenarios.measure`, `scenarioDaily`) |
| Content, validation, new game | `SkylineContent/ScenarioContent.swift` |
| Browser and panel data | `SkylineContent/ScenarioReports.swift` (`ScenarioBrief`, `ScenarioSummary`) |
| App | `AppModel+Scenarios.swift`, `Views/ScenarioViews.swift` |

## Rules

A scenario starts from a start in `starts.json`, which gives the city, the plot, the
foundation and standard or sandbox mode. The scenario may replace the start's cash. Its
objectives are **copied into the save**, so a save keeps its rules even if the content
changes.

Every daily closing at 06:00 runs these steps, after the rent, the tenant reviews and the
standing update:

1. Measure every objective.
2. If all are met, the streak grows; otherwise it resets to 0.
3. **Won** when the streak reaches `holdDays`.
4. Otherwise **lost** when the estate is bankrupt ("Bankrupt"), or when this was the closing
   of the last day ("Time ran out").

A scenario of `days: 10` has closings on days 1 to 10. The last one is the last chance.

The result is decided once. After that the game goes on as free play: the result screen
offers *Keep Playing*, *Scenarios…* and *Main Menu*.

The panel measures live, so its bars move during the day. Only the closings decide.

## Metrics

All metrics cover the whole estate.

| Metric | Measures | Met when |
|--------|----------|----------|
| `population` | tenant members (residents and workers; staff excluded) | ≥ target |
| `occupiedUnits` | rentable units with a tenant | ≥ target |
| `cash` | cash after the closing | ≥ target |
| `dailyProfit` | the last closing's operating result: rent + turnover + maintenance + utilities + wages + interest + taxes + waste (construction, land, loans and grants excluded; turnover, taxes and waste since Phase C) | ≥ target |
| `buildingClass` | best class index (0 = Class C, 1 = B, 2 = A, 3 = Prime) | ≥ target |
| `reputation` | best building reputation | ≥ target |
| `averageWait` | average elevator wait over every bank with at least 10 boardings (since the cars were built) | ≤ target; no data is not met |
| `properties` | properties owned | ≥ target |

## Base scenarios

| Scenario | Difficulty | Start | Days | Objectives |
|----------|-----------|-------|-----:|------------|
| Opening Day | Easy | Quay Street, $2.5M | 10 | 12 units let; daily profit ≥ $5,000 |
| Harbour Revival | Medium | Harbour Row, Saltmere, $1.5M | 30 | population 120; daily profit ≥ $4,000; held 3 closings |
| Three Properties | Medium | Quay Street, $2.5M | 60 | 3 properties; population 250; daily profit ≥ $10,000 |
| Crown Prestige | Hard | Crown Yard, Harrowgate, $5M | 45 | Class A; reputation 70; average wait ≤ 45 s |
| Skyline | Hard | Quay Street, $3M | 120 | population 1,500; average wait ≤ 60 s; daily profit ≥ $1; held 7 closings |
| Lean Tower (Phase C) | Hard | Quay Street, $3M | 30 | 20 units let; daily profit ≥ $15,000; held 3 closings. Rules: no apartments, floors up to 12, fixed rents, no staff |

**Testing and balancing:**

* Opening Day is tested to be winnable: the demo tower wins it on day 3.
* The other targets are first-pass balancing. They have not been played through.

## Scripted events, restrictions and scores (Phase C, 0.24)

Code: `SkylineSimulation/ScenarioEvents.swift`; model in `SkylineCore/Scenario.swift`.

### Events
Events are checked at every market hour. Each one fires once, at its scenario day and
hour (default 09:00), in content order. Nothing fires once the scenario is decided. Every
fired event adds a news line to the objectives panel.

| Kind | Effect |
|------|--------|
| `news` | Only the message. |
| `demand` | Prospects × `multiplier` for `days` days, for all tenant types or only `tenantType`. |
| `grant` | Pays `amount` if its condition `when` (an objective) is met, or always without one. |
| `fine` | Charges `amount` if `when` is *not* met, or always without one. |
| `weather` | Today's weather in the scenario's city becomes `weather` (heat also lifts the temperature to 34 °C). |
| `fire` | A fire starts in a rentable room of the scenario's building (deterministic). |

### Restrictions
| Restriction | Enforced by |
|-------------|-------------|
| `forbiddenRooms` | The construction engine; the palette shows the tool locked. |
| `maxFloor` | The construction engine. |
| `maxLoans` | `Economy.borrow`. |
| `fixedRent` | The rent level and unit rent controls. |
| `noStaff` | Hiring. |

### Scores
A win earns stars:
- one star for winning;
- one more for winning within 60 % of the days;
- one more when every objective beats its target by 25 % (an upper limit by staying 25 % under it).

Points: 1,000 plus the following.
- 50 per day left.
- Up to 250 per objective for beating it, with the full amount at twice the target.
- 2 × the best reputation.

A lost scenario scores 100 points per fully met objective, in proportion, and no stars.
A scenario may override these values with `scoring`.

### Completion record
The completion record is `scenario-records.json` in the saves folder. For each scenario it
keeps:
- the best stars and points;
- plays and wins;
- the fastest win and the first win.

It is updated once per decided play. Reloading a save never counts that play again. When
iCloud sync is on, both sides are merged, keeping the best. The browser shows each
scenario's record, rules and number of events. The result screen shows the stars, the points
and whether this play set a new best.

## Content format

```json
{
  "id": "harbour-revival", "name": "Harbour Revival", "difficulty": "medium",
  "summary": "One line for the list.", "briefing": "A paragraph.",
  "startID": "scenario-saltmere", "startingCash": 1500000, "days": 30, "holdDays": 3,
  "objectives": [{ "metric": "population", "target": 120 }, { "metric": "dailyProfit", "target": 4000 }]
}
```

Validation refuses a scenario when:

* its id is duplicated or its start is unknown;
* `days < 1`, or `holdDays` is outside 1…days;
* its cash is negative, or it has no objectives;
* a class target is not a class index from 1 up;
* a reputation target is outside 0…100;
* a count or wait target is not positive;
* an event has a day outside 1…days, no message, or incomplete kind fields;
* a restriction names an unknown room.

Phase C adds optional fields to a scenario:

```json
"restrictions": { "forbiddenRooms": ["apartment-studio"], "maxFloor": 12, "maxLoans": 2000000, "fixedRent": true, "noStaff": true },
"events": [{ "day": 4, "hour": 10, "kind": "grant", "message": "Early occupancy subsidy", "amount": 250000,
             "when": { "metric": "occupiedUnits", "target": 6 } }],
"scoring": { "fastShare": 0.6, "margin": 0.25, "winPoints": 1000 }
```
