# Phase 2 — Screenshots (construction + saves)

**Real screenshots of the running game**, captured automatically by the Debug build's
screenshot director on a GitHub Actions `macos-15` runner — CI run 36306205755, commit
`74289b0`, Skyline Architect **0.2.0 (1)**, Debug, 1024 × 681 pt @1×. JPEG copies (quality 80)
of the PNG captures; the director drives the *real* model through the same code paths as the
player (construction engine, undo history, save store).

| File | Demonstrates |
|------|--------------|
| `01-empty-foundation.jpg` | New sandbox game: foundation only, building preset framing. |
| `02-demo-tower.jpg` | The `demo-tower` blueprint applied as 58 player commands through the engine: B1 parking + mechanical, lobbies, 4 office floors, 4 apartment floors (setback at 7–8), stairwell and elevator shaft B1–8, roofs with parapets. Build palette generated from content; session cost $1,044,800 (not yet charged). |
| `03-interiors.jpg` | Room shells with finishes at 30 pt/m (grid off): offices (glazed doors, ceiling lights), lobbies (stone panels), corridors, parking markings, mechanical plant, stairwell flights, hoistway with landing doors; room labels. |
| `04-core-detail.jpg` | 64 pt/m close-up of the core: stair flights with treads and half landings, handrail, hoistway rails, landing doors and hall-call indicators. |
| `05-place-floor-valid.jpg` | Floor tool dragging storey 9 across the setback roof: green ghost, label “Floor 9 · 24 m · $43,200”. |
| `06-place-room-invalid.jpg` | Office tool in the basement: red ghost, label “Small Office: Not allowed on this floor” (rule from `rooms.json`). |
| `07-save-load-roundtrip.jpg` | Saved to a slot and reloaded through `SaveStore`/`SaveCodec`: `worldIdentical=true` (see report). Camera kept across the load. |
| `08-after-undo.jpg` | After the reload: built floors 9 and 10, undid floor 10 → floor 9 remains as an empty shell with its own roof; only changed tiles re-rendered. |

## Measurements (`capture-report.json`)

| Capture | Zoom / LOD | Tiles shown / cached | Raster ms/tile | FPS | Scene update ms | Nodes | Memory MB |
|---|---|---|---|---|---|---|---|
| 01 | 27.7 Rooms | 9 / 25 | 13.8 | 60 | 0.15 | 97 | 148 |
| 02 | 10.4 Floors | 15 / 24 | 14.6 | 60 | 0.14 | 129 | 165 |
| 03 | 30 Rooms | 12 / 30 | 15.0 | 60 | 0.16 | 156 | 173 |
| 04 | 64 Interior | 9 / 39 | 16.8 | 52 | 0.11 | 165 | 183 |
| 05 | 10.4 Floors | 15 / 39 | 16.8 | 60 | 0.16 | 165 | 186 |
| 06 | 10.4 Floors | 15 / 39 | 16.8 | 57 | 0.16 | 165 | 186 |
| 07 | 10.4 Floors | 15 / 15 | 20.8 | 50 | 0.21 | 105 | 158 |
| 08 | 9.8 Floors | 15 / 15 | 19.3 | 60 | 0.11 | 108 | 162 |

FPS dips (50–57) coincide with bursts of background tile rasterization right after camera
jumps / world reloads on the 3-core CI runner; steady-state is 60 (display cap).

## Inspection notes — issues found and fixed during this phase

1. Basement rooms painted over the retaining walls → walls redrawn after rooms.
2. Stair flights low-contrast against the shaft → darker shaft, outlined lighter flights.
3. Build palette: `body` too complex for the type checker (CI build failure) → split views.
4. Refusal labels (red text on dark pill) hard to read → white text on a red pill.
5. “Elevator Shaft” truncated in the palette → “Elevator”.

## Known visual limitations

- Rooms are **finished shells**: no furniture, people or elevator cars yet (Phases 3, 4, 6).
- Mechanical plant and parking details are placeholder programmer art.
- Narrow rooms (≤ 8 m at mid zoom) hide their labels to avoid clutter.
- Floor slabs run through stair shafts (no slab openings drawn).
- Retina (2×) not captured; CI display is 1×. Developer HUD covers the left edge (Debug).
