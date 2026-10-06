// fftabs — list and switch Firefox tabs for Alfred.
//
//   fftabs list            Alfred Script Filter JSON of every open tab
//   fftabs focus <arg>     bring the tab identified by <arg> to the front
//   fftabs bookmarks       Alfred Script Filter JSON of every bookmark
//
// Tabs are read live via the Accessibility API (covers every running Firefox
// profile). URLs come from each profile's session file, matched by window and
// position. Bookmarks come from each profile's places.sqlite.

import Cocoa
import SQLite3

let firefoxBundleIDs: Set<String> = [
    "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly",
]

// MARK: - Accessibility helpers

func attr<T>(_ e: AXUIElement, _ name: String) -> T? {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success else { return nil }
    return v as? T
}

func children(_ e: AXUIElement) -> [AXUIElement] { attr(e, "AXChildren") ?? [] }

struct Tab {
    let pid: pid_t
    let window: Int
    let index: Int
    let title: String
    let windowTitle: String
    let selected: Bool
    let element: AXUIElement
    let windowElement: AXUIElement
}

/// Finds tab buttons in a window. Tabs are AXRadioButtons inside an AXTabGroup;
/// web content (AXWebArea) is skipped so the walk stays fast.
func tabElements(in window: AXUIElement) -> [AXUIElement] {
    var found: [AXUIElement] = []
    func walk(_ e: AXUIElement, _ depth: Int, _ inTabGroup: Bool) {
        guard depth < 30 else { return }
        let role: String = attr(e, "AXRole") ?? ""
        if role == "AXWebArea" { return }
        if inTabGroup && role == "AXRadioButton" && attr(e, "AXSubrole") == "AXTabButton" {
            found.append(e); return
        }
        for c in children(e) { walk(c, depth + 1, inTabGroup || role == "AXTabGroup") }
    }
    walk(window, 0, false)
    return found
}

func allTabs() -> [Tab] {
    var tabs: [Tab] = []
    for app in NSWorkspace.shared.runningApplications
    where firefoxBundleIDs.contains(app.bundleIdentifier ?? "") {
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
        let windows: [AXUIElement] = attr(axApp, "AXWindows") ?? []
        for (wi, w) in windows.enumerated() {
            let wTitle: String = attr(w, "AXTitle") ?? ""
            for (ti, t) in tabElements(in: w).enumerated() {
                let title: String = attr(t, "AXTitle") ?? attr(t, "AXDescription") ?? ""
                let selected = (attr(t, "AXValue") as NSNumber?)?.boolValue ?? false
                tabs.append(Tab(pid: pid, window: wi, index: ti, title: title, windowTitle: wTitle,
                                selected: selected, element: t, windowElement: w))
            }
        }
    }
    return tabs
}

// MARK: - Session store (URLs)

/// Decodes Mozilla's "mozLz40\0" + u32 size + LZ4 block format.
func mozLz4Decode(_ data: Data) -> Data? {
    let src = [UInt8](data)
    guard src.count > 12, String(bytes: src[0..<8], encoding: .ascii) == "mozLz40\0" else { return nil }
    let size = Int(src[8]) | Int(src[9]) << 8 | Int(src[10]) << 16 | Int(src[11]) << 24
    var out = [UInt8](); out.reserveCapacity(size)
    var i = 12
    while i < src.count {
        let token = Int(src[i]); i += 1
        var litLen = token >> 4
        if litLen == 15 { while i < src.count { let b = Int(src[i]); i += 1; litLen += b; if b != 255 { break } } }
        guard i + litLen <= src.count else { return nil }
        out.append(contentsOf: src[i..<i + litLen]); i += litLen
        if i >= src.count { break }
        guard i + 1 < src.count else { return nil }
        let offset = Int(src[i]) | Int(src[i + 1]) << 8; i += 2
        var matchLen = token & 15
        if matchLen == 15 { while i < src.count { let b = Int(src[i]); i += 1; matchLen += b; if b != 255 { break } } }
        matchLen += 4
        guard offset > 0, offset <= out.count else { return nil }
        let start = out.count - offset
        for k in 0..<matchLen { out.append(out[start + k]) }
    }
    return Data(out)
}

struct SessionTab { let title: String; let url: String }

/// Every window in every profile's live session file, as ordered tab lists.
/// Firefox rewrites this file every ~15s, so titles can lag slightly.
func sessionWindows() -> [[SessionTab]] {
    var result: [[SessionTab]] = []
    let profiles = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Firefox/Profiles")
    let dirs = (try? FileManager.default.contentsOfDirectory(at: profiles, includingPropertiesForKeys: nil)) ?? []
    for dir in dirs {
        let file = dir.appendingPathComponent("sessionstore-backups/recovery.jsonlz4")
        guard let raw = try? Data(contentsOf: file), let json = mozLz4Decode(raw),
              let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let windows = root["windows"] as? [[String: Any]] else { continue }
        for w in windows {
            var tabs: [SessionTab] = []
            for t in (w["tabs"] as? [[String: Any]]) ?? [] {
                guard let entries = t["entries"] as? [[String: Any]], !entries.isEmpty else { continue }
                let idx = min(max(((t["index"] as? Int) ?? entries.count) - 1, 0), entries.count - 1)
                let url = entries[idx]["url"] as? String ?? ""
                tabs.append(SessionTab(title: entries[idx]["title"] as? String ?? url, url: url))
            }
            result.append(tabs)
        }
    }
    return result
}

/// Assigns a URL to each live tab. Each live window is paired with the session
/// window sharing the most titles; if tab counts agree, tabs map by position
/// (robust to titles that changed since the last save), otherwise by title.
func urlsFor(_ tabs: [Tab]) -> [String] {
    var sessions = sessionWindows()
    var urls = [String](repeating: "", count: tabs.count)
    let groups = Dictionary(grouping: tabs.indices) { "\(tabs[$0].pid):\(tabs[$0].window)" }
    for (_, idxs) in groups.sorted(by: { $0.value.count > $1.value.count }) {
        let live = idxs.map { tabs[$0].title }
        let liveSet = Set(live)
        guard let best = sessions.indices.max(by: { a, b in
            sessions[a].filter { liveSet.contains($0.title) }.count < sessions[b].filter { liveSet.contains($0.title) }.count
        }) else { break }
        let session = sessions.remove(at: best)
        if session.count == live.count {
            for (k, i) in idxs.enumerated() { urls[i] = session[k].url }
        } else {
            var pool = session
            for i in idxs {
                if let j = pool.firstIndex(where: { $0.title == tabs[i].title }) { urls[i] = pool.remove(at: j).url }
            }
        }
    }
    return urls
}

// MARK: - Commands

func emit(_ obj: Any) {
    let data = try! JSONSerialization.data(withJSONObject: obj)
    FileHandle.standardOutput.write(data)
}

func list() {
    guard AXIsProcessTrusted() else {
        emit(["items": [[
            "title": "Alfred needs Accessibility permission",
            "subtitle": "System Settings → Privacy & Security → Accessibility → enable Alfred",
            "arg": "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]]])
        return
    }
    let tabs = allTabs()
    if tabs.isEmpty {
        emit(["items": [["title": "No Firefox tabs found", "subtitle": "Is Firefox running?", "valid": false]]])
        return
    }
    let urls = urlsFor(tabs)
    let windowKeys = tabs.map { "\($0.pid):\($0.window)" }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
    let items: [[String: Any]] = zip(tabs, urls).map { t, url in
        var subtitle = url
        if windowKeys.count > 1 {
            let n = windowKeys.firstIndex(of: "\(t.pid):\(t.window)")! + 1
            subtitle = "Window \(n) · " + subtitle
        }
        let host = URL(string: url)?.host ?? ""
        let port = URL(string: url)?.port.map { ":\($0)" } ?? ""
        let arg: [String: Any] = ["pid": Int(t.pid), "window": t.window, "index": t.index,
                                  "title": t.title, "windowTitle": t.windowTitle]
        let argStr = String(data: try! JSONSerialization.data(withJSONObject: arg), encoding: .utf8)!
        return [
            "uid": url.isEmpty ? t.title : url,
            "title": (t.selected ? "● " : "") + t.title,
            "subtitle": subtitle,
            "arg": argStr,
            "match": "\(t.title) \(url) \(host)\(port) \(host) \(port.dropFirst())",
            "autocomplete": t.title,
            "quicklookurl": url,
            "text": ["copy": url, "largetype": url.isEmpty ? t.title : url],
            "mods": ["cmd": ["subtitle": "Copy URL: \(url)", "arg": url, "valid": !url.isEmpty]],
        ]
    }
    emit(["items": items])
}

func focus(_ argStr: String) {
    guard let data = argStr.data(using: .utf8),
          let arg = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let pid = arg["pid"] as? Int, let title = arg["title"] as? String else { exit(1) }
    let wantWindow = arg["window"] as? Int ?? -1
    let wantIndex = arg["index"] as? Int ?? -1
    let wantWindowTitle = arg["windowTitle"] as? String ?? ""

    let tabs = allTabs().filter { $0.pid == pid_t(pid) }
    // Prefer an exact position+title match; fall back to title (the tab may have
    // moved), then to position in the same window (the title may have changed).
    let tab = tabs.first { $0.window == wantWindow && $0.index == wantIndex && $0.title == title }
        ?? tabs.first { $0.title == title && $0.windowTitle == wantWindowTitle }
        ?? tabs.first { $0.title == title }
        ?? tabs.first { $0.windowTitle == wantWindowTitle && $0.index == wantIndex }
    guard let tab else { exit(1) }

    AXUIElementPerformAction(tab.element, "AXPress" as CFString)
    AXUIElementSetAttributeValue(tab.windowElement, "AXMain" as CFString, kCFBooleanTrue)
    AXUIElementPerformAction(tab.windowElement, "AXRaise" as CFString)
    NSRunningApplication(processIdentifier: pid_t(pid))?.activate()
}

// MARK: - Bookmarks

let profilesDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/Firefox/Profiles")

/// Profile directory name -> display name, from profiles.ini.
func profileNames() -> [String: String] {
    let ini = profilesDir.deletingLastPathComponent().appendingPathComponent("profiles.ini")
    guard let text = try? String(contentsOf: ini, encoding: .utf8) else { return [:] }
    var names: [String: String] = [:]
    var name: String?
    for line in text.split(whereSeparator: \.isNewline) {
        if line.hasPrefix("[") { name = nil }
        else if line.hasPrefix("Name=") { name = String(line.dropFirst(5)) }
        else if line.hasPrefix("Path="), let n = name {
            names[(String(line.dropFirst(5)) as NSString).lastPathComponent] = n
        }
    }
    return names
}

struct Bookmark { let title: String; let url: String; let folder: String; let profile: String }

/// Reads bookmarks from every profile, most-used (frecency) first. Firefox holds
/// an exclusive lock on places.sqlite, so we query a clone of it plus its WAL
/// (an instant copy-on-write on APFS) to see changes made seconds ago.
func allBookmarks() -> [Bookmark] {
    let fm = FileManager.default
    let names = profileNames()
    var result: [Bookmark] = []
    for dir in (try? fm.contentsOfDirectory(at: profilesDir, includingPropertiesForKeys: nil)) ?? [] {
        let db = dir.appendingPathComponent("places.sqlite")
        guard fm.fileExists(atPath: db.path) else { continue }
        let tmp = fm.temporaryDirectory.appendingPathComponent("fftabs-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmp) }
        do {
            try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
            try fm.copyItem(at: db, to: tmp.appendingPathComponent("places.sqlite"))
            let wal = dir.appendingPathComponent("places.sqlite-wal")
            if fm.fileExists(atPath: wal.path) {
                try fm.copyItem(at: wal, to: tmp.appendingPathComponent("places.sqlite-wal"))
            }
        } catch { continue }

        var conn: OpaquePointer?
        guard sqlite3_open(tmp.appendingPathComponent("places.sqlite").path, &conn) == SQLITE_OK else { continue }
        defer { sqlite3_close(conn) }

        func rows(_ sql: String, _ each: (OpaquePointer) -> Void) {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(conn, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { return }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW { each(stmt) }
        }
        func text(_ stmt: OpaquePointer, _ col: Int32) -> String {
            sqlite3_column_text(stmt, col).map { String(cString: $0) } ?? ""
        }

        // Folder tree, so each bookmark can show its path.
        let rootNames = ["menu________": "Bookmarks Menu", "toolbar_____": "Bookmarks Toolbar",
                         "unfiled_____": "Other Bookmarks", "mobile______": "Mobile Bookmarks"]
        var folders: [Int64: (parent: Int64, title: String, guid: String)] = [:]
        rows("SELECT id, parent, IFNULL(title, ''), guid FROM moz_bookmarks WHERE type = 2") { st in
            folders[sqlite3_column_int64(st, 0)] =
                (sqlite3_column_int64(st, 1), text(st, 2), text(st, 3))
        }
        func path(_ id: Int64) -> String? {  // nil = under the tags root, i.e. not a real bookmark
            var parts: [String] = []
            var cur = id
            while let f = folders[cur], parts.count < 50 {
                if f.guid == "tags________" { return nil }
                if f.guid == "root________" { break }
                parts.insert(rootNames[f.guid] ?? f.title, at: 0)
                cur = f.parent
            }
            return parts.joined(separator: " › ")
        }

        rows("""
            SELECT IFNULL(b.title, ''), p.url, b.parent FROM moz_bookmarks b
            JOIN moz_places p ON p.id = b.fk
            WHERE b.type = 1 AND p.url NOT LIKE 'place:%'
            ORDER BY p.frecency DESC
            """) { st in
            guard let folder = path(sqlite3_column_int64(st, 2)) else { return }
            let url = text(st, 1)
            result.append(Bookmark(title: text(st, 0).isEmpty ? url : text(st, 0), url: url, folder: folder,
                                   profile: names[dir.lastPathComponent] ?? dir.lastPathComponent))
        }
    }
    return result
}

func bookmarks() {
    let all = allBookmarks()
    if all.isEmpty {
        emit(["items": [["title": "No Firefox bookmarks found", "valid": false]]])
        return
    }
    let multiProfile = Set(all.map(\.profile)).count > 1
    var seen = Set<String>()
    let items: [[String: Any]] = all.compactMap { b in
        guard seen.insert(b.url).inserted else { return nil }
        let host = URL(string: b.url)?.host ?? ""
        let port = URL(string: b.url)?.port.map(String.init) ?? ""
        var location = b.folder
        if multiProfile { location = "\(b.profile) · " + location }
        return [
            "uid": b.url,
            "title": b.title,
            "subtitle": "\(location) · \(b.url)",
            "arg": b.url,
            "match": "\(b.title) \(b.url) \(host) \(port) \(b.folder)",
            "autocomplete": b.title,
            "quicklookurl": b.url,
            "text": ["copy": b.url, "largetype": b.url],
            "mods": ["cmd": ["subtitle": "Copy URL: \(b.url)", "arg": b.url]],
        ]
    }
    emit(["items": items])
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "list": list()
case "focus" where args.count > 2: focus(args[2])
case "bookmarks": bookmarks()
case "urls":  // debugging: dump session URLs without needing Accessibility
    emit(sessionWindows().map { $0.map { ["title": $0.title, "url": $0.url] } })
default:
    FileHandle.standardError.write("usage: fftabs list | focus <arg> | bookmarks | urls\n".data(using: .utf8)!)
    exit(2)
}
