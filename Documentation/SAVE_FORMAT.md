# Save Format

Status: **FUNCTIONAL** (Phase 2). Implemented in `Packages/SkylineKit/Sources/SkylinePersistence`.

## Envelope (format version 1)

```json
{
  "format": "skyline-architect-save",
  "formatVersion": 1,
  "game": {
    "metadata": { "title": "Quay Street Lot", "savedAt": "2026-09-27T10:00:00Z", "gameVersion": "0.2.0" },
    "contentPacks": [{ "id": "base", "version": "0.1.0" }],
    "activePropertyID": 2,
    "world": {
      "grid": { … },
      "ids": { "next": 57 },
      "cities": [ … ], "properties": [ … ],
      "buildings": [ { "id": 3, "footprint": …, "foundation": …, "floors": [ { "level": 0, "span": … } ] } ],
      "rooms": [ { "id": 4, "buildingID": 3, "definitionID": "office-small", "columns": …, "floors": … } ]
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
  rooms on built floors, no overlaps, ID allocator ahead of all IDs) → otherwise refused.
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
