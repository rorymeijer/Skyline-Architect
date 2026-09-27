# Phase 10 — Screenshots (utilities + maintenance)

**Real screenshots of the running game**, taken by the Debug build's screenshot director on a
GitHub Actions `macos-15` runner. Details:

* CI run 36345637290, Skyline Architect **0.10.0 (1)**, Debug build.
* 1024 × 681 pt @1×, saved as JPEG copies.
* The director calls the same model functions as the facilities panel buttons (hire and dismiss staff) and the menu toggles. `capture-report.json` holds the numbers behind each caption.

| File | Demonstrates |
|------|--------------|
| `01-equipment-rooms.jpg` | Basement plant of the demo tower: telecom room (server racks), mechanical room, electrical room. Supply/demand: electricity 600/467, water 640/158, climate 1120/280, data 450/226. |
| `02-services-ok.jpg` | Day 1, 10:00. Services overlay (⌥⌘U) and facilities panel (⌥⌘F): every room is supplied, clean and sound (green). |
| `03-neglect.jpg` | Day 6, 10:00, no staff for 5 days. 15 cleaning jobs are open, average cleanliness is 59 % and condition 94 %. |
| `04-janitors-at-work.jpg` | Two janitors hired mid-shift; one is cleaning an office (teal coveralls) a minute later. |
| `05-plant-failure.jpg` | Day 26, still no technician. The mechanical and electrical rooms have failed (red), so 15 rooms are short of water and 17 of climate (orange). The panel asks for a technician. |
| `06-technician-repairs.jpg` | A technician hired and repairing the failed mechanical room (orange coveralls). |
| `07-restored.jpg` | Day 26, 18:00. Nothing is out of order: 4 repairs and 153 cleanings; wages $620 per day. |
| `08-save-load-roundtrip.jpg` | Save and reload with staff, open jobs and upkeep: `worldIdentical=true`. |

## Inspection notes

* **First run (CI run 36345094325):** captures 04 and 06 jumped to 07:00 the next morning. By then the hired staff had already cleared the backlog, so there was nobody at work to close in on. Both steps now capture right after hiring, while the jobs are still open, and were recaptured (CI run 36345637290). The captions report whether a staff member was found.
* **Tenant reaction:** in 05 no tenant has moved out yet. The equipment failed only recently, and it takes three bad daily reviews in a row to move out. This reaction is covered by `FacilitiesTests` rather than by a capture.
* **Abstract utilities:** there are no pipes or cables to draw. The overlay colours rooms by how well they are served.
