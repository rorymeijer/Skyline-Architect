# Accessibility

Status:

* **FUNCTIONAL (Phase 20):**
  * VoiceOver names every icon-only control;
  * panels are grouped containers;
  * Reduce Motion is respected for flashing effects.
* **FUNCTIONAL (F4, 0.28):**
  * **Text size** for panels, menus and the manual (Standard, Large, Larger, Largest); on an
    iPad, Standard follows Dynamic Type;
  * **Esc** closes what is on top, one thing per press;
  * **focus rings** on every custom button for Tab navigation;
  * the **iPad keyboard**: the game view's keys and the menu shortcuts;
  * **Save** and **Main Menu** by touch on the iPad.
* **PLANNED:**
  * an increased-contrast panel style;
  * VoiceOver descriptions of the building itself (the SpriteKit world is not exposed).

| Area | What it does | Code |
|------|--------------|------|
| View controls (bottom right) | Each icon button reads its name without the shortcut ("Elevator Traffic"); toggles report "On". Main Menu and Save come first (F4). | `RootView.ControlButton` |
| Build palette | Each tool reads its name, the hint from its tooltip, and "Locked" or "Selected". This matters most in the icon-only palette (Phase 17). | `BuildPalette.ToolButton` |
| Speed buttons | "Pause" or "Speed 2×", marked selected. | `SimulationControls` |
| Panels | One card style (`panelCard()`), grouped as a container; the close button is named "Close". | `Views/PanelChrome.swift` |
| Saves panel | The delete button names the save it deletes. | `SavesPanel` |
| Mod manager | Order buttons read "Load earlier" / "Load later". | `ModManagerView` |
| Reduce Motion | No full-screen lightning flashes. Rain, snow and clouds keep moving: they are slow and carry the weather. | `Rendering/Motion.swift`, `WeatherLayer` |
| Text size (F4) | `.dynamicTypeSize` on all chrome. The panels use text styles, so they grow with it; the palette and view-control icons keep their size. | `TextSizeSetting.swift`, `RootView` |
| Esc (F4) | One per press: the tool, a tip, the manual, saves, mods or scenarios, the menu over a game (resumes), the selection, then the lowest open panel. | `AppModel+Keyboard.swift` |
| Focus rings (F4) | A 2 pt accent ring around the focused control (`isFocused`), on every custom button style. | `PanelChrome.focusRing` |
| Tutorial and tips (F3) | The step list reads "Done", "Current step" or "To do"; a tip is a container named "Tip: …". | `HelpViews` |

## Keyboard

On a **Mac**:

* Every panel and overlay has a menu command with a shortcut (View menu:
  ⌥⌘E/L/K/I/P/M/F/O/T/U/G).
* In the game view, Space pauses, 1–6 set the speed, F and X pick tools, WASD, the arrows
  and Q/E move the camera, and Esc closes what is on top.
* File ▸ Main Menu is `⇧⌘M`, and Help ▸ Skyline Architect Manual is `⌘?`.

On an **iPad with a keyboard** (F4):

* The game view takes the same keys (`GameSKView+iOS.pressesBegan`).
* The same commands are available with the same shortcuts; iPadOS lists them when you hold ⌘.

**Tab navigation:** with *Keyboard navigation* (Mac) or *Full Keyboard Access* (iPad) turned
on in the system settings, Tab moves between the buttons of the panels and menus. The focus
ring shows where you are, and Space presses the button.

## What is verified, and how

* **Text size:** CI captures on the Mac and in the iPad simulator show the same panels at
  Standard, Larger and Largest (`Development/Screenshots/Accessibility-0.28/`).
* **Esc:** a capture step presses Esc twice and reports what closed.
* **iPad keyboard and Tab focus:** these need a real keyboard. They are built and compiled in
  CI but have not been tried by a person (OPEN_ITEMS).
