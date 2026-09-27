# Save Format

Status: **PLANNED** (Phase 2). Phase 1 has no save/load. All model types are already
`Codable` and a JSON round-trip test guards `GameWorld`.

## Planned envelope

```json
{
  "format": "skyline-architect-save",
  "formatVersion": 1,
  "gameVersion": "0.2.0",
  "createdAt": "2026-…",            // metadata only, never read by the simulation
  "contentPacks": [{ "id": "base", "version": "0.1.0" }],
  "world": { … GameWorld … }
}
```

## Rules

* Only authoritative model state is saved — never SpriteKit nodes, textures, caches or
  derived data (navigation graphs, statistics caches are rebuilt on load).
* `formatVersion` increments on any incompatible change; a chain of migration steps
  `vN → vN+1` operates on the decoded JSON tree before typed decoding.
* Loading a save with a **newer** format, unknown required content packs, or failed
  validation is refused with a clear message. Never silently corrupt or partially load.
* Writes are atomic (write temp file, then replace). Autosave rotates N slots.
* Chunking/compact encodings are deferred until profiling shows need (brief §44).
