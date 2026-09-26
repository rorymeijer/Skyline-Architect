# Decision Log

Format: DATE · DECISION · CONTEXT · ALTERNATIVES · REASON · CONSEQUENCES.

---

## D-001 — Xcode app project + local Swift package
- **Date:** 2026-09-26
- **Decision:** One Xcode project (`SkylineArchitect.xcodeproj`) with a single multiplatform app target (macOS + iPadOS). All engine code lives in a local Swift package `Packages/SkylineKit` split into modules.
- **Context:** Must be buildable/editable in Xcode; engine must be testable without rendering; macOS + iPadOS share engine code.
- **Alternatives:** (a) package-only (Xcode can open it, but SPM cannot produce a proper app bundle with Info.plist/iPad settings); (b) separate app targets per platform; (c) XcodeGen/Tuist (third-party tooling).
- **Reason:** Module boundaries are enforced by the compiler; package tests run with `swift test` anywhere; one multiplatform target avoids duplicated build settings while allowing `#if os(macOS)` platform-specific interaction files.
- **Consequences:** Platform-specific UI code lives in `App/` behind `#if os(...)`. If macOS and iPad UIs diverge a lot later, split into two targets sharing `App/Shared`.

## D-002 — Engine modules import only Foundation and build on Linux
- **Date:** 2026-09-26
- **Decision:** `SkylineCore`, `SkylineContent`, `SkylinePresentation`, `SkylineSnapshot` must not import Apple UI/graphics frameworks and must build/test on Linux.
- **Context:** Hard separation of model/simulation from rendering/UI (brief §30); development partially happens in a Linux container; CI Linux runners are cheap and fast.
- **Alternatives:** Allow CoreGraphics types (CGPoint/CGRect) in the model.
- **Reason:** Own `Vec2`/`Rect` types remove ambiguity (CGFloat vs Double), keep the model portable and make the boundary compiler-enforced.
- **Consequences:** Small conversion code in the App layer (`Vec2` ↔ `CGPoint`).

## D-003 — Drawing IR + tiled rasterization for static art
- **Date:** 2026-09-26
- **Decision:** Procedural art is produced as a platform-neutral vector drawing IR (`Drawing`: rects, polygons, polylines, ellipses; solid/linear-gradient paints; per-item minimum detail) in `SkylinePresentation`. The App rasterizes it with CoreGraphics into quadtree tiles (512 px + 1 px bleed) shown as `SKSpriteNode`s. `skyline-snapshot` renders the same IR to SVG.
- **Context:** Need realistic, detailed, *scalable* rendering of huge buildings; SKShapeNode is slow and aliasing-prone at scale; art must be testable and previewable headlessly.
- **Alternatives:** (a) SKShapeNode per primitive; (b) hand-built SKSpriteNodes per element; (c) Metal shaders directly; (d) pre-made bitmap assets only.
- **Reason:** Tiles bound GPU cost by screen area rather than building size, give automatic LOD (detail thresholds per tile level), and cache well. IR keeps art logic testable and moddable. Bitmap sprites/sheets remain possible later for characters/animation (AssetPipeline).
- **Consequences:** Static changes (construction) must invalidate affected tiles (Phase 2: dirty-rect invalidation). Animated/dynamic elements (people, elevator cars) will be sprites, not tiles.

## D-004 — Scene = viewport; camera transform on a `worldRoot` node
- **Date:** 2026-09-26
- **Decision:** The SKScene size equals the view size in points. The camera is applied as scale/position of a `worldRoot` node instead of `SKCameraNode`.
- **Context:** Screen-space overlays (grid, labels, HUD) and in-app screenshot capture.
- **Alternatives:** SKCameraNode with overlay nodes as camera children.
- **Reason:** Scene coordinates are screen points ⇒ `SKView.texture(from: scene)` captures exactly what the player sees; conversion math lives in the tested `Camera2D`.
- **Consequences:** Parallax, if added, is done by offsetting layer nodes manually.

## D-005 — Flat, insertion-ordered entity stores with typed 32-bit IDs; per-property coordinates
- **Date:** 2026-09-26
- **Decision:** `GameWorld` stores cities, properties, buildings in `EntityStore<ID, Value>` (array + index), with back references for the hierarchy. IDs are `EntityID<Tag>` (UInt32) from a world counter. Each property has its own local meter coordinate space.
- **Context:** Multiple buildings/properties/cities; determinism; save size; scale.
- **Alternatives:** Deeply nested value types; dictionaries; UUIDs; one global coordinate space.
- **Reason:** Deterministic iteration (Swift dictionaries are randomly ordered per process), compact IDs, simple mutation, stable save output.
- **Consequences:** Referential integrity is validated by model methods and tests.

## D-006 — Swift 6 language mode for the package, Swift 5 mode for the app target
- **Date:** 2026-09-26
- **Decision:** Package: Swift tools 6.0, Swift 6 language mode (strict concurrency). App: `SWIFT_VERSION = 5.0`.
- **Context:** SpriteKit/AppKit/UIKit are main-thread frameworks whose concurrency annotations vary across SDK versions; overriding `SKScene.update(_:)` etc. from `@MainActor` types produces SDK-dependent errors.
- **Alternatives:** Swift 6 everywhere.
- **Reason:** Strict checking where our threading logic lives (engine, future simulation host); pragmatic stability for the thin UI shell.
- **Consequences:** Revisit when Apple frameworks are fully annotated. App code must still marshal background work (tile rasterization) explicitly to the main queue.

## D-007 — Content as declarative JSON packs from Phase 1
- **Date:** 2026-09-26
- **Decision:** Cities, plots and game starts are defined in JSON inside a base content pack (package resource). Loader validates ids and references.
- **Context:** Brief §8, §27: data-driven content, future mods, no giant switches.
- **Alternatives:** Swift literals now, JSON later.
- **Reason:** Cheap to start now; prevents engine code from growing content assumptions.
- **Consequences:** Every new content type needs a definition struct + validation + tests.

## D-008 — Verification through GitHub Actions (Linux + macOS), in-app screenshot capture
- **Date:** 2026-09-26
- **Decision:** CI runs package tests on Linux and macOS, builds the app for macOS and iPad Simulator, then launches the macOS app with `--capture-screenshots` which renders deterministic camera presets and writes PNGs uploaded as artifacts.
- **Context:** Development sessions may run in a Linux container without Xcode; the brief mandates real screenshots of the running game.
- **Alternatives:** Only local screenshots by the developer; XCUITest screenshots; `screencapture` (needs Screen Recording permission).
- **Reason:** In-app capture of the SKView (scene = viewport, D-004) needs no OS permission and captures real rendered output. The SwiftUI HUD is composited on top from the real view via `ImageRenderer`.
- **Consequences:** Capture code is Debug-only. The HUD in captures is rendered separately from the window server (documented in each screenshot README).

## D-009 — Roadmap re-ordering
- **Date:** 2026-09-26
- **Decision:** Local saves → Phase 2; sim clock/speeds → Phase 4; basic day/night → Phase 9; M1 First Playable at end of Phase 9. See ROADMAP.md.
- **Reason:** The first playable milestone and visual vertical slice require these earlier than the original numbering.

## D-010 — Xcode 16 synchronized folders (project objectVersion 77)
- **Date:** 2026-09-26
- **Decision:** `App/` is a `PBXFileSystemSynchronizedRootGroup`.
- **Reason:** Files added to `App/` join the target automatically; the project file stays tiny and merge-friendly, and can be edited without Xcode.
- **Consequences:** Requires Xcode 16 or newer.

## D-011 — Swift Testing for automated tests
- **Date:** 2026-09-26
- **Decision:** Use the Swift Testing framework (`import Testing`) for package tests.
- **Reason:** Ships with Swift 6 toolchains on macOS and Linux; parameterized tests suit simulation cases.

## D-012 — SwiftUI-drawn chrome controls
- **Date:** 2026-09-26
- **Decision:** Floating game controls use custom `ButtonStyle`s and plain SwiftUI shapes instead of platform-styled `Button`/`Menu`/materials.
- **Context:** The first CI capture showed AppKit-backed controls as placeholders in `ImageRenderer` output.
- **Alternatives:** Capture the window through ScreenCaptureKit (needs Screen Recording permission, unavailable on CI).
- **Reason:** Captures must show what the player sees; a consistent game-styled HUD is also the desired look.
- **Consequences:** Native macOS menus remain for app-level commands; in-world chrome is custom-drawn.
