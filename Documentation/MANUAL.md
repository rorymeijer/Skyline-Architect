# Manual, tutorial and tips (F3)

## One source for the game and the website

The player's manual is a set of Markdown files in
`Packages/SkylineKit/Sources/SkylineContent/Resources/Manual/`:

- `NN-id.md`: one chapter per file. The `NN-` prefix sets the order; the rest is the chapter
  id (`03-transport.md` → `transport`). The first `#` heading is the title.
- `hints.json`: the first-time tips (`id`, `title`, `text`, optional `chapter`).

The game shows the chapters in *Help ▸ Skyline Architect Manual* (`⌘?`), the main menu and
the book button in the view controls. The website's `Website/manual/` pages are generated
from the same files by `skyline-website` (see `Website/README.md`).

The manual is separate from the base content pack, so mods do not change it.

### Supported Markdown

| Block | Syntax |
|-------|--------|
| Heading | `#` (title), `##`, `###` |
| Paragraph | lines of text; a blank line ends it |
| Bullets | `- item` (an indented next line continues the item) |
| Numbered list | `1. item` |
| Note | `> text` (shown as a tip box) |
| Table | `| a | b |` rows; the `|---|` rule is skipped |

Inline: `**bold**`, `*italic*`, `` `key` `` (shown as a key), `[text](chapter.md)` links to
another chapter, `[text](https://…)` links out.

### Checks (`ManualTests`)

- every chapter has a title;
- chapter links, hint chapters and tutorial step chapters point at chapters that exist;
- the hint ids are exactly the ones the app triggers;
- `Website/manual/` equals what `skyline-website` would write.

## Tutorial steps

A scenario may have `tutorial` steps (`scenarios.json`, `TutorialStep`):

```json
{ "id": "plant", "title": "Install the plant", "text": "…", "chapter": "facilities",
  "done": [ { "kind": "rooms", "count": 1, "rooms": ["mechanical"] } ] }
```

| Condition `kind` | Met when |
|------------------|----------|
| `rooms` | at least `count` rooms of one of the `rooms` ids |
| `floors` | at least `count` built floor levels |
| `tenants` | at least `count` tenants |
| `population` | at least `count` residents and workers |
| `staff` | at least `count` janitors and technicians |
| `scenarioDay` | the scenario reached day `count` |

Steps are guidance, not rules: they are read from content and measured on the live world;
the current step is the first one whose conditions do not all hold. They are not saved (no
save format change). A scenario with steps starts paused and shows the tutorial panel.

*First Tower (Tutorial)* is played step by step in `TutorialTests`, through the construction
engine, until it is won.

## First-time tips

The app raises a tip at its moment (a tool picked, the first tenant, the first closing,
a decline for poor services, a fire…). Each shows once per device, remembered in the user
defaults. Tips can be turned off in the tip itself or in the Help menu; *Show All Tips
Again* forgets which were seen. Screenshot captures never read or write these settings.
