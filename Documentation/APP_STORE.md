# App Store Connect — every field

What to enter in App Store Connect for Skyline Architect, field by field, for the Mac, iPad
and iPhone. The store text is in English because the game is in English.

The owner still has to decide or supply the items marked **▶ DECIDE**.

Checked against the code on 2026-09-29 (0.29.x):

- no network access;
- no analytics, ads or tracking;
- no in-app purchases;
- no cryptography;
- iCloud not yet enabled.

## 1. New app (My Apps ▸ +)

| Field | Value |
|-------|-------|
| Platforms | iOS and macOS. One app record; the iPhone and iPad builds use the iOS platform, the Mac build the macOS platform. |
| Name | `Skyline Architect` (17 of 30 characters). If the name is taken: `Skyline Architect: Towers` |
| Primary language | English (U.S.) — or English (U.K.): the game uses British spelling ("storey", "flat", "colour") |
| Bundle ID | `app.skylinearchitect.SkylineArchitect` (register it under Certificates, Identifiers & Profiles if it is not in the list) |
| SKU | `SKYLINE-ARCHITECT-001` (internal, never shown) |
| User access | Full access |

## 2. App information (General ▸ App Information)

| Field | Value |
|-------|-------|
| Subtitle (30) | `Build upward. Keep it moving.` (29) |
| Category, primary | Games |
| Games subcategory 1 | Simulation |
| Games subcategory 2 | Strategy |
| Content rights | "No, it does not contain, show, or access third-party content." All art is procedural and made for the game; there are no licensed assets. |
| Age rating | See §6 → **4+** |
| License agreement | Apple's standard EULA |

## 3. Pricing and availability

| Field | Value |
|-------|-------|
| Price | **▶ DECIDE** (for example Tier €9.99 / $9.99; the game has no ads or purchases inside) |
| Availability | All countries or regions |
| Pre-orders | Optional |
| Apple silicon Mac (iPhone app on Mac) | **Off**: the Mac has its own native build |
| Apple Vision Pro | Off (not tested) |

## 4. The version page (per platform: iOS and macOS)

### Promotional text (170)

> A tower-building game in cross-section. Lay the floors, run the elevators, let the offices and flats, and keep every resident and worker on the move.

(149 characters. Can be changed at any time without a new review.)

### Description (4000)

> Build upward. Keep the building moving.
>
> Skyline Architect is a tower-building management game in cross-section. Lay the floors, run the elevators, let the offices and flats, and keep every resident, worker and visitor on the move, from a four-storey block to a tower of five hundred floors.
>
> BUILD IN CROSS-SECTION
> Floors, lobbies, offices, flats, plant rooms and amenities on a metre grid, over a foundation you widen and dig deeper. Every step can be undone.
>
> EVERY PERSON SIMULATED
> Residents, office workers, visitors and your own staff follow their day: to work, out for lunch, home in the evening, all walking and riding for real.
>
> ELEVATORS THAT MATTER
> Banks of cars, express shuttles to sky lobbies, service elevators, three dispatch strategies, and traffic you can see waiting on every landing.
>
> TENANTS WITH OPINIONS
> Prospects weigh rent, access, noise, view and services before they sign, and move out when they are unhappy. Rent your flats out or sell them.
>
> RUN THE BUILDING
> Electricity, water, climate and data from your own plant rooms; janitors and technicians; waste, taxes, energy prices, loans, and a daily closing at 06:00.
>
> WEATHER, NIGHT AND FIRE
> Seasons, storms and heatwaves, a city that lights up at night, and fires your sprinklers and the brigade have to put out.
>
> THREE CITIES
> Buy land in Port Calder, Harrowgate and Saltmere, each with its own market, ground and weather, all on one account.
>
> SCENARIOS AND A TUTORIAL
> A step-by-step tutorial and six scenarios with stars and points, from Opening Day to Lean Tower, plus free play with or without unlocks.
>
> MAKE IT YOURS
> Data-only content packs add cities, rooms and scenarios of your own.
>
> FOR EVERY PLAYER
> Four text sizes, VoiceOver labels, Reduce Motion, full keyboard control on a Mac and an iPad, and a 14-chapter manual inside the game.
>
> No ads. No in-app purchases. No account. Your game stays on your device.

(About 1,900 characters.)

### Keywords (100, comma-separated, no spaces needed)

```
tower,building,elevator,skyscraper,city,builder,tycoon,management,sim,construction,tenants,offices
```

(98 characters. Do not repeat words from the name or the subtitle, and do not use other games' names.)

### URLs

| Field | Value |
|-------|-------|
| Support URL (required) | `https://www.skyline-architect.com/support.html` (page in `Website/`; **▶ publish the site first**) |
| Marketing URL | `https://www.skyline-architect.com/` |
| Privacy Policy URL (required, under App Privacy) | `https://www.skyline-architect.com/privacy.html` (page in `Website/`) |

### Version and build

| Field | Value |
|-------|-------|
| Version | **▶ DECIDE**: the store version must match `MARKETING_VERSION` of the uploaded build (now 0.29.1). For a first public release, set 1.0.0 in Xcode before archiving. |
| Build | The uploaded build, picked after processing (10–30 minutes after upload) |
| Copyright | `2026 Rory Meijer` (**▶ DECIDE**: or your company name) |
| Routing app coverage file | None (not a navigation app) |
| Game Center | Off (the game has no Game Center) |
| Release | Manually release this version (recommended for the first one) |

### What's New (4000; not shown for the very first version)

> First release.

### App Review information

| Field | Value |
|-------|-------|
| Sign-in required | No |
| Contact | **▶ DECIDE**: first name, last name, phone number and e-mail of the person App Review may call |
| Notes (4000) | See below |
| Attachment | None needed |

Notes for App Review:

> Skyline Architect is a single-player simulation game. It needs no account, no network and no purchases.
>
> A quick way to see it: choose Tutorial in the main menu and follow the panel on the left; each step says which tool to use. New Sandbox starts with every room unlocked.
>
> On iPhone the game plays in landscape. The build palette groups its tools by category, and the four-squares button in the bottom-right controls opens every panel.
>
> Mods are optional JSON data files the player places in the app's own folder. No code is ever loaded from them.

## 5. App Privacy (General ▸ App Privacy)

| Question | Answer |
|----------|--------|
| Privacy Policy URL | as above |
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app.** |
| Resulting label | **Data Not Collected** |

Why this is true:

- Saves, settings, mods and scenario records stay on the device, in the app's own container.
- The app never opens a network connection and contains no SDKs.
- If iCloud Drive sync is turned on later, saves go to the player's own iCloud, which Apple does not count as collection by the developer. Check the label again then.

## 6. Age rating questionnaire

Answer **None** or **No** to every question. The result is **4+**.

| Question | Answer | Note |
|----------|--------|------|
| Cartoon or fantasy violence | None | |
| Realistic violence | None | Fires damage rooms; people walk out and nobody is hurt on screen |
| Prolonged graphic or sadistic realistic violence | None | |
| Profanity or crude humour | None | |
| Mature or suggestive themes | None | |
| Horror or fear themes | None | |
| Medical or treatment information | None | |
| Alcohol, tobacco or drug use or references | None | The sky bar is a room type; no drinking is shown |
| Simulated gambling | None | |
| Sexual content or nudity | None | |
| Contests | None | |
| Unrestricted web access | No | |
| User-generated content | No | Mods are local files; nothing is shared through the app |
| Messaging or chat | No | |
| Loot boxes / paid random items | No | |
| Made for Kids | No | Not in the Kids category |

## 7. Export compliance (encryption)

The game uses no encryption. The build says so itself (`ITSAppUsesNonExemptEncryption = NO`
in the Info.plist since 0.29.2), so App Store Connect no longer asks after every upload. If it
does ask: **"None of the algorithms mentioned above"** / uses no encryption.

## 8. Screenshots

Up to 10 per size; the first three matter most. The sizes App Store Connect needs:

| Device | Size (landscape, pixels) | Our captures today |
|--------|--------------------------|--------------------|
| iPhone 6.9" (required) | 2868 × 1320 (or 2796 × 1290) | ✗ CI uses a 6.1" iPhone (2556 × 1179) |
| iPad 13" (required) | 2752 × 2064 (or 2732 × 2048) | ✗ CI uses an 11" iPad (2420 × 1668) |
| Mac (required) | 2880 × 1800, 2560 × 1600, 1440 × 900 or 1280 × 800 | ✗ CI window is 1024 × 681 |

The CI captures show the right game but at the wrong sizes. The honest way to fill this in is
to run the same capture script on an iPhone 16 Pro Max and an iPad Pro 13" simulator and in a
1440 × 900 window. **▶ DECIDE**: ask for it and CI can produce real store screenshots.

Suggested order and captions:

1. The cut-away tower at lunchtime (offices, theatre, restaurant, elevators) — "Build upward"
2. The same tower in the evening, lit up — "Keep the building moving"
3. Elevator banks and waiting traffic — "Elevators that matter"
4. The leasing panel with prospects — "Tenants with opinions"
5. The tutorial — "Learn as you build"
6. The scenario browser with stars — "Scenarios against the clock"

App previews (video): optional; skip for the first release.

## 9. Before submitting — checklist

- [ ] Website published with `support.html` and `privacy.html` reachable
- [ ] Version number set in Xcode (`MARKETING_VERSION`) and the same on the version page
- [ ] Builds uploaded for iOS (iPhone and iPad) and macOS, and picked on each version page
- [ ] Screenshots for iPhone 6.9", iPad 13" and Mac
- [ ] Price and countries
- [ ] App Privacy answered ("Data Not Collected")
- [ ] Age rating questionnaire answered (4+)
- [ ] App Review contact filled in
- [ ] Copyright filled in
