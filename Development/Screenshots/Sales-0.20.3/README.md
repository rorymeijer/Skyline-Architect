# 0.20.3 — Screenshots (flats for sale)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36464936417 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.20.2 (1)** (built before the 0.20.3 version bump), Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the scenes were set up.**

* The script builds the demo tower in the sandbox and leases it with the developer tools.
* It **empties** the studios (their tenants move out) and sets the weather to clear.
* It offers the studios for sale through `offerSelectedUnit(forSale:)`, the inspector
  button's model call.
* The buyers are the market's own, on day 2.

| File | Demonstrates |
|------|--------------|
| `01-vacant-flat.jpg` | A vacant studio (asking $1,764/month) with *Offer for Sale · $176,400* in the inspector. |
| `02-for-sale.jpg` | Every studio labelled *For sale*. The inspector shows the price, the service charges that follow ($441/month) and *Rent Out Instead*. |
| `03-sold.jpg` | Day 2: all 7 studios sold ($1,293,500). A sold studio shows its owner, the purchase price and the service charges; its label reads "Coelho · owner". |
| `04-economy.jpg` | The economy panel with a *Sales* line and "Sale — Studio Apartment …" and "Service charges — …" entries. The leasing panel is a tab. |

**Inspection.** In the first run the owners' labels ("… household · owner") were too wide
for a studio and were hidden. They are now "Rinaldi · owner" (commit 916ef84); this set is
from the run after that fix.
