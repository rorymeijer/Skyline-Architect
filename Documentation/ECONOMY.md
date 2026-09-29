# Economy

Status: **FUNCTIONAL (Phase 9 subset)** — ledger with traceable transactions, construction
charged (and refunded exactly on undo), daily closing (rent, maintenance, utilities,
interest), loans, rent level, bankruptcy, economy panel. **PLANNED:** taxes, wages and
staff (Phase 10), per-unit rents, events affecting demand, reputation (Phase 11).

Code: `SkylineCore/Ledger.swift` (saved state), `Construction/ConstructionHistory.swift`
(construction charging), `SkylineSimulation/Economy.swift` (closing, loans, rent level,
panel data), content `economy.json`; app `EconomyViews.swift`, `AppModel+Economy.swift`.

## Ledger

`Ledger` holds cash, outstanding loans, a journal (the latest 400 transactions), per-day
totals per category (60 days), consecutive days in the red and the bankruptcy flag. Every
change is `Ledger.post(Transaction)`: a signed amount, a category (construction,
demolition, rent, maintenance, utilities, loan, interest, grant), a readable detail and the
building / room / tenant it belongs to. Cash therefore always equals the sum of all posted
transactions (tested). New games post their starting capital (`startingCash` in
`starts.json`, 2.5 M) as a grant.

## Construction

`ConstructionHistory` charges each performed command its plan cost (demolitions return
40 % as income). A command that costs more than the cash at hand is refused before the
world changes, and the placement preview shows *not enough money*. **Undo posts the exact
reversal** of what the step was charged; redo charges it again — the player never loses or
gains money by undoing. (Developer blueprints in Debug builds grant any shortfall as a
visible "Developer grant".)

## Daily closing (06:00, with the market step)

1. Rent from every tenant: agreed monthly rent / `rentDaysPerMonth`. The base content uses
   **1: one game day bills one rent month** (time compression — a game day lasts an hour at
   1×, so real monthly billing would take 30 hours of play).
2. Maintenance per building: Σ room `maintenancePerModulePerDay` × width × floors.
3. Utilities per building: people × `utilitiesPerPersonPerDay` + cars × `elevatorCarPerDay`.
4. Loan interest: loans × `loanInterestRate` / 365.
5. Bankruptcy: seven closings in a row with negative cash → the game ends (screen with New
   Game / Load).

### Phase E (0.23) additions to the closing

Wages are paid first, in the facilities step. The closing then continues:

- **Amenity turnover share** (0.22).
- **Waste collection:**
  - The building produces 1.2 kg per resident or worker and 0.3 kg per amenity customer a day.
  - Waste rooms take 80 kg per module a day. What they take is billed at $0.80/kg (`waste`).
  - The overflow dirties every room of the building: up to 0.25 cleanliness at full overflow.
- **Utilities and lighting** are multiplied by the city's **energy price**. It moves every
  morning by up to ±6 % of the city's base level, is pulled 30 % back toward it, and stays
  within half to twice the base. It is deterministic per city and day.
- **Property tax** per building: 0.4 % of its assessed value (what its plates and rooms
  cost to build at the city's prices) per closing, times the city's tax level. Levels:
  Harrowgate 120 %, Saltmere 85 %.
- **Profit tax:** 15 % of the closing's positive result (everything the closing booked,
  wages included). Nothing is charged on a loss.

Taxes are booked in the ledger category `taxes`.

## Player controls

* **Loans**: borrow / repay in steps of 500 k up to 5 M (economy panel).
* **Rent level** per building, 60–160 %: multiplies asking rents, so it changes how
  prospects and tenants appraise units (tested: at 150 % more prospects decline as too
  expensive and fewer sign). Signed rents are contracts and stay.
* **Unit rent** (Phase E), 60–160 % in 10 % steps, set in the unit inspector. It multiplies
  the building's level for that unit only (`Room.rentFactor`) and works the same way: for
  new leases and appraisal.

## Measured (demo tower, M1 capture run)

Building the demo tower costs 1,044,800 of the 2,500,000 start. A full tower bills about
45.6 k rent per day against 1.5 k maintenance, 0.2 k utilities and 0.1 k interest on a
500 k loan; after a week cash is back to 2.21 M. Balancing will continue as more costs
(staff, taxes) arrive.
