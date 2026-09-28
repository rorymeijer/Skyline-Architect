# Save Format

Status: **FUNCTIONAL** (Phases 2–18; format 14 after Phase 20). Implemented in `Packages/SkylineKit/Sources/SkylinePersistence`.

## Versions

| Format | Game | Change | Migration |
|--------|------|--------|-----------|
| 1 | 0.2–0.3 | Initial: world with cities, properties, buildings, rooms | — |
| 2 | 0.4–0.5 | World gains `clock` (`{ "tick": N }`) and `people` | v1→v2 adds `clock: {tick: 0}` and `people: []` |
| 15 | 0.20.3 | Rooms may carry `tenure` (`rent` / `forSale` / `owned`); tenants may carry `purchasePrice`; ledger category `sales` (daily totals grow by one) | v14→v15 pads daily totals to 11; older games rent every unit |
| 14 | 0.20.1 | Cities may carry `weather` (each city its own); the world no longer does. Pack references may carry `hash` (FNV-1a of the pack's files) | v13→v14 moves the world's `weather` to the first city (whose seed drew it); other cities start their own on the next step. Older references have no hash: only versions are compared |
| 13 | 0.16 | World may carry `scenario` (`id`, `name`, `objectives [{metric, target}]`, `deadlineDay`, `holdDays`, `streak`, `measured`, `result {won, tick, reason}`) | v12→v13: nothing to add — older games are free play |
| 12 | 0.15 | Cities gain `economy` (`rent`, `construction`, `demand`); properties may carry `plotID`; ledger category `land` (daily totals grow by one) | v11→v12 adds a default economy and pads daily totals; on load `Estate.adoptLegacy` matches properties to plots and applies the content market |
| 11 | 0.14 | World gains `incidents` (`log` of incidents, `fires` in progress with burning rooms and intensities, `nextID`) | v10→v11 adds an empty incident state |
| 10 | 0.13 | World may carry `weather` (`day`, `yesterday`, `today`, `tomorrow`, `temperature`) | v9→v10: nothing to add — the simulation starts the weather on the current day at its next step |
| 9 | 0.12 | Buildings gain `lightingKWh` (lighting energy since the last closing) | v8→v9 adds `lightingKWh: 0` |
| 8 | 0.11 | Buildings gain `standing` (`classLevel`, `reputation`, `promotions`); world gains `unlocks` (`all` / `byClass`) | v7→v8 adds `standing: {classLevel: 0, reputation: 50, promotions: []}` and `unlocks: "all"` (older games stay sandbox-like) |
| 7 | 0.10 | World gains `upkeep` (per room: condition, cleanliness) and `facilities` (jobs, counters); people may be `janitor` / `technician` with a `job`; ledger category `wages` and decline reason `poorServices` (count arrays grow by one) | v6→v7 adds empty `upkeep` (created as new on the next step) and `facilities`, pads daily totals and decline counts |
| 6 | 0.9 | World gains `ledger` (cash, loans, journal, daily totals, negativeDays, bankrupt); buildings gain `rentLevel` | v5→v6 adds an empty ledger (older games have no money history) and `rentLevel: 1` |
| 5 | 0.8 | World gains `tenants` and `market` (next step, counters, declines per reason, log); people gain optional `tenantID` | v4→v5 adds `tenants: []` and a market whose next step is the next full hour; on load the population sync adopts existing people into one tenant per room |
| 4 | 0.7 | Cars gain `strategy` (`collective` / `zoning` / `destination`) and `stats` (boardings, totalWait, maxWait, abandoned, stops, day, hourly[24]); rides may carry `assigned` | v3→v4 adds `strategy: "collective"` and zeroed `stats` to every car |
| 3 | 0.6 | World gains `elevators` (cars: floor, direction, motion, passengers, nextEventTick); people gain optional `pendingRide`; `place` may be `waiting` / `riding` | v2→v3 adds `elevators: []` (cars are created for existing shafts on the next simulation step) |

Golden fixtures: `save-v1` … `save-v14` (frozen) and `save-v15.skylinesave` (a sold studio with its owner, a studio for sale).

## Envelope (format version 15)

```json
{
  "format": "skyline-architect-save",
  "formatVersion": 15,
  "game": {
    "metadata": { "title": "Quay Street Lot", "savedAt": "2026-09-27T10:00:00Z", "gameVersion": "0.2.0" },
    "contentPacks": [{ "id": "base", "version": "0.1.0", "hash": "9c2e41f0a7d3b518" }],
    "activePropertyID": 2,
    "world": {
      "grid": { … },
      "ids": { "next": 57 },
      "cities": [ { "id": 1, "definitionID": "port-calder", "name": "Port Calder", "seed": 7301, "economy": { … },
                    "weather": { "day": 3, "yesterday": "rain", "today": "storm", "tomorrow": "overcast", "temperature": 17 } } ],
      "properties": [ … ],
      "buildings": [ { "id": 3, "footprint": …, "foundation": …, "floors": [ { "level": 0, "span": … } ],
                       "rentLevel": 1, "standing": { "classLevel": 1, "reputation": 61.25, "promotions": [259200] },
                       "lightingKWh": 12.5 } ],
      "unlocks": "byClass",
      "scenario": { "id": "opening-day", "name": "Opening Day", "deadlineDay": 10, "holdDays": 1, "streak": 0,
                    "objectives": [ { "metric": "occupiedUnits", "target": 12 } ], "measured": [ 9 ], "result": null },
      "rooms": [ { "id": 4, "buildingID": 3, "definitionID": "office-small", "columns": …, "floors": … } ],
      "clock": { "tick": 8400 },
      "people": [ { "id": 41, "name": "…", "role": "worker", "scheduleID": "office-worker",
                    "place": { "travelling": { "legs": [ … ], "destination": … } },
                    "nextEventTick": 8455, "nextGoal": null, "traits": 123456, "pendingRide": null, … } ],
      "elevators": [ { "id": 9, "buildingID": 3, "floor": 0, "direction": 1,
                       "motion": { "moving": { "fromFloor": 0, "toFloor": 8, "start": 8440, "end": 8458,
                                               "speed": 2.5, "acceleration": 1 } },
                       "passengers": [41, 44], "nextEventTick": 8458, "strategy": "collective",
                       "stats": { "boardings": 12, "totalWait": 240, "maxWait": 41, "abandoned": 0,
                                  "stops": 17, "day": 0, "hourly": [0, 0, …] } } ]
    }
  }
}
```

JSON with sorted keys and ISO-8601 dates: encoding the same game twice gives identical
bytes. Files use the extension `.skylinesave`.

## Rules (all enforced by `SaveCodec.decode`)

* Only authoritative model state is saved — never SpriteKit nodes, textures, tile caches,
  compositions or other derived data; these are rebuilt on load.
* `format` must match, otherwise **not a save**.
* `formatVersion` newer than the running build → refused with a clear message.
* Older versions are upgraded step by step (`migrations[v]` upgrades v → v+1) on the
  untyped JSON tree before typed decoding. A missing step → refused.
* Every content pack listed must be installed → otherwise refused.
* A pack installed with another version, or the same version with a different `hash`, is
  loaded anyway; `SaveCodec.changedPacks` names it and the app tells the player that the
  content may no longer match the world.
* The decoded world must pass `GameWorld.validateIntegrity()` (references, floor order,
  rooms on built floors, no overlaps, cars on their shafts, riders ⇔ car passengers, ID
  allocator ahead of all IDs) → otherwise refused.
  **An inconsistent save is never partially loaded.**

## Storage (`SaveStore`)

* Directory: `~/Library/Application Support/Skyline Architect/Saves/` (macOS; iPadOS app
  container equivalent). Screenshot captures use a private directory inside the capture folder.
* Writes are atomic (`Data.write(options: .atomic)`): a crash mid-write keeps the old file.
* Slots: `quicksave` (⌘S), named slots, and rotating `autosave-1…3` (every 2 minutes when
  there are unsaved changes). Slot names are restricted to letters, digits, space, `-`, `_`.

## Sync with iCloud Drive (Phase 18)

Status: the sync logic is **FUNCTIONAL** and tested. The iCloud Drive connection is
**implemented but unverified**: it needs a signed build with an iCloud container (see
*Setup* below), which CI does not have.

**Where the code lives.**

* `SaveSync` (SkylinePersistence) syncs this device's save folder with a shared folder in
  both directions. It is plain file logic, tested on Linux with two simulated devices.
* The app uses the app's iCloud Drive container (`Documents/Saves`) as the shared folder.
* Sync is **off by default**. The switch is in the saves panel (File ▸ Load Game… / main
  menu).
* Sync runs:
  * on launch;
  * after every save;
  * when the saves panel opens;
  * on *Sync Now*.

**Rules.** Each device keeps `.skyline-sync.json`, the fingerprint (FNV-1a 64 of the file
bytes) of every slot at its last sync.

| This device | Shared folder | Result |
|-------------|---------------|--------|
| changed | unchanged | upload |
| unchanged | changed | download |
| changed | changed (or both new with different contents) | **conflict**: the shared version is kept as "‹slot› conflict ‹yyyyMMdd-HHmm›" on both sides and this device's version is uploaded. Nothing is lost or silently overwritten. |
| deleted | unchanged since the last sync | deleted in the shared folder too |
| deleted | changed since | restored here (the change wins over the deletion) |
| — | iCloud placeholder (`.slot.skylinesave.icloud`) | pending: a download is requested; nothing is deleted or overwritten |

Autosaves are per device and never synced. Saves still need the content packs they list
(MODDING.md).

**Setup for a real iCloud build** (requires an Apple Developer team, so it is not in the
repository's project):

1. Add the iCloud capability to the app target, with *iCloud Documents* and a container
   such as `iCloud.<team-prefix>.SkylineArchitect`.
2. Sign with that team.

Without this, `url(forUbiquityContainerIdentifier:)` returns nil and the panel says iCloud
Drive is unavailable. That is what the CI build shows.

**Limits.**

* The app writes files without `NSFileCoordinator`.
* It does not use `NSMetadataQuery` to see changes live: it syncs at the moments listed
  above.

## Adding a format version

1. Bump `SaveCodec.currentVersion`.
2. Register `migrations[old] = { game in … }` that rewrites the JSON tree.
3. Keep the old golden fixture (`Tests/SkylinePersistenceTests/Fixtures/save-vN.skylinesave`)
   and add a new one; the tests load every fixture forever.
4. Document the change here.

Chunking / compact encodings stay deferred until profiling shows the need (brief §44).
