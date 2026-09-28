# Accessibility

Status:

* **FUNCTIONAL (Phase 20):**
  * VoiceOver names every icon-only control;
  * panels are grouped containers;
  * Reduce Motion is respected for flashing effects.
* **PLANNED:**
  * full keyboard navigation of panels;
  * Dynamic Type for panel text;
  * an increased-contrast panel style;
  * VoiceOver descriptions of the building itself (the SpriteKit world is not exposed).

| Area | What it does | Code |
|------|--------------|------|
| View controls (bottom right) | Each icon button reads its name without the shortcut ("Elevator Traffic"); toggles report "On". | `RootView.ControlButton` |
| Build palette | Each tool reads its name, the hint from its tooltip, and "Locked" or "Selected". This matters most in the icon-only palette (Phase 17). | `BuildPalette.ToolButton` |
| Speed buttons | "Pause" or "Speed 2×", marked selected. | `SimulationControls` |
| Panels | One card style (`panelCard()`), grouped as a container; the close button is named "Close". | `Views/PanelChrome.swift` |
| Saves panel | The delete button names the save it deletes. | `SavesPanel` |
| Mod manager | Order buttons read "Load earlier" / "Load later". | `ModManagerView` |
| Reduce Motion | No full-screen lightning flashes. Rain, snow and clouds keep moving: they are slow and carry the weather. | `Rendering/Motion.swift`, `WeatherLayer` |

**Keyboard.** Every panel and overlay has a menu command with a shortcut (View menu:
⌥⌘E/L/K/I/P/M/F/O/T/U/G). Space pauses and 1–6 set the speed.
