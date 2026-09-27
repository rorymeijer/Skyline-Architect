# Save Format

Status: **FUNCTIONAL** (Phases 2–10). Implemented in `Packages/SkylineKit/Sources/SkylinePersistence`.

## Versions

| Format | Game | Change | Migration |
|--------|------|--------|-----------|
| 1 | 0.2–0.3 | Initial: world with cities, properties, buildings, rooms | — |
| 2 | 0.4–0.5 | World gains `clock` (`{ "tick": N }`) and `people` | v1→v2 adds `clock: {tick: 0}` and `people: []` |
| 7 | 0.10 | World gains `upkeep` (per room: condition, cleanliness) and `facilities` (jobs, counters); people may be `janitor` / `technician` with a `job`; ledger category `wages` and decline reason `poorServices` (count arrays grow by one) | v6→v7 adds empty `upkeep` (created as new on the next step) and `facilities`, pads daily totals and decline counts |
| 6 | 0.9 | World gains `ledger` (cash, loans, journal, daily totals, negativeDays, bankrupt); buildings gain `rentLevel` | v5→v6 adds an empty ledger (older games have no money history) and `rentLevel: 1` |
| 5 | 0.8 | World gains `tenants` and `market` (next step, counters, declines per reason, log); people gain optional `tenantID` | v4→v5 adds `tenants: []` and a market whose next step is the next full hour; on load the population sync adopts existing people into one tenant per room |
| 4 | 0.7 | Cars gain `strategy` (`collective` / `zoning` / `destination`) and `stats` (boardings, totalWait, maxWait, abandoned, stops, day, hourly[24]); rides may carry `assigned` | v3→v4 adds `strategy: "collective"` and zeroed `stats` to every car |
| 3 | 0.6 | World gains `elevators` (cars: floor, direction, motion, passengers, nextEventTick); people gain optional `pendingRide`; `place` may be `waiting` / `riding` | v2→v3 adds `elevators: []` (cars are created for existing shafts on the next simulation step) |

Golden fixtures: `save-v1` … `save-v6` (frozen) and `save-v7.skylinesave` (upkeep).

## Envelope (format version 7)

```json
{
  "format": "skyline-architect-save",
  "formatVersion": 7,
  "game": {
    "metadata": { "title": "Quay Street Lot", "savedAt": "2026-09-27T10:00:00Z", "gameVersion": "0.2.0" },
    "contentPacks": [{ "id": "base", "version": "0.1.0" }],
    "activePropertyID": 2,
    "world": {
      "grid": { … },
      "ids": { "next": 57 },
      "cities": [ … ], "properties": [ … ],
      "buildings": [ { "id": 3, "footprint": …, "foundation": …, "floors": [ { "level": 0, "span": … } ] } ],
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

## Adding a format version

1. Bump `SaveCodec.currentVersion`.
2. Register `migrations[old] = { game in … }` that rewrites the JSON tree.
3. Keep the old golden fixture (`Tests/SkylinePersistenceTests/Fixtures/save-vN.skylinesave`)
   and add a new one; the tests load every fixture forever.
4. Document the change here.

Chunking / compact encodings stay deferred until profiling shows the need (brief §44).
