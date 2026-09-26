# Phase 1 — Screenshots (renderer, camera, architectural grid)

**These are real screenshots of the running game**, captured automatically by the Debug
build's screenshot director (`--capture-screenshots`, see `App/Diagnostics/ScreenshotDirector.swift`)
on a GitHub Actions `macos-15` runner, CI run #5, commit `6981841`.

- Build: Skyline Architect 0.1.0 (1), Debug, macOS, Xcode 16 (runner default).
- Window: 1024 × 681 pt at 1× (the CI display is small; the default window is 1440 × 900).
- Method: SpriteKit scene captured via `SKView.texture(from:crop:)` (scene = viewport),
  SwiftUI chrome (title badge, developer HUD, view controls) rendered from the same views via
  `ImageRenderer` and composited on top. Each capture waits until the camera is at rest and
  every wanted tile is displayed (`settled: true` in `capture-report.json`).

| File | Demonstrates |
|------|--------------|
| `01-overview.png` | Site overview (7.3 pt/m, LOD *Floors*): Quay Street Lot in Port Calder, neighbouring masonry and glass buildings, distant skyline, soil strata section, prepared foundation, architectural grid with floor labels (G, 1…, B1–B3), grade line, dashed plot boundary. |
| `02-foundation.png` | Foundation framing (22 pt/m, LOD *Rooms*): basement box, raft, retaining walls with toes, eight bored piles into bedrock, starter bars on bay lines, material grain (gravel pebbles, bedrock bedding planes and fissures). Hover cell highlight at the view center (HUD: `col 24, B3`). |
| `03-detail.png` | Close-up (64 pt/m, LOD *Interior*, tile level 5): cut concrete with aggregate stipple, rebar in the raft section, basement back wall with pour lifts, tie holes and ambient occlusion, starter rebar, excavation halo, 1 m module grid. |
| `04-skyline.png` | Maximum-style zoom-out (0.45 pt/m, LOD *Skyline*, tile level 0): the grid continues upward without a floor limit (labels every 10 floors up to 360+ in view); distant skyline across the full width. |
| `05-overview-no-grid.png` | Same as 01 with the grid toggled off — the pure rendered world. |

## Measurements (from `capture-report.json`)

| Capture | Zoom / LOD | Tile level | Tiles shown / cached | Avg raster ms/tile | FPS | Scene update ms | Nodes | Memory MB |
|---|---|---|---|---|---|---|---|---|
| 01-overview | 7.26 Floors | L2 | 9 / 28 | 6.8 | 60 | 0.10 | 95 | 148 |
| 02-foundation | 21.98 Rooms | L4 | 15 / 40 | 8.1 | 60 | 0.12 | 107 | 164 |
| 03-detail | 64 Interior | L5 | 9 / 49 | 9.1 | 60 | 0.09 | 116 | 180 |
| 04-skyline | 0.45 Skyline | L0 | 24 / 73 | 5.4 | 60 | 0.14 | 197 | 205 |
| 05-overview-no-grid | 7.26 Floors | L2 | 9 / 73 | 5.4 | 60 | 0.09 | 197 | 209 |

FPS is capped by the runner's 60 Hz display. Raster time is per 512 px tile on a background queue.

## Inspection notes

Issues found in the first CI capture (run #4) and fixed before these final captures:
1. View controls rendered as yellow “unavailable” placeholders — `ImageRenderer` cannot draw
   AppKit-backed `Button`/`Menu`. Replaced with SwiftUI-drawn controls (also gives one-click presets).
2. Pile reinforcement bars read as red edge artifacts at close zoom — made thinner and fainter.

Earlier design iterations (via `skyline-snapshot` previews) fixed: full-scale backdrop towers looking
adjacent to the plot (now reduced scale + haze); world visibly ending at far zoom (terrain now ±6 km).

## Known visual limitations

- All art is procedural programmer art following the art direction; **not production quality**.
- Distant skyline has no parallax; at mid zoom it still reads somewhat close behind the plot.
- Only day lighting; no shadows beyond gradient ambient occlusion; no people, rooms or furniture yet.
- The developer HUD covers the left edge of the view and can hide floor labels there (Debug only).
- Retina (2×) rendering was not captured (CI display is 1×); tile level selection accounts for
  backing scale but is unverified on a Retina screen.
- In captures the SwiftUI chrome is rendered separately via `ImageRenderer`; translucent
  materials are not used in the chrome for that reason.
- Interactive input (trackpad direction, inertia feel, pinch) cannot be exercised by CI and has
  only been verified by unit tests of `CameraController`, not by hand.
