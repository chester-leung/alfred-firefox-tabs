# Firefox Tabs for Alfred

Search your open Firefox tabs and bookmarks from Alfred with one keyword.

Type **`ff`** and everything is listed: open tabs first, then bookmarks (marked
★). Keep typing to filter by title, URL, host, port or bookmark folder
(`ff gmail`, `ff localhost:3000`, `ff 3000`, `ff toolbar`). Add `tab` or
`bookmark` to the query to narrow to one kind (`ff jira bookmark`). Bookmarks
already open in a tab are skipped, since picking the tab gets you there.

| Key | Action |
| --- | --- |
| ↩ | Tab: switch to it and bring Firefox to the front · Bookmark: open it in Firefox |
| ⌘↩ | Copy the URL |
| ⇧ / ⌘Y | Quick Look the page |

Works with horizontal and vertical tabs, multiple windows, and multiple Firefox
profiles (bookmarks from every profile are included, labelled by profile). No
Firefox extension needed.

## Requirements

- macOS 12 or later (Apple Silicon or Intel)
- [Alfred](https://www.alfredapp.com) 4 or 5 with the Powerpack (needed for workflows)
- Firefox (release, Developer Edition or Nightly)

## Install

### Option A: download the release

1. Download `Firefox-Tabs.alfredworkflow` from the
   [latest release](https://github.com/chester-leung/alfred-firefox-tabs/releases/latest).
2. Double-click it, and Alfred imports the workflow.
3. Downloaded files are quarantined by macOS, and the helper binary isn't
   notarized, so clear the quarantine flag once. In Alfred Preferences →
   Workflows, right-click **Firefox Tabs** → *Open in Finder*, then in Terminal run:

   ```sh
   xattr -dr com.apple.quarantine "<that folder>"
   ```

   (Or build from source, Option B, which avoids this step.)

### Option B: build from source

Needs the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/chester-leung/alfred-firefox-tabs.git
cd alfred-firefox-tabs
./build.sh install
```

`./build.sh` alone just produces `dist/Firefox-Tabs.alfredworkflow`, which you can
double-click to import. Releases are built by GitHub Actions when a `v*` tag
is pushed (see `CLAUDE.md`).

### Grant Accessibility permission

Needed for tabs (bookmarks are listed without it). The workflow reads and clicks Firefox's tabs through the macOS Accessibility
API, so Alfred needs that permission: **System Settings → Privacy & Security →
Accessibility → enable Alfred**. If it's missing, `ff` shows an item that opens
that settings pane for you.

### Changing the keyword

Open the workflow in Alfred Preferences, click the **[𝑥]** (variables) button,
and edit `keyword` (default `ff`).

## How it works

`fftabs` is a small Swift program the workflow calls:

- **Listing:** it walks each Firefox window's Accessibility tree for tab
  buttons (`AXRadioButton` / `AXTabButton`). This is live and fast (~0.15s) and
  sees every running Firefox instance, so all profiles are covered.
- **URLs:** Firefox doesn't expose URLs through Accessibility, so they're read
  from each profile's session file
  (`~/Library/Application Support/Firefox/Profiles/*/sessionstore-backups/recovery.jsonlz4`,
  Mozilla's LZ4 variant, decoded in-process) and matched to the live tabs by
  window and position.
- **Switching:** it presses the tab's button, raises its window and activates
  Firefox.
- **Bookmarks:** read from each profile's `places.sqlite`, most-used first, with
  their folder path. Firefox keeps that database locked while running, so
  `fftabs` queries a copy-on-write clone of it (and its WAL, so bookmarks added
  seconds ago show up), then deletes the clone.

Nothing leaves your machine: no network access, no extension, nothing kept on disk.

## Limitations

- Firefox rewrites the session file every ~15 seconds, so a brand-new tab can
  briefly show no URL. You can still switch to it; it just can't be searched by
  URL until the next save.
- While a window is in fullscreen video, Firefox hides its tab strip, so that
  window's tabs don't appear.
- With several profiles running, a bookmark opens in whichever Firefox instance
  macOS routes the URL to, not necessarily the profile it came from.

## License

MIT
