# Accessibility and the iPad — 0.28.0 (F4)

Real captures from the Debug build, taken by CI run  with the same script on two platforms:

- `mac/`: the macOS app on a GitHub `macos-15` runner, 1024 × 681 pt.
- `ipad/`: the iPad app in the iPad simulator on the same runner, 1210 × 834 pt landscape
  @2x. These are the first iPad captures of the project.

How the script set up the game:
- It builds the demo tower with the developer blueprint and leases it with the developer tool
  (sandbox).
- It sets the text size through the same property as the menu.
- It presses Esc through the same handler the key uses.

| File | What it shows |
|------|---------------|
| `01-main-menu.jpg` | The main menu with the new **Text Size** button at Standard. |
| `02-panels-standard.jpg` | The Economy, Facilities and Leasing panels at Standard (tabs, because they do not all fit). |
| `03-panels-larger.jpg` | The same at Larger. |
| `04-panels-largest.jpg` | The same at Largest. The panel widens, so amounts stay on one line. |
| `05-manual-largest.jpg` | The manual at Largest: fewer lines per page, and the card grows. |
| `06-menu-over-game.jpg` | The main menu over the running game, with **Resume** first. Main Menu and Save buttons sit at the left of the view controls. |
| `07-escape.jpg` | After Esc twice: the menu closed (the game resumed), then the lowest panel (Leasing) closed. Economy and Facilities remain and now fit without tabs. |

What the captures showed and what was fixed:
- **First run:**
  - On the Mac, Standard and Largest were identical: SwiftUI on macOS ignores Dynamic Type.
    The Mac now sizes its text styles itself (`Font.ui`).
  - On the iPad the text grew but the panel did not, so amounts wrapped mid-number. Panels
    and columns now widen with the text (`scaledFrame`).
- **Second run:** the manual at Largest on the iPad ran outside its card. The card height and
  the lines per page now follow the text size.

Not visible in captures: the Tab focus ring and the iPad hardware keyboard both need a person
with a keyboard (OPEN_ITEMS V2).
