"""Writes workflow/info.plist for the Firefox Tabs Alfred workflow."""
import plistlib

SF, RUN, COPY = "A1F0F1AB-0001-4000-8000-000000000001", "A1F0F1AB-0002-4000-8000-000000000002", "A1F0F1AB-0003-4000-8000-000000000003"
BSF, BOPEN = "A1F0F1AB-0004-4000-8000-000000000004", "A1F0F1AB-0005-4000-8000-000000000005"
CMD = 1048576

info = {
    "bundleid": "com.chesterleung.firefox-tabs",
    "name": "Firefox Tabs",
    "description": "Search open Firefox tabs and bookmarks",
    "createdby": "Chester Leung",
    "category": "Internet",
    "readme": "`t` searches open tabs (↩ switches to the tab). `b` searches bookmarks (↩ opens it in Firefox). Filter by title, URL, host or port; ⌘↩ copies the URL.\n\nhttps://github.com/chester-leung/alfred-firefox-tabs",
    "webaddress": "https://github.com/chester-leung/alfred-firefox-tabs",
    "disabled": False,
    "version": "1.0",
    "objects": [
        {"uid": SF, "type": "alfred.workflow.input.scriptfilter", "version": 3, "config": {
            "keyword": "t", "withspace": True, "argumenttype": 1, "argumenttrimmode": 0,
            "argumenttreatemptyqueryasnil": True,
            "title": "Search Firefox tabs", "subtext": "", "runningsubtext": "Reading tabs…",
            "type": 0, "script": "./fftabs list", "scriptfile": "", "scriptargtype": 1, "escaping": 102,
            "alfredfiltersresults": True, "alfredfiltersresultsmatchmode": 0,
            "queuemode": 1, "queuedelaymode": 0, "queuedelaycustom": 3, "queuedelayimmediatelyinitially": True,
        }},
        {"uid": RUN, "type": "alfred.workflow.action.script", "version": 2, "config": {
            "type": 0, "scriptargtype": 1, "escaping": 102, "concurrently": False, "scriptfile": "",
            "script": 'case "$1" in\n  x-apple*) open "$1" ;;\n  *) ./fftabs focus "$1" ;;\nesac',
        }},
        {"uid": BSF, "type": "alfred.workflow.input.scriptfilter", "version": 3, "config": {
            "keyword": "b", "withspace": True, "argumenttype": 1, "argumenttrimmode": 0,
            "argumenttreatemptyqueryasnil": True,
            "title": "Search Firefox bookmarks", "subtext": "", "runningsubtext": "Reading bookmarks…",
            "type": 0, "script": "./fftabs bookmarks", "scriptfile": "", "scriptargtype": 1, "escaping": 102,
            "alfredfiltersresults": True, "alfredfiltersresultsmatchmode": 0,
            "queuemode": 1, "queuedelaymode": 0, "queuedelaycustom": 3, "queuedelayimmediatelyinitially": True,
        }},
        {"uid": BOPEN, "type": "alfred.workflow.action.script", "version": 2, "config": {
            "type": 0, "scriptargtype": 1, "escaping": 102, "concurrently": False, "scriptfile": "",
            "script": 'open -b org.mozilla.firefox "$1"',
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
        BSF: [
            {"destinationuid": BOPEN, "modifiers": 0, "modifiersubtext": "", "vitoclose": False},
            {"destinationuid": COPY, "modifiers": CMD, "modifiersubtext": "", "vitoclose": False},
        ],
    },
    "uidata": {SF: {"xpos": 50, "ypos": 50}, RUN: {"xpos": 300, "ypos": 20}, COPY: {"xpos": 300, "ypos": 150},
               BSF: {"xpos": 50, "ypos": 250}, BOPEN: {"xpos": 300, "ypos": 280}},
    "variablesdontexport": [],
}
with open("workflow/info.plist", "wb") as f:
    plistlib.dump(info, f)
