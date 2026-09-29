# Balance

Status: **FUNCTIONAL** (F1, 0.25). The balance bot (`Sources/SkylineBot`) plays every scenario
the way a player does:
- it builds through the construction engine, which charges every command;
- the market does the leasing;
- it gets no developer grants.

Every morning it builds up to three storeys while the cash stays above a reserve of 50,000.
- **Tower layout:** a core in the middle (stairs, two elevators, a service elevator), a wing of
  units on each side (offices on two floors of three, flats on the third), and plant in the
  basement and on every sixth floor.
- **Elevators:** a second elevator from six floors up; a service elevator once the building
  reaches Class B.
- **Staff and land:** it hires staff when allowed and buys land when an objective asks for properties.
- **What it cannot do:** it does not widen foundations, and does not build express elevators,
  sky lobbies or amenities.

A bot win proves a scenario can be won by a plain strategy. A player can do better.

Run it with `swift run -c release skyline-balance [--scenario id] [--out file.md]`. The whole set
takes about 10 seconds.

## Findings and changes (F1)

1. **High offices could not be let.**
   - *Cause:* asking rents rise 1 % per storey, but tenant budgets did not. Above about the
     12th floor every office priced itself out of the market (call centre and design studio
     declined as "too expensive"), and towers stood half empty.
   - *Fix:* budgets now rise with the same height premium (D-056).
2. **Class A was out of reach without widening the foundation.**
   - *Cause:* it needed 150 people, while Class B stops at floor 25, and a 32-module
     footprint houses about 5 people per floor.
   - *Fix:* Class A now needs 100 people and Prime 250.
3. **Scenario targets.**
   - Opening Day (won on day 3) is raised to 16 units and 2,000.
   - Harbour Revival is set to population 100; Three Properties to 160; Skyline to 600.
   - Crown Prestige (won on day 8) now asks reputation 75 and waits ≤ 30 s, held 5 closings,
     within 30 days.
   - Lean Tower (won on day 9) now asks 0,000 a day, held 10 closings.
4. **A crash.** A repaired elevator's first event could fall in the past (arithmetic overflow in
   the boarding wait). Repairs now schedule the car's event at once.

## Bot results after tuning

| Scenario | Result | Day | Stars | Points | Floors | Population | Units | Lowest cash | Objectives (last measured) |
|----------|--------|----:|------:|-------:|-------:|-----------:|------:|------------:|-------------|
| Opening Day | won | 5 | 3 | 1807 | 18 | 84 | 26 | 353483 | Units let ≥ 16: 26 ✓; Daily profit ≥ $12,000: 64938 ✓ |
| Harbour Revival | won | 26 | 1 | 1653 | 16 | 114 | 32 | 275164 | Population ≥ 100: 114 ✓; Daily profit ≥ $4,000: 70163 ✓ |
| Three Properties | won | 45 | 1 | 2225 | 46 | 205 | 76 | 319883 | Properties ≥ 3: 3 ✓; Population ≥ 160: 205 ✓; Daily profit ≥ $10,000: 226437 ✓ |
| Crown Prestige | won | 12 | 2 | 2146 | 33 | 154 | 54 | 459542 | Building class ≥ Class A: 2 ✓; Reputation ≥ 75: 84 ✓; Average elevator wait ≤ 30 s: 25 ✓ |
| Skyline | lost (time ran out) | 120 | 0 | 233 | 46 | 200 | 76 | 354168 | Population ≥ 600: 200 ✗; Average elevator wait ≤ 60 s: 41 ✓; Daily profit ≥ $1: 226845 ✓ |
| Lean Tower | won | 14 | 2 | 2047 | 13 | 72 | 20 | 1158383 | Units let ≥ 20: 20 ✓; Daily profit ≥ $40,000: 55228 ✓ |

- **Opening Day** (0 s): 26 of 30 units let; prospects 121, signed 26, moved out 0; declined: noVacancy 95, tooExpensive 0, poorAccess 0, tooNoisy 0, poorView 0, poorServices 0. set up · D2 second elevator · D4 service elevator
- **Harbour Revival** (0 s): 32 of 32 units let; prospects 518, signed 33, moved out 1; declined: noVacancy 485, tooExpensive 0, poorAccess 0, tooNoisy 0, poorView 0, poorServices 0. set up · D2 second elevator · D7 service elevator
- **Three Properties** (1 s): 76 of 76 units let; prospects 1859, signed 79, moved out 3; declined: noVacancy 1780, tooExpensive 0, poorAccess 0, tooNoisy 0, poorView 0, poorServices 0. set up · D1 bought Harbour Row · D2 second elevator · D24 blocked: Unlocks at Class A · D25 blocked: Unlocks at Class A · D26 blocked: Unlocks at Class A · D26 service elevator · D40 blocked: Unlocks at Prime
- **Crown Prestige** (0 s): 54 of 54 units let; prospects 277, signed 54, moved out 0; declined: noVacancy 223, tooExpensive 0, poorAccess 0, tooNoisy 0, poorView 0, poorServices 0. set up · D2 second elevator · D4 service elevator · D8 blocked: Unlocks at Class A
- **Skyline** (6 s): 76 of 76 units let; prospects 3802, signed 88, moved out 12; declined: noVacancy 3714, tooExpensive 0, poorAccess 0, tooNoisy 0, poorView 0, poorServices 0. set up · D2 second elevator · D4 service elevator · D31 blocked: Unlocks at Prime · D32 blocked: Unlocks at Prime · D33 blocked: Unlocks at Prime · D34 blocked: Unlocks at Prime · D35 blocked: Unlocks at Prime
- **Lean Tower** (0 s): 20 of 20 units let; prospects 387, signed 20, moved out 0; declined: noVacancy 367, tooExpensive 0, poorAccess 0, tooNoisy 0, poorView 0, poorServices 0. set up · D2 second elevator · D4 blocked: This scenario allows floors up to 12 · D4 service elevator · D5 blocked: This scenario allows floors up to 12 · D6 blocked: This scenario allows floors up to 12 · D7 blocked: This scenario allows floors up to 12 · D8 blocked: This scenario allows floors up to 12


## Reading the table

- **Skyline** is lost by the bot: 600 people need Prime above floor 45, which takes an express
  elevator and a sky lobby, and the bot does not build those. A player can.
- "noVacancy" declines are mostly prospects for amenity operators and room types the bot does
  not build. They are not a shortage of units.
