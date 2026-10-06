"""Writes workflow/info.plist for the Firefox Tabs Alfred workflow."""
import plistlib

SF, RUN, COPY = "A1F0F1AB-0001-4000-8000-000000000001", "A1F0F1AB-0002-4000-8000-000000000002", "A1F0F1AB-0003-4000-8000-000000000003"
CMD = 1048576

info = {
    "bundleid": "com.chesterleung.firefox-tabs",
    "name": "Firefox Tabs",
    "description": "Search open Firefox tabs and switch to one",
    "createdby": "Chester Leung",
    "category": "Internet",
    "readme": "Type `t` then part of a tab title or URL (e.g. `t 3000`). ↩ switches to the tab, ⌘↩ copies its URL.\n\nSource: ~/repos/alfred-firefox-tabs",
    "webaddress": "",
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
    "variablesdontexport": [],
}
with open("workflow/info.plist", "wb") as f:
    plistlib.dump(info, f)
