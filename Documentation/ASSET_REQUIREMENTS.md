# Asset Requirements

What procedural generation in Skyline Architect can and cannot deliver, and exactly what
external (hand-made) art a production release needs. Programmer art in the current build
follows the art direction (realistic · clean · modern · architectural) but is **not**
production quality.

## What stays procedural (good enough, keep it)

| Area | Why procedural works | Status |
|------|----------------------|--------|
| Soil strata, terrain grain, foundations | Geometric, seeded variety, scales to any size | FUNCTIONAL |
| Building structure (slabs, columns, façades, roofs, shafts, stairs) | Derived from the model; must follow construction exactly | FUNCTIONAL |
| Distant skyline, neighbours | Silhouettes; atmospheric perspective hides detail | FUNCTIONAL |
| Room finishes (walls, floors, ceilings, lights) | Flat materials with gradients | FUNCTIONAL |
| Architectural grid, overlays, placement ghosts | UI geometry | FUNCTIONAL |
| Furniture at room/floor zoom (≤ ~40 pt/m) | Data-driven vector recipes read clearly at this scale | FUNCTIONAL (programmer art) |

## What needs external art

### 1. People (Phase 4) — **required**
- Side-view character sprites, ~1.7 m tall, readable from 20 pt/m (≈ 34 px) to 96 pt/m
  (≈ 160 px) → author at 192 px tall, downsample for smaller mip levels.
- Body types: at least 6 (adult ×4, older adult, child), 3 skin-tone palettes,
  swappable clothing layers (business, casual, uniform variants: technician, security,
  cleaner, firefighter, paramedic, police).
- Animations (8–12 frames each unless noted): idle (4), walk, carry/luggage walk, sit down /
  sitting (desk, sofa, bed lying), queue fidget (4), enter/exit elevator (turn), stairs up/down,
  typing at desk (4), eating, phone call.
- Format: sprite sheets (PNG, premultiplied alpha, sRGB) + JSON atlas (frame rects, pivots,
  frame durations); one sheet per body type × clothing layer so layers can be tinted.

### 2. Furniture close-ups — recommended for polish (Phase 20)
- Procedural recipes lack texture (fabric weave, wood grain, reflections) at interior zoom
  (> 40 pt/m). Provide per-piece sprites at 128 px/m for: desk, office chair, monitor,
  filing cabinet, meeting set, sofa ×4 colours, bed ×3, kitchen, kitchenette, fridge,
  bathroom pod, reception desk, lobby sofa, plants ×3, cars ×6 colours, AHU, pump set,
  electrical panel, wall art ×6.
- Same footprint (width × height in meters) as the recipe so layouts stay valid; the
  recipe remains the far-zoom LOD.

### 3. Elevator cars and doors (Phase 6) — recommended
- Car interior (side view) 2.1 × 2.4 m at 128 px/m with door open/close animation (8 frames).

### 4. Façade materials (Phase 20) — optional
- Tileable textures (512 px, seamless) for curtain-wall glass reflections, brick, stone,
  metal panels, to replace flat gradients at massing zoom.

### 5. Weather and effects (Phases 13–14) — required then
- Rain/snow particle sprites, smoke puffs (8-frame sheet), fire (12-frame sheet, additive),
  sparks, water spray.

### 6. UI iconography — optional
- The build palette uses SF Symbols; custom icons per room type would strengthen the identity.

## Technical constraints for any delivered art

- Side cutaway orthographic view, light from upper left, neutral daylight white balance.
- Meters are the unit: every asset states its real-world size; pixels per meter is fixed per
  mip level (32 / 64 / 128 px/m).
- No text baked into images (localization); no brand names or logos; no likenesses.
- Original work only — nothing traced or derived from existing games (see CLAUDE.md).
