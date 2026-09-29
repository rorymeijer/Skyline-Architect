# Economy and facilities — 0.23.0 (Phase E)

Real in-game captures from the macOS app, taken by CI run 36524083998 (`--capture-screenshots`).

How the script set up the scene:
- It builds `demo-plaza` in the sandbox and leases every unit with the developer tools.
- Rent and staff changes use the panels' own model calls.
- The breakdown is **forced**: the script sets the first car's shaft condition to 0.02, then lets the simulation run until the car breaks down.
- Everything else (closing, taxes, waste, energy price, repair) is the simulation's.

| File | What it shows |
|------|---------------|
| `01-unit-rent.jpg` | An office's own rent raised to 130 % with the inspector's +; it now asks $5,138 a month (the rent criterion drops). |
| `02-staff-room.jpg` | Five hires pressed: 4 of 4 staff-room places taken, the fifth refused. The idle staff wait in the staff room next to the waste room. |
| `03-economy.jpg` | After a closing: Taxes (property tax $8,422 and 15 % profit tax $9,047), Waste $156, and the energy price 0.99×. |
| `04-breakdown.jpg` | The worn car broke down in the basement: dark cab with a warning band; the facilities panel reports it. |
| `05-repaired.jpg` | 45 minutes later, a technician has repaired the shaft first and the car runs again (1 breakdown so far). |

Inspected: the panels are readable, the numbers match the closing, and the warning band shows on the broken car.
