"""Writes workflow/info.plist for the Firefox Tabs Alfred workflow."""
import os
import plistlib

SF, RUN, COPY = "A1F0F1AB-0001-4000-8000-000000000001", "A1F0F1AB-0002-4000-8000-000000000002", "A1F0F1AB-0003-4000-8000-000000000003"
CMD = 1048576

info = {
    "bundleid": "com.chesterleung.firefox-tabs",
    "name": "Firefox Tabs",
    "description": "Search open Firefox tabs and bookmarks with one keyword",
    "createdby": "Chester Leung",
    "category": "Internet",
    "readme": "`ff` searches open tabs and bookmarks (★). ↩ switches to the tab or opens the bookmark; ⌘↩ copies the URL. Filter by title, URL, host, port or folder; add `tab` or `bookmark` to narrow. Change the keyword via the `keyword` workflow variable.\n\nhttps://github.com/chester-leung/alfred-firefox-tabs",
    "webaddress": "https://github.com/chester-leung/alfred-firefox-tabs",
    "disabled": False,
    "version": os.environ.get("VERSION", "dev"),
    "objects": [
        {"uid": SF, "type": "alfred.workflow.input.scriptfilter", "version": 3, "config": {
            "keyword": "{var:keyword}", "withspace": True, "argumenttype": 1, "argumenttrimmode": 0,
            "argumenttreatemptyqueryasnil": True,
            "title": "Search Firefox tabs and bookmarks", "subtext": "", "runningsubtext": "Reading Firefox…",
            "type": 0, "script": "./fftabs search", "scriptfile": "", "scriptargtype": 1, "escaping": 102,
            "alfredfiltersresults": True, "alfredfiltersresultsmatchmode": 0,
            "queuemode": 1, "queuedelaymode": 0, "queuedelaycustom": 3, "queuedelayimmediatelyinitially": True,
        }},
        {"uid": RUN, "type": "alfred.workflow.action.script", "version": 2, "config": {
            "type": 0, "scriptargtype": 1, "escaping": 102, "concurrently": False, "scriptfile": "",
            # Tabs pass a JSON locator, bookmarks a URL.
            "script": 'case "$1" in\n  x-apple*) open "$1" ;;\n  "{"*) ./fftabs focus "$1" ;;\n  *) open -b org.mozilla.firefox "$1" ;;\nesac',
        }},
        {"uid": COPY, "type": "alfred.workflow.output.clipboard", "version": 3, "config": {
            "clipboardtext": "{query}", "autopaste": False, "ignoredynamicplaceholders": False, "transient": False,
        }},
    ],
    "connections": {
        SF: [
            {"destinationuid": RUN, "modifiers": 0, "modifiersubtext": "", "vitoclose": False},
            {"destinationuid": COPY, "modifiers": CMD, "modifiersubtext": "", "vitoclose": False},
        ],
    },
    "uidata": {SF: {"xpos": 50, "ypos": 50}, RUN: {"xpos": 300, "ypos": 20}, COPY: {"xpos": 300, "ypos": 150}},
    "variables": {"keyword": "ff"},
    "variablesdontexport": [],
}
with open("workflow/info.plist", "wb") as f:
    plistlib.dump(info, f)
