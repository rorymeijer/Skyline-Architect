# Graphics

## Art direction

Realistic · clean · modern · architectural · detailed. Not cartoon. Materials read as
real materials (concrete, steel, glass, soil), lit from a soft sky with ambient
occlusion at contacts. Colours are muted; saturated colour is reserved for UI accents,
warnings and the blueprint-cyan grid overlay.

## Pipeline (Phase 1 — FUNCTIONAL)

```
model ──SiteComposer──▶ SiteComposition (layers of Drawing IR, world meters)
                         │
          ┌──────────────┴───────────────┐
          ▼                              ▼
  App: DrawingRasterizer (CG)     skyline-snapshot: SVG writer
  → 512px tiles → SKSpriteNodes   (design previews, NOT screenshots)
```

* **Drawing IR** (`SkylinePresentation/Drawing`): rect, polygon, polyline, ellipse;
  solid and linear-gradient fills; strokes; `minDetail` = minimum pixels-per-meter at
  which the item is drawn (fine texture only appears when it can be seen).
* **Procedural recipes** (`SkylinePresentation/Art`): seeded and deterministic —
  the same world always produces the same art.
  * `TerrainArt` — paved grade strip & curb, topsoil/clay/sand/gravel/bedrock strata
    with material-specific grain (speckles, pebbles, fissures), depth darkening.
  * `FoundationArt` — excavation, diaphragm retaining walls with panel joints, raft
    slab, bored piles with cylindrical shading, grade slab, starter rebar at column
    lines, formwork tie holes and pour lines on the exposed back wall.
  * `BackdropArt` — distant city silhouettes in atmospheric perspective with faint
    window grids, generated per city seed.
* **Tiles:** level L has 2·2^L px/m; a view picks the level matching zoom × backing
  scale. Old-level tiles stay visible until replacements finish (no pop-to-empty).

## Furniture and interiors (Phase 3 — FUNCTIONAL, programmer art)

* `furniture.json`: each piece is a list of vector parts (rect, ellipse, polygon, line) in
  local meters with material keys from `materials.json`, optional vertical shading,
  per-part detail thresholds and material variants (e.g. car colours, blankets).
* `interiors.json`: per room type, items anchored left/right/center with offsets,
  elevations (monitor on desk, art on wall), width conditions (`minRoomWidth`,
  `maxRoomWidth`) and repeat groups (workstations, parked cars).
* `LayoutResolver` (pure, deterministic) places items without overlaps; variants are
  seeded per room and storey. `FurnitureArt` converts placements into drawing items.
* Furniture defaults to `minDetail` 10 px/m: it disappears at massing zoom.

## Exterior façade LOD (Phase 3)

Drawing items carry a detail band `[minDetail, maxDetail)`. Above grade, the cutaway
(shells, rooms, furniture, end walls) is drawn from `BuildingArt.cutawayDetail` = 6 px/m;
below that an exterior curtain wall (glass with sky reflection, spandrel bands, mullions,
glazed ground floor) replaces it. Because tiles choose detail from zoom × backing scale,
the switch happens at ~5 pt/m on 1× displays and ~2.5 pt/m on Retina — a pixel-density
based LOD, not a fixed zoom. Below-grade levels always stay in section.

## LOD bands (`DetailLevel`)

| Band | Points per meter | Intended content (future phases) |
|------|------------------|----------------------------------|
| skyline | < 1.5 | massing, lit windows as pixels |
| massing | 1.5 – 5 | façades, floor lines |
| floors | 5 – 14 | room outlines, elevator cars, people as dots |
| rooms | 14 – 40 | furniture silhouettes, people sprites |
| interior | ≥ 40 | full furniture, animated people, labels |

## Known limitations (Phase 1)

* All art is procedural programmer art with a deliberate art direction; it is **not**
  production-quality. `ASSET_REQUIREMENTS.md` lists the external art a release needs
  (characters, furniture close-ups, elevator cars, façade materials, effects).
* No lighting model yet (day only; day/night lands in Phase 9/12).
* No shaders yet; depth comes from gradients and contact darkening.

## Day/night (Phase 9, basic) — FUNCTIONAL

`DayNight` (Presentation) gives daylight 0…1 from the time of day (sunrise 04:45–06:15,
sunset 19:00–21:00), an ambient multiply colour (white → warm at dusk → blue night) and the
rooms lit from inside (occupied rooms fully, lobbies/corridors dimly). The app draws a
screen-sized multiply sprite over the world and additive warm quads over lit rooms; UI and
labels stay untinted. Purely presentational — the simulation never reads it. Full lighting
(light sources, window emission, grading, energy) is Phase 12.
