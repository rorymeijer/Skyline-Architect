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
| `dailyProfit` | the last closing's operating result: rent + maintenance + utilities + wages + interest (construction, land, loans and grants excluded) | ≥ target |
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

**Testing and balancing:**

* Opening Day is tested to be winnable: the demo tower wins it on day 3.
* The other targets are first-pass balancing. They have not been played through.

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
* a count or wait target is not positive.
