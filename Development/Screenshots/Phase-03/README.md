# Phase 3 — Screenshots (first furnished rooms)

**Real screenshots of the running game** from the Debug build's screenshot director on a
GitHub Actions `macos-15` runner — CI run 36327134414, commit `dc4dfb3`, Skyline Architect
**0.3.0 (1)**, Debug, 1024 × 681 pt @1×, JPEG copies (quality 80). The demo tower is built
through the construction engine; all furniture comes from `furniture.json` + `interiors.json`.

| File | Demonstrates |
|------|--------------|
| `01-tower-facade.jpg` | Massing zoom (3.2 pt/m, tile level 1): the tower shows its **exterior curtain-wall façade** (glass, spandrels, mullions, glazed ground floor); the basement stays in section. |
| `02-cutaway-lod.jpg` | Same tower at 10.4 pt/m (tile level 3): past the LOD threshold the **furnished cutaway** replaces the façade. |
| `03-offices.jpg` | Offices: repeated workstations (desk, monitor, chair), filing cabinets, glazed doors, printers (narrow offices) or meeting set + whiteboard (≥ 10.5 m), plants; corridors with extinguishers and plants. HUD hidden. |
| `04-apartments.jpg` | Studio apartments: kitchen + fridge (≥ 7.5 m) or kitchenette (narrow), bed with seeded blanket colours, nightstand lamp, art; wide units get a bathroom pod (shower, toilet). |
| `05-lobby-parking.jpg` | Lobby (reception desk, sofa, directory board, plants, art) above the parking level with cars in seeded colours; mechanical room at right. |
| `06-mechanical-roof.jpg` | Top floor: air handling unit with duct, electrical panel, pump set, extinguisher; roof parapets and setback. |
| `07-new-office-furnished.jpg` | Built floor 9 and a 15 m office through the engine during the capture: it is furnished immediately (3 workstations, meeting set, whiteboard). |
| `08-save-load-roundtrip.jpg` | Save → load round trip: `worldIdentical=true`; camera kept across the load. |

## Measurements (`capture-report.json`)

| Capture | Zoom / LOD | Tile level | Tiles shown / cached | Raster ms/tile | FPS | Scene update ms | Nodes | Memory MB |
|---|---|---|---|---|---|---|---|---|
| 01 | 3.2 Massing | L1 | 8 / 23 | 17.4 | 60 | 0.10 | 95 | 147 |
| 02 | 10.4 Floors | L3 | 15 / 23 | 15.3 | 60 | 0.15 | 128 | 158 |
| 03 | 36 Rooms | L4 | 9 / 32 | 14.0 | 60 | 0.10 | 188 | 171 |
| 04 | 36 Rooms | L4 | 9 / 35 | 13.0 | 60 | 0.10 | 191 | 180 |
| 05 | 36 Rooms | L4 | 8 / 37 | 12.7 | 60 | 0.09 | 193 | 180 |
| 06 | 36 Rooms | L4 | 6 / 37 | 12.7 | 60 | 0.10 | 193 | 181 |
| 07 | 30 Rooms | L4 | 9 / 35 | 10.8 | 60 | 0.09 | 191 | 182 |
| 08 | 30 Rooms | L4 | 9 / 9 | 6.3 | 60 | 0.09 | 63 | 153 |

Raster time is the running average per 512 px tile on background threads (it includes the
first, heaviest tiles of the capture); the scene update stays at ~0.1 ms and frame rate at the
60 Hz display cap.

## Inspection notes — issues found and fixed

1. Mechanical rooms still drew the Phase 2 placeholder plant boxes behind the new furniture →
   placeholders only for unfurnished rooms.
2. Capture 08 claimed a preset was applied after loading; the camera is intentionally kept
   across a load → note corrected.
3. (Design iteration with `skyline-snapshot` previews before the CI run: layouts tuned so
   narrow studios fall back to a kitchenette and wide ones gain a bathroom.)

## Known visual limitations

- Furniture is **vector programmer art**: flat colours with simple shading, no textures;
  close-up sprites are listed in `Documentation/ASSET_REQUIREMENTS.md`.
- No people yet (Phase 4); rooms look staged.
- Room labels and grid show through the translucent build palette at the bottom.
- The LOD switch depends on pixel density (Retina switches at a lower zoom).
- Floor 9's unfurnished part and the shafts ending at floor 8 in capture 07 are the actual
  build state, not a rendering issue.
