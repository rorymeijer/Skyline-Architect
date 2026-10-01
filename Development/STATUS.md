# Development Status

_Last updated: 2026-10-01 (0.30.4 — shape a held room from both ends, move it exactly)_

## Current phase
**Next round (the player's plan):**

| Step | Content | State |
|------|---------|-------|
| F1 | Balance bot and tuning | COMPLETE (rorymeijer/Skyline-Architect#31) |
| F2 | 500 floors running smoothly | COMPLETE (rorymeijer/Skyline-Architect#32) |
| F3 | Tutorial, in-game manual, website (`Website/`) | COMPLETE (rorymeijer/Skyline-Architect#33) |
| F4 | Accessibility and iPad | COMPLETE (rorymeijer/Skyline-Architect#34) |
| F5 | iPhone | COMPLETE (rorymeijer/Skyline-Architect#35) |

**0.29.2:** App Store preparation (D-062):
- Every screen fits an iPhone. A capture screen tour of 19 screens found 8 that were too
  tall; side panels and cards now shrink in steps, and the scenario views have compact forms.
  Evidence: all 19 tour captures at the display's size on Mac, iPad and iPhone
  (`Development/Screenshots/iPhone-0.29.2/`).
- `Documentation/APP_STORE.md` holds every App Store Connect field and the App Review notes.
  The website has support and privacy pages (not published: the owner decides).
- App Store screenshots come from the game itself (`Development/Screenshots/AppStore/`).
- Review risks removed: the iCloud switch without iCloud, the unreachable mods folder on iOS,
  and the encryption question.

**0.30.4:** from the owner's iPhone recording: a held room only grew to the right and was
hard to put in the right place. `PlacementPlanner.edited` (`HeldEdit`: left/right edge, move;
PlacementEditTests) drives the bar's Left, Move and Right buttons (Bottom, Move and Top for new shafts). Not checked on a device.

**0.30.3:** `ToolSummary` (ToolSummaryTests) names the picked tool with its size and price in
`ToolInfoBar` above the palette; rooms may set `icon` (elevators and hotel rooms now differ).
Tour step 24 captures it. Build numbers now come from Xcode Cloud (D-067).

**0.30.2 (build 6):** the owner found that Longer/Shorter did not change a held room.
`PlacementPlanner.nudgedVisibly` steps the end until the ghost changes, and
`PlacementPlanner.tapped` moves a held room to a tapped floor (PlacementTests; from the
owner's iPad recording of 0.30.1).
Merged 0.30.1 was PR #41.

**0.30.1 (build 5):** a shaft placed or extended past the existing floors builds the
missing floor plates first, in one batch (`ConstructionEngine.addingFloors`, ShaftTests).
Used by shaft drags and the inspector's Extend Up/Down. FUNCTIONAL in the package tests; not
checked in a capture. Housekeepers (D-066): a separate staff role makes up hotel rooms;
HotelTests run ten days (with a technician: without one the only elevator breaks down on
day 4 and staff cannot reach the hotel floor, which is correct). Capture 21 now puts a second
elevator in front of rooms; captures 22–23 hide the tool tip; 23 shows the second night.

**0.30.0 (build 4):** the owner's elevator requests. FUNCTIONAL in the package tests; the
app side is checked by CI captures 20 and 21 of the screen tour.
- Shafts stand in front of rooms (D-064); rooms stay whole and may go behind a shaft.
- Stops per car (`ElevatorStops`, save format 19): the inspector shows one button per floor.
- Floor numbers in the shaft where the car stops; see-through shafts (`⌥⌘J`).
- Touch placement (iOS): a held ghost with a bar (size, price, ±, Cancel, Place); taps
  move its end; drags from its end stretch it; two fingers pan; a drag scrolls at the screen
  edge. `PlacementPlanner.nudged` is tested; the rest is app input. Tour step 22 captures the
  bar. Not checked on a device.
- Hotel rooms (HOTELS.md, D-065, save format 20): single, twin and suite. Nights are booked
  from 15:00, guests sleep there and check out in the morning, and the room then waits for a
  janitor. FUNCTIONAL in the package tests (HotelTests, SaveV20Tests). Tour step 23 captures
  them. Balance not played over long games.

**0.29.4 (build 3):** on the iPhone, the scenario browser still ran off the screen with a
long briefing (*Lean Tower*). The shrink steps assumed the smallest step would fit. Now
`fitsScreen()` wraps every full-screen ladder (`shrinkToFit`, the scenario browser and
result, the main menu). It proposes the screen's height, so the ladder still picks the step
that fits, and it puts the card in a scroll view only when even the smallest step is taller
than the screen. `ScaledLayout` no longer hides a real overflow; it still absorbs one of up
to 12 pt.
Learned from the CI captures: (1) a scroll view *inside* `ViewThatFits` gets its tiny ideal
height and vanishes; (2) the capture tool draws the chrome with `ImageRenderer`, which
leaves any scroll view blank. The scrolling case can therefore not be shown by a capture.
It is SCAFFOLDED until checked on a device, with *Lean Tower* in the scenario browser.

**0.29.3 (build 2):** on iPad and iPhone the mods folder did not show in the Files app.
`INFOPLIST_KEY_UIFileSharingEnabled` is not a build setting Xcode knows, so the key was
dropped without an error. It now comes from `Config/Info-iOS.plist`, and CI checks the built
Info.plist (`Scripts/check-files-app.sh`, green). Not verified on a device yet: this needs a
new TestFlight build.

**Mods:** `Mods/` holds 24 community content mods: cities, rooms and tenants, amenities,
elevators, rule changes, scenarios, furniture and blueprints (see `Mods/README.md`).
None of them changes the base pack. FUNCTIONAL: `CommunityModsTests` loads each mod on its own
and all together, places every new room, starts every scenario and builds the blueprints.
Not verified: in-game screenshots of the new interiors, and long-game balance. Mod blueprints
cannot be picked in the game yet.

**Docs:** `Documentation/MOD_AUTHORING_PROMPT.md` is a shareable brief/AI prompt for making
content mods (format version 1), with a headless validation snippet. Documentation only.

**0.29.1:** the Mac app runs in the App Sandbox, which the Mac App Store requires (D-061).
CI checks the entitlement in a signed Release build. Not verified here: the upload to App
Store Connect itself (done by the owner from Xcode).

F5 (merged) runs the game on an iPhone in landscape (D-060). It is not a separate interface: each
view falls back to a compact form where the full one does not fit.
- **Build palette:** tools grouped under five categories; a tap opens one category's tools
  in a row above.
- **View controls:** camera buttons only; the panels and overlays sit in a picker, by name.
- **Cash and standing:** bottom left beside the view controls, clear of the time bar.
- **Main menu:** two columns. **Manual:** a Contents button in place of the chapter list;
  pages hold as many lines as the window allows.
- **Tutorial panel:** the current step only, ending above the palette so its tools stay free.
- Panels are now drawn above the palette on every platform.
- CI launches the iPhone build in an iPhone simulator (`Scripts/capture-simulator.sh`).

Evidence: CI captures on the Mac, the iPad and the iPhone
(`Development/Screenshots/iPhone-0.29/`, CI run 36565637497). Found and fixed in the captures: the time bar over
the cash readout, wrapped speed labels, the picker behind a panel, one-paragraph manual pages,
the tutorial panel over the Floor tool, and the chrome outgrowing the screen with a category open. Not verified by a person: touch on a real iPhone;
touch targets are below Apple's 44 pt (OPEN_ITEMS V2).

F4 (merged) made the game usable with larger text and a keyboard, and ran the iPad for the first
time (ACCESSIBILITY.md, D-059):
- **Text size** (Standard, Large, Larger, Largest) for all panels, menus and the manual.
  - The first captures showed that SwiftUI on macOS ignores Dynamic Type. The Mac now sizes
    its text styles itself (`Font.ui`).
  - Panels widen with the text, so amounts no longer wrap mid-number (seen on the iPad).
- **Esc** closes what is on top, one thing per press.
- **Focus rings** on every button, for the system's Tab navigation.
- **The iPad:**
  - it runs in the simulator in CI with the Mac's capture script;
  - with a keyboard, the game keys and the menu shortcuts work;
  - Save and Main Menu buttons, and Resume in the menu over a running game.

Evidence: CI captures on the Mac and the iPad at three text sizes, the manual at Largest, the
menu over a game, and Esc (`Development/Screenshots/Accessibility-0.28/`). Not verified by a
person: Tab focus, the iPad keyboard, touch on a real iPad (OPEN_ITEMS V2).

F3 (merged) added the tutorial *First Tower*, a 14-chapter manual in the game and on the
website (`Website/`), and first-time tips (MANUAL.md, D-058).

F2 (merged): a 526-floor tower simulates 2.5× faster, with its worst step at 134 ms and the
daily closing at 65 ms (PERFORMANCE.md, D-057).

## Quality gates (0.20.1)
| Gate | Status | Evidence |
|------|--------|----------|
| Compiles (macOS + iPad Simulator) | ✅ | CI run 36444953400 |
| Automated tests pass | ✅ | 290 tests (Linux + macOS): per-city weather, v14 migration and fixture, pack hashes, estate split, camera inset, particle scale, city activity |
| Game launches | ✅ macOS (CI) · ⚠️ iPad built, not launched | |
| Fixes demonstrable | ✅ | CI run 36445406112: 7 captures in `Development/Screenshots/Fixes-0.20.1/` (weather, grant and panel openings set by the script — labelled) |
| Obvious runtime errors fixed | ✅ | captures settle, exit 0 |
| Documentation updated | ✅ | OPEN_ITEMS, SAVE_FORMAT (v14), ESTATE, WEATHER, LIGHTING, MODDING, DECISIONS D-046/D-047, CHANGELOG 0.20.1, ROADMAP |
| Screenshots produced & inspected | ✅ | The estate capture first fell outside the 24 h window (estate $0): script adjusted and recaptured |
| Known issues recorded | ✅ | below |

## Completed
- Phases 0–20 (merged: rorymeijer/Skyline-Architect#1 … #20).
- 0.20.1:
  - **B1** side panels become tabs when they do not fit (`PanelStack`).
  - **B2** the camera may look 150 pt below the ground; presets frame above the build bar.
  - **B3** weather per city (save format 14, migration, golden fixture v14).
  - **B4** one account for the estate — kept by design (D-046).
  - **B5** a content hash per pack in saves; changed packs are reported on load.
  - **B6** the estate overview splits building and estate money and shows each city's weather.
  - **B7** rain and snow scale with the zoom.
  - **B8** city windows go out through the night; street lamps stay on (own tile layer).

## Whole-game review (end of the roadmap)
- **FUNCTIONAL, with tests and real captures:**
  - construction with undo;
  - people and navigation;
  - elevators, banks and dispatch;
  - tenants and the market;
  - economy;
  - facilities;
  - progression;
  - lighting;
  - weather;
  - emergencies;
  - estate and cities;
  - scenarios;
  - modding;
  - versioned saves (format 14);
  - save sync logic;
  - performance at scale;
  - polish.
- **Implemented but unverified:**
  - iCloud Drive (needs a signing team);
  - the iPad (built on CI, never launched);
  - performance on real Apple hardware (only CI VMs and a Linux container).
- **Not done:**
  - human play test and balancing (only Opening Day is proven winnable);
  - Dynamic Type;
  - keyboard navigation inside panels;
  - removing entries or shipping images in mods;
  - a background simulation thread (D-044).

## Known bugs / unverified
- With many panels open the tab row can get wide (nine tabs ≈ 650 pt); fine on the tested 1024–1440 pt windows.
- The daily closing is still a 100 ms spike on very large towers; night window panes cost 4–5 ms per frame on the 211-floor tower.
- Accessibility is verified by code review only, not with VoiceOver on a device.
- Earlier notes still apply (STATUS history in git): scenario balance. Which city windows are lit does not change through the night, only how many show.

## Technical debt
- Utility allocation is a full recomputation (about 4 ms at 400 floors).
- Window panes are separate nodes.
- Simulation on the main thread.

All open items in one checklist: `Documentation/OPEN_ITEMS.md`.

## Suggested next steps (beyond the roadmap)
1. A human play test on a Mac and an iPad, followed by a balancing pass (scenario targets, tenant budgets, costs).
2. A signed build with iCloud, then verify sync between two devices.
3. Dynamic Type, keyboard navigation of panels, and a VoiceOver pass on a device.
4. A background simulation actor if the play test shows the daily-closing hitch.

## Environment
- Cloud sessions run in a Linux container without Xcode. To build/test the package there,
  install Swift from the official Docker image layers (download.swift.org is blocked):
  pull `library/swift:6.1-noble` layers via the Docker registry API, extract the toolchain
  layer into `/opt/swift`, apt-install its runtime deps (binutils libc6-dev
  libcurl4-openssl-dev libedit2 libgcc-13-dev libpython3-dev libsqlite3-0 libstdc++-13-dev
  libxml2-dev libncurses-dev libz3-dev pkg-config tzdata zlib1g-dev) and use
  `PATH=/opt/swift/usr/bin:$PATH`. `apt-get install librsvg2-bin` for SVG previews.
- If package tests crash with a segfault after model layout changes, it is a stale
  incremental build on Linux: `rm -rf Packages/SkylineKit/.build` and rebuild.
- GitHub artifact/log blob storage (`productionresultssa*.blob.core.windows.net`) is blocked
  by this environment's network policy. CI therefore commits the latest captures to
  `Development/Screenshots/_ci-latest/` — `git pull` after a CI run to inspect them.
- The app target is verified by macOS CI (`.github/workflows/ci.yml`, runs on every push to
  `claude/**`); screenshots are uploaded as the `phase-screenshots` artifact.

## Local verification (on a Mac)
```sh
Scripts/test-package.sh
Scripts/build-app.sh && Scripts/capture-screenshots.sh /tmp/skyline-shots
open SkylineArchitect.xcodeproj   # run the SkylineArchitect scheme on "My Mac"
```
