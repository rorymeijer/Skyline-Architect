# Phase 17 — Screenshots (modding)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36405609107 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.17.0 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the scenes were set up.**

* The script installs, enables and applies mods through the same calls as the mod
  manager's buttons, in the capture's own mods folder. The player's mods are never read.
* The broken mod "Harbour Lights" in 04 was **written by the capture script** to
  demonstrate validation reporting.
* The tower in 06 is built from the mod's blueprint (developer blueprint tool).
* Leasing is the simulation's own.

| File | Demonstrates |
|------|--------------|
| `01-mods-empty.jpg` | Main menu → *Mods…*: only the base pack; hints for installing mods. |
| `02-examples-installed.jpg` | *Install Examples* copied **Kestrel Bay** into the mods folder; switched on, pending *Apply*. |
| `03-mod-active.jpg` | After *Apply*: Kestrel Bay is active, adds 8 entries and replaces 1 (tenant 'couple'). Saves now list the packs `base` and `kestrel-bay`. |
| `04-broken-mod.jpg` | Harbour Lights references a room type nobody defines. It is **not loaded**: `[harbour-lights/rules] tenant 'lighthouse-keeper': unknown room type 'lighthouse-flat'`. Kestrel Bay and the base game load normally. |
| `05-scenario-from-mod.jpg` | The mod's scenario, **Kestrel Lofts**, appears in the scenario browser with its briefing. |
| `06-kestrel-bay.jpg` | Day 2, 19:00 in **Kestrel Bay** (the mod's city: its own seed, skyline and ground). Pier Lofts was built from the mod's blueprint and tenants signed, including the mod's Creative Household type. The palette shows icons only because the mod's Loft Apartment makes it too wide for 1024 pt. |
| `07-loft-close-up.jpg` | A **Loft Apartment** (a mod room, 10 m wide, furnished from the mod's layout) let to a couple. The Couple tenant type was replaced by the mod so couples rent lofts too. |
| `08-save-load.jpg` | Saved and reloaded with the mod (`worldIdentical=true`). The same save checked against the base pack alone is refused: *The save needs content pack 'kestrel-bay', which is not installed.* |

## Inspection notes

* **Two app builds failed before the first capture**, both fixed:
  * a capture-script expression too complex for the type checker;
  * reading an observable property before `init` finished.
* **Fixed after the first captures:**
  * The validation message named every rule file (`[pack/schedules/names/rooms/…]`); it
    now reads `[pack/rules]`.
  * With the mod's extra room, the build palette was wider than a 1024 pt window and ran
    off screen. A first fix made it scroll, but a `ScrollView` does not render in captures,
    so the palette vanished from them. It now switches to icon-only buttons when the
    labelled palette does not fit (names stay in the tooltips).
* **The loft reuses the studio's furniture** (the mod copies the layout). Mods cannot yet
  ship images.
