# Tutorial, manual and tips — 0.27.0 (F3)

Real in-game captures from the macOS app (Debug), taken by CI run 36546858116
(`--capture-screenshots`, GitHub `macos-15` runner, 1024 × 681 pt).

How the script set up the game:
- It starts the tutorial with the menu's own call.
- It builds the first seven steps through the player's command path (`AppModel.perform`,
  with costs and undo). No command was refused.
- It then lets three game hours pass.
- Each tip was raised by the game itself, not by the script.

| File | What it shows |
|------|---------------|
| `01-main-menu.jpg` | The main menu with **Tutorial** first and **Manual** last. |
| `02-tutorial-start.jpg` | *First Tower* just started, paused at 06:00. The tutorial panel is at step 1 of 10, the objectives panel on the right. |
| `03-tutorial-built.jpg` | After the construction steps: 7 of 10 done, the current step is "Let the first units", and four vacant units. |
| `04-first-tip.jpg` | 09:00: four tenants have signed. The game raised the tip "Your first tenant" and the tutorial moved on to "Hire a janitor". |
| `05-manual.jpg` | The manual at "Stairs and elevators", page 1 of 3, with the chapter list on the left. |
| `06-manual-search.jpg` | Searching for "sprinklers" finds two chapters, each with the matching table row or sentence. |
| `07-manual-table.jpg` | The longest table (rooms, in "Building"): it fits the page without clipping. |

`website/` holds Chromium renderings of the website (`Website/`), not game captures:
- the landing page on the desktop and on a phone (dark);
- the manual's contents page;
- a chapter in dark mode;
- the keyboard chapter on a phone.

What the captures showed and what was fixed:
- **First run:** the renderer used for captures cannot draw AppKit-backed controls (scroll
  view, text field, progress bar, system button styles), so they appeared as yellow
  placeholders. The help views were rebuilt in plain SwiftUI: the manual pages instead of
  scrolling, and the Mac search field is drawn and takes typed keys.
- **Second run:** search snippets showed a table's header, and pages ended too early. The
  snippets now show the matching row or sentence, and the page size follows the measured line
  length.
