# Phase 9 — Screenshots (economy, day/night, main menu → M1)

**Real screenshots of the running game** from the Debug build's screenshot director on a
GitHub Actions `macos-15` runner — CI run 36343296837, Skyline Architect **0.9.0 (1)**,
Debug, 1024 × 681 pt @1×, JPEG copies. The director drives the same model calls as the
menus and buttons (start from menu, borrow, save, continue). This run walks the M1
checklist (see `Development/STATUS.md`).

| File | Demonstrates |
|------|--------------|
| `01-main-menu.jpg` | Launch: main menu (no saves yet: New Game and Load only). Game starts at 06:00 in daylight. |
| `02-build-and-pay.jpg` | New game; the demo tower built through construction commands and **paid**: $2,500,000 → $1,455,200 (−$1,044,800 construction). Economy panel open. |
| `03-first-rent.jpg` | Day 2, 06:05, after the first daily closing: rent $41,739 from 14 tenants (each line attributed), maintenance −$1,537, utilities −$196, interest −$110 on a $500,000 loan. |
| `04-dusk.jpg` | Day 2, 20:10: warm dusk tint, occupied homes lit, offices empty and dark. |
| `05-night.jpg` | Day 2, 23:00: blue night, lit homes, dim lobbies. |
| `06-economy-week.jpg` | Day 8, 07:00: cash $2,253,982; week income $311,743 vs expenses −$12,961; journal of the latest closing. |
| `07-menu-continue.jpg` | After saving and starting over: the main menu offers **Continue — M1 walkthrough**. |
| `08-continued.jpg` | Continue loads the save from disk: day 8, same cash and 15 tenants — `matches the save: true`. |

## Inspection notes

* First run (CI run 36342947845): the game's 06:00 start was still dark (sunrise was
  05:30–07:30), and the "first rent" step looked at day 1 before any closing. Fixed
  (sunrise 04:45–06:15, capture advances to day 2); recaptured.
* Night lighting is basic by design (multiply tint + additive room light); window
  emission and light sources are Phase 12.
