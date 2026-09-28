# Phase 18 — Screenshots (iCloud persistence)

**Real screenshots of the running game**, taken by the Debug build's screenshot director.

* **Run:** CI run 36416756463 on a GitHub Actions `macos-15` runner.
* **Build:** Skyline Architect **0.18.0 (1)**, Debug.
* **Format:** 1024 × 681 pt @1×, JPEG copies.

**How the scenes were set up.** Read this before the table.

* **No real iCloud Drive.** The CI build is unsigned and has no iCloud container. Steps
  01–05 and 07 sync against a **local folder standing in for the app's iCloud container**
  (`syncFolderOverride`, Debug captures only). They go through exactly the calls the saves
  panel uses.
* **The "iPad" is simulated.** The capture script writes saves straight into that folder,
  as another device's sync would.
* **Step 06** switches the stand-in off and shows what the real iCloud lookup returns on CI:
  unavailable.
* The tower was built with the developer blueprint tool.

| File | Demonstrates |
|------|--------------|
| `01-saves-local.jpg` | *Load Game…* opens the new **saves panel**: named save, quicksave and autosave, all "on this device"; iCloud Drive is off (the default). |
| `02-sync-on.jpg` | iCloud Drive switched on: the two saves are uploaded and marked *in iCloud Drive*. The autosave stays on the device. |
| `03-from-other-device.jpg` | A save made on "the iPad" (written by the script) arrives on the next sync ("iPad Quay"). |
| `04-conflict.jpg` | Both devices changed "Quay Street" before syncing: **both versions are kept**. This device's version stays "Quay Street"; the iPad's becomes "Quay Street conflict 20260928-1140" (orange). The status line says so. |
| `05-loaded-conflict-copy.jpg` | Loading the conflict copy gives exactly the iPad's world (`identical=true`, day 1 · 15:00). |
| `06-icloud-unavailable.jpg` | The **real** iCloud lookup on this unsigned build: "iCloud Drive is not available…". The saves are untouched and marked *not synced yet*. |
| `07-delete-propagates.jpg` | Deleting "iPad Quay" here removes it from the shared folder too; it was unchanged there. |

## Inspection notes

* **The first capture of 04 showed no conflict**, and that was correct behaviour: the
  script wrote the iPad's version *after* this device had already synced its own. For this
  device that is simply a newer remote edit, so it was downloaded. The script now makes
  both edits before either sync, which is what a conflict is.
* **The conflict row's detail line** was shortened ("conflict copy"). With the long slot
  name it is still cut off; the orange icon and the title carry the meaning.
* **Not shown:** a real iCloud account and placeholder downloads. Placeholders are covered
  by the tests (`placeholdersArePending`).
