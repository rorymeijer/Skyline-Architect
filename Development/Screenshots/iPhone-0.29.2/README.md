# Every screen on the iPhone — 0.29.2

Real captures from the Debug build: the *screen tour* (`ScreenshotDirector+Tour.swift`),
taken by CI run 36580919345 for commit bcb5340 with the same script on three platforms:

- `mac/`: the macOS app, 1024 × 681 pt;
- `ipad/`: the iPad simulator, 1210 × 834 pt @2x;
- `iphone/`: the iPhone simulator, 852 × 393 pt @3x.

The tour opens every full-screen view and side panel once. Every capture is exactly the
display's size (2556 × 1179 px on the iPhone), so no screen is taller than the display.

The script set some scenes up:

- the demo tower is built and leased by developer tools;
- the fire is set by the developer tool;
- the tip, the won result (Opening Day, 3 stars, 1,250 points) and the bankruptcy are set
  directly.

| File | Screen |
|------|--------|
| `01-main-menu` | Main menu |
| `02-scenarios` | Scenario browser (compact on the iPhone: no summaries in the list) |
| `03-mods` | Mod manager |
| `04-demo-tower` | The game with no panel open |
| `05-saves` | Saves (no iCloud switch without iCloud) |
| `06-unit` | Unit inspector (an office) |
| `07-leasing` … `14-incidents` | Leasing, Economy, Facilities, Standing, Estate, Elevator Banks, Foundation, Incidents |
| `15-tip` | A first-time tip |
| `16-three-panels` | Economy, Facilities and Leasing at once (tabs) |
| `17-manual-search` | The manual searching "elevator" |
| `18-scenario-result` | The result screen (compact on the iPhone) |
| `19-bankruptcy` | The bankruptcy screen |

What the tour showed and what changed:

- **First run:** 8 of 19 iPhone screens were taller than the display (up to 1917 px):
  - the scenario browser and the result screen;
  - the Unit, Economy, Facilities, Standing and Estate panels;
  - three panels at once.
- **Fix:** views too tall for their room are drawn smaller in steps (90, 80, 75 %) through a
  layout (`ShrinkToFit.swift`). The scenario views got compact forms.
- **Second run:** three panels were still 4–13 pt too tall. They measured shorter than they
  laid out. A shrunk view now never reports more height than it is offered.
- **Third run (these files):** all 19 fit on all three platforms.

Not verified: how the smaller panels read on a real iPhone. At 75 %, captions are about 9 pt.
