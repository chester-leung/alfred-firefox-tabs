# Firefox Tabs for Alfred

Type `t` in Alfred to see every open Firefox tab (all windows, all running
profiles, horizontal or vertical tabs). Type to filter by title, URL, host or
port (e.g. `t 3000`). ↩ switches to the tab and brings Firefox forward;
⌘↩ copies the tab's URL.

## How it works

`fftabs` (Swift) reads the live tab list from Firefox's Accessibility tree and
selects tabs by pressing them there, so no Firefox extension is needed. URLs
come from each profile's `sessionstore-backups/recovery.jsonlz4`, which Firefox
rewrites every ~15s, so a brand-new tab may briefly show no URL.

Requires Alfred to have Accessibility permission. Tabs aren't visible while a
window is in fullscreen video mode, because Firefox hides its tab strip then.

## Build / install

    ./build.sh

Compiles a universal binary, regenerates `info.plist` from
`make_workflow.py`, and copies the workflow into Alfred's synced preferences.
