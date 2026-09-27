# Modding

Status: **SCAFFOLDED** — content already loads from a declarative JSON pack; pack
merging and user mod folders are PLANNED for Phase 17.

## Rules

* Mods are **data only** (JSON, and later images/sprite sheets). No scripts, no native
  code, no dynamic libraries. Ever.
* Every definition has a stable string `id` (`namespace.name` recommended for mods,
  e.g. `acme.rooftop-bar`).
* Validation errors name the pack, file and id; invalid packs are rejected, never
  partially applied.

## Pack layout (current base pack)

```
Base/
  pack.json      { "id": "base", "name": "…", "version": "0.1.0", "formatVersion": 1,
                   "files": { "cities": "cities.json", "plots": "plots.json", "starts": "starts.json" } }
  cities.json    [CityDefinition]
  plots.json     [PlotDefinition]
  starts.json    [StartDefinition]
```

### CityDefinition
`id, name, description, seed, geology: [{ material, thickness }]` — `material` ∈
`paving, topsoil, clay, sand, gravel, bedrock`; the last stratum is bedrock (infinite).

### PlotDefinition
`id, name, cityID, frontageModules, maxBasementFloors, siteMarginModules`

### StartDefinition
`id, name, mode ("sandbox"), cityID, plotID, propertyName, startingFoundation?
{ buildingName, footprintOffsetModules, footprintModules, basementFloors,
pileDepthMeters, pileSpacingModules }`

## Planned (Phase 17)

Load order (base → mods by dependency), override-by-id with explicit `"override": true`,
additive lists, content hashes stored in saves so a save knows which packs it needs.
