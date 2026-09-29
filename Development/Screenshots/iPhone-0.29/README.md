# The iPhone — 0.29.0 (F5)

Real captures from the Debug build, taken by CI run 36565637497 with the same script on three
platforms:

- `mac/`: the macOS app on a GitHub `macos-15` runner, 1024 × 681 pt.
- `ipad/`: the iPad app in the iPad simulator, 1210 × 834 pt landscape @2x.
- `iphone/`: the iPhone app in an iPhone simulator, 852 × 393 pt landscape @3x. These are the
  first iPhone captures of the project.

How the script set up the game:
- It starts the *First Tower* tutorial and builds its first steps through the player's own
  command path (`AppModel.perform`, with costs and undo).
- It opens the palette's Circulation category, the Leasing panel, the panel picker and the
  manual through the same properties the buttons set. On the Mac and the iPad the palette is
  not grouped, and the picker is opened by the script although their full view controls fit.

| File | What it shows |
|------|---------------|
| `01-main-menu.jpg` | The main menu. On the iPhone in two columns. |
| `02-tutorial-start.jpg` | The tutorial's first step. On the iPhone: the grouped palette, the narrow view controls, cash beside them, and the tutorial panel without the step list, clear of the Floor tool. |
| `03-tutorial-built.jpg` | Seven steps done, the Circulation category open. On the iPhone its tools show in a row above the categories, and the tutorial panel shrinks to the step's title and link to leave that row free. |
| `04-panel-picker.jpg` | The Leasing panel and the panel picker: every panel and overlay by name. |
| `05-manual.jpg` | The manual at *Stairs and elevators*. On the iPhone a Contents button replaces the chapter list, and the page holds as many lines as the card allows. |
| `06-manual-contents.jpg` | The manual's contents on the iPhone (two columns, with search). On the Mac and iPad the chapter list is already beside the page. |

What the captures showed and what was fixed:
- **First run:**
  - the time bar covered the property badge, and "30×" and "60×" wrapped;
  - the full view controls still fitted, so the picker never appeared, and it opened behind
    the Leasing panel;
  - the cash readout sat in the middle of the building;
  - panels were drawn under the palette;
  - manual pages held one paragraph.
- **Then:** the cash readout moved to the top left and collided with the time bar; it now sits
  beside the view controls.
- **Then:** the tutorial panel covered the Floor tool that its first step asks for; the left
  column now ends above the palette.
- **Then:** with a category open, the panel still did not fit and the capture grew to 416 pt
  tall; the panel now has a briefest form (title and link).

Not verified: touch on a real iPhone. Touch targets are below Apple's 44 pt (palette tools 40
pt, view controls 28 pt, speed buttons 22 pt).
