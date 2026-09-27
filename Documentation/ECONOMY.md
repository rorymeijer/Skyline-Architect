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

## Player controls

* **Loans**: borrow / repay in steps of 500 k up to 5 M (economy panel).
* **Rent level** per building, 60–160 %: multiplies asking rents, so it changes how
  prospects and tenants appraise units (tested: at 150 % more prospects decline as too
  expensive and fewer sign). Signed rents are contracts and stay.

## Measured (demo tower, M1 capture run)

Building the demo tower costs 1,044,800 of the 2,500,000 start. A full tower bills about
45.6 k rent per day against 1.5 k maintenance, 0.2 k utilities and 0.1 k interest on a
500 k loan; after a week cash is back to 2.21 M. Balancing will continue as more costs
(staff, taxes) arrive.
