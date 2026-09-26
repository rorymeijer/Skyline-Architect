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
  production-quality. A later `ASSET_REQUIREMENTS.md` will list external art needs
  (characters, furniture sprite sheets, façade materials).
* No lighting model yet (day only; day/night lands in Phase 9/12).
* No shaders yet; depth comes from gradients and contact darkening.
