# Stairs and elevators

Everyone who comes into the building walks in from the street through the lobby, then climbs or rides to their floor. How quickly they get there decides whether tenants stay.

## Stairs

People walk at 1.3 m/s and climb a storey in **14 seconds**. For one or two storeys they take the stairs; further up, a working elevator is quicker. A stairwell is also the way out during a fire, when nobody uses the elevators.

Floors that cannot be reached at all show up in the people count's tooltip as "cannot reach their room".

## Elevators

Each elevator shaft has one car. Build shafts side by side so they share the waiting crowd.

| Type | Car holds | Speed | Stops | Unlocks |
|---|---|---|---|---|
| **Elevator Shaft** | 13 people | 2.5 m/s | every floor | from the start |
| **Express Elevator Shaft** | 20 people | 6 m/s | its lowest and highest floor only | Class A |
| **Service Elevator** | 8 people | 1.6 m/s | every floor, staff only | Class B |

- In a tall tower, run an express shaft from G to a **Sky Lobby** and start a new bank of ordinary elevators there. People change cars in the sky lobby.
- Service elevators carry janitors and technicians only, so staff do not crowd your tenants' cars.
- People who wait too long give up and take the stairs if a stairs route of five minutes or less exists. The bank panel counts them as "took the stairs".

## Stops

Select an elevator shaft to see its **Stops**: one button per floor, top floor first. Tap a floor to switch it off, and tap it again to switch it back on. The car passes a switched-off floor, and people there walk to the nearest floor it still serves. At least two floors always stay on. An express shaft stops only at its ends, so it has no floors to switch off.

Every floor where the car stops shows its number in the shaft; a floor it passes shows none. Elevator shafts may stand in front of rooms. To see the rooms behind them, turn on **See-through Elevator Shafts** (`⌥⌘J`, or the stacked-squares button in the view controls).

## Banks and dispatching

Elevator shafts of the same type that stand next to each other and share floors form a **bank**. Open **Elevator Banks** (`⌥⌘E`) to see each bank's floors, cars, average and longest wait, and to choose how its cars are sent:

| Strategy | How it works |
|---|---|
| **Collective** | Each call goes to the car that can be there soonest; cars sweep up and down collecting calls. |
| **Zoning** | The floors are split into one zone per car. |
| **Destination** | People going to the same floor share a car. Good at the morning rush. |

A bank needs at least two cars before the strategy matters.

## Seeing the traffic

**Elevator Traffic** (`⌥⌘T`) draws a badge at every waiting crowd: how many are waiting and the longest wait, green under 30 s, amber under 60 s, red above. Zoomed in you also see how full each car is.

Waiting time matters: tenants weigh how long it takes to reach their unit (see [Tenants and units](tenants.md)), and short waits help your reputation (see [Standing](progression.md)).

## Wear and breakdowns

Every stop wears a shaft a little. Below half condition it asks for a technician. A badly worn car can **break down**: it stops, its passengers get out, and everyone else finds another way, often the stairs. A technician repairs broken cars before anything else. Keep enough technicians for the number of cars (see [Utilities and staff](facilities.md)).
