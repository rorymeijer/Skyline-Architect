# Building

Everything stands on floors, and floors stand on the foundation. You build with the tools in the **build palette** at the bottom of the screen. When you pick a tool, a bar above the palette shows what it is, its size and what it costs: the smallest size, and the price per metre or per floor. Construction is paid at once from your cash.

## Floors

Pick **Floor** (`F`) and drag across the columns where you want a floor plate.

- Your first floors go on the foundation: the street level (G) and the basements the foundation has been dug for.
- Every upper floor must rest on the floor below it and may not stick out beyond it.
- A slab costs **$1,800** per metre, a basement slab **$3,200**.
- In the standard game the building's class limits the height: floor 12 at Class C, 25 at Class B, 45 at Class A and no limit at Prime (see [Standing](progression.md)). The sandbox has no limit.

Floors are numbered from the street: G is the ground floor, 1 is the first floor up, and B1, B2 are basements.

## Rooms

Every room type has its own button, grouped by category: circulation, offices, homes, plant, amenities. Pick one and **drag to set its width**; the width snaps to the room's limits. The preview is green with the name, width and price, or red with the reason it cannot go there.

- A room needs a floor at its level and may not overlap another room.
- Some rooms are only allowed on certain floors: a lobby on G only, a parking level in basements only, a sky bar from floor 15.
- Locked rooms have a small padlock. Their tooltip says what unlocks them.

| Room | Width | Cost per m | Rent per m | Notes |
|---|---|---|---|---|
| Lobby | 6–32 m | $900 | — | Ground floor only; the way in |
| Sky Lobby | 6–32 m | $1,100 | — | Class A; a transfer floor high up |
| Corridor | 2–48 m | $300 | — | Fills gaps between rooms |
| Stairwell | 4 m | $1,500 | — | A shaft, two floors or more |
| Elevator Shaft | 3 m | $4,500 | — | A shaft with one car |
| Express Elevator Shaft | 3 m | $7,500 | — | Class A; stops at both ends only |
| Service Elevator | 3 m | $3,800 | — | Class B; for your staff |
| Small Office | 6–16 m | $1,200 | $380 | Workers on weekdays |
| Studio Apartment | 6–10 m | $1,400 | $210 | Residents around the clock |
| Mechanical Room | 3–12 m | $2,000 | — | Water and climate |
| Electrical Room | 3–12 m | $5,200 | — | Electricity |
| Telecom Room | 3–8 m | $4,800 | — | Data |
| Parking Level | 8–32 m | $800 | — | Basements only |
| Fire Control Room | 4–6 m | $3,600 | — | Sprinklers for 15 floors up and down |
| Shop | 6–16 m | $1,300 | $320 | An amenity |
| Restaurant | 8–20 m | $1,600 | $280 | An amenity |
| Fitness Club | 8–16 m | $1,500 | $240 | Class B amenity |
| Cinema | 10–24 m | $1,700 | $200 | Class B amenity |
| Theatre | 12–32 m | $1,900 | $180 | Class A amenity |
| Sky Bar | 8–24 m | $2,100 | $360 | Class A amenity, floor 15 or higher |
| Waste Room | 2–8 m | $700 | — | Collects the building's waste |
| Staff Room | 4–10 m | $1,000 | — | Houses your staff |

Costs are for Port Calder; other cities build dearer or cheaper (see [Cities and land](estate.md)). Rooms furnish themselves to fit their width.

## Shafts

Stairwells and elevators are **shafts**: drag them upward across the floors they should serve, at least two. A shaft may stand in front of rooms: they stay whole behind it, and a room may also be built behind an existing shaft. Only another shaft blocks a shaft.

A shaft may reach past the building: drag it above the top floor or below the lowest basement, and the missing floor plates under the shaft are built with it, as wide as the shaft. The preview shows how many (*+2 new floors*), and the price includes them. Floors are only added where they may be built: basements need a dug foundation, and higher floors need the class, the piles and the scenario to allow them.

To make a shaft taller or shorter later, pick its tool and drag its top or bottom, or select it and use **Extend Up**, **Shorten Top**, **Extend Down** and **Shorten Bottom** in the inspector. See [Stairs and elevators](transport.md).

## The foundation

**Foundation** in the palette opens the foundation panel. Each button is one step with its price:

- **Widen Left** / **Widen Right**: one pile bay (4 m) wider, as far as the plot allows. Foundation costs $6,000 per metre.
- **Dig a Basement Level**: a deeper excavation, $4,000 per metre, up to the plot's limit.
- **Piles +5 m**: longer piles, $150 per metre.

## Undo, demolish and refunds

- **Undo** (`⌘Z`) and **Redo** (`⇧⌘Z`) work for every construction step, with the money: undo gives it back, redo charges it again. Buying land and loans cannot be undone.
- **Demolish** (`X`) removes the room under the cursor, or an empty floor that carries nothing above it. Demolishing refunds **40 %** of the cost and ends the lease of a unit.
- A flat you have sold belongs to its owner: you cannot demolish or cut it.

Press `Esc` to put the tool away.
