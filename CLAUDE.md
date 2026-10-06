# Firefox Tabs for Alfred

Alfred workflow: the `ff` keyword lists open Firefox tabs (↩ switches to the
tab) and bookmarks (↩ opens them). See README.md for user-facing behaviour.

## Layout

- `fftabs.swift`: the whole program. `fftabs search` prints Alfred Script
  Filter JSON (tabs, then bookmarks); `fftabs focus <json>` switches to a tab;
  `fftabs urls` dumps session-file URLs for debugging.
- `make_workflow.py`: generates `workflow/info.plist`. Edit this, never the
  plist. Everything in `workflow/` is a build output and gitignored.
- `build.sh`: compiles a universal binary into `workflow/`, writes the plist,
  zips `dist/Firefox-Tabs.alfredworkflow`. `./build.sh install` also copies
  the workflow into the local Alfred preferences for testing.

## How it works (and the traps)

- **Tabs come from the Accessibility tree** (`AXTabGroup` → `AXRadioButton`
  with subrole `AXTabButton`), so it works for horizontal and vertical tabs and
  every running profile. Tab switching is an `AXPress` on that element.
- **Terminals usually lack Accessibility permission**, so `fftabs search` from
  a shell shows the permission item plus bookmarks only. To test tabs, run the
  binary via Alfred (which has the permission): temporarily add an
  `alfred.workflow.trigger.external` object to the installed info.plist that
  runs `./fftabs search > some-file`, fire it with
  `osascript -e 'tell application id "com.runningwithcrayons.Alfred" to run trigger "<id>" in workflow "com.chesterleung.firefox-tabs"'`,
  then reinstall with `./build.sh install` to remove it. Alfred takes a few
  seconds to notice plist changes.
- **Fullscreen video hides the tab strip** from the Accessibility tree; an
  empty tab list may just mean a window is fullscreen.
- **URLs come from `sessionstore-backups/recovery.jsonlz4`** (mozLz4, decoded
  in-process), matched to live tabs by window and position. Firefox rewrites it
  every ~15s, so new tabs briefly have no URL.
- **Bookmarks come from `places.sqlite`**, which Firefox locks exclusively.
  Query a copy (APFS clone) of it plus its `-wal` file; never open the live DB.
- Tab titles change after listing (pages finish loading), so `focus` falls back
  from position+title to title to position.

## Conventions

- **Don't commit or package the Firefox logo** (Mozilla trademark).
  `workflow/icon.png` is generated from the local Firefox.app for local
  installs only and is gitignored.
- The `ff` keyword is the `keyword` workflow variable, not hard-coded.
- Keep changes in `fftabs.swift` dependency-free (Cocoa + SQLite3 only).

## Releasing

Releases are built by CI (`.github/workflows/build.yml`), not locally:

1. Merge to `main` (CI builds every push/PR as a check).
2. `git tag vX.Y.Z && git push origin vX.Y.Z`
3. CI builds on macOS with `VERSION=X.Y.Z` and publishes
   `Firefox-Tabs.alfredworkflow` as the tag's GitHub release (notes are
   auto-generated; edit them on GitHub if needed).

Bump the major version when the keyword or other user-facing behaviour changes
incompatibly.
