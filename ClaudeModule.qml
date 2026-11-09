import QtQuick

// Claude: pinned items, projects, past sessions and links.
ListModule {
    id: root

    property int epoch: 0               // bumped on every open, so relative times and the entrance refresh

    glyph: "✻"
    title: "Claude"
    subtitle: Claude.projects.length + " projects  ·  " + Claude.sessions.length + " sessions"
        + Claude.hosts.filter(h => !h.online).map(h => "  ·  " + h.name + " offline").join("")
    buttons: [
        { glyph: "+", tip: "New session", run: () => Claude.newBlankSession() },
        { glyph: "↻", tip: "Refresh", run: () => Claude.refresh() }
    ]
    placeholder: "Search projects, sessions and links"
    tabNames: ["Pinned", "Projects", "Sessions", "Links"]
    lists: all.map((items, t) => t === 0 ? filter(items, query, true) : pinnedFirst(filter(items, query)))
    hints: [
        "⏎ open   ^⏎ terminal   ^P unpin   alt+↑↓ reorder   ⇥ switch",
        "⏎ new   ⇧⏎ continue   ^⏎ terminal   ^P pin   ^E editor   ^O files",
        "⏎ resume   ^⏎ terminal   ^P pin   ↑↓ move   ⇥ switch",
        "⏎ open   ↑↓ move   ⇥ switch   esc close"
    ]
    emptyTexts: [
        "Nothing pinned yet.\nPin a project or session with ☆, right-click or ^P.",
        Claude.loading ? "Reading sessions…" : "No projects found",
        Claude.loading ? "Reading sessions…" : "No sessions yet",
        "No links yet. Add some under \"links\" in config.json."
    ]

    readonly property var all: {
        epoch;
        const projects = projectItems(), sessions = sessionItems();
        const byKey = {};
        projects.concat(sessions).forEach(i => byKey[i.key] = i);
        // Pinned tab keeps your pin order; elsewhere pinned items just float to the top.
        return [Claude.pins.map(k => byKey[k]).filter(Boolean), pinnedFirst(projects), pinnedFirst(sessions), linkItems()];
    }

    function open() {
        tab = Claude.pins.length ? 0 : 1;
        epoch++;
        grab(true);
    }

    function pinnedFirst(items) { return items.filter(i => i.pinned).concat(items.filter(i => !i.pinned)); }

    function ago(ms) {
        const s = (Date.now() - ms) / 1000;
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        if (s < 7 * 86400) return Math.floor(s / 86400) + "d";
        return Qt.formatDate(new Date(ms), "MMM d");
    }

    function projectName(cwd, host) {
        const p = Claude.projects.find(p => p.path === cwd && p.host === host);
        return p ? p.name : cwd.split("/").pop() || "/";
    }

    function pinAction(d) {
        const on = Claude.isPinned(d);
        return { label: on ? "★" : "☆", lit: on, run: () => root.togglePin({ key: Claude.pinKey(d), data: d }) };
    }

    function projectItems() {
        return Claude.projects.map(p => ({
            kind: "project", data: p, glyph: p.name.charAt(0).toUpperCase(), tint: Theme.tint(p.name),
            title: p.name, subtitle: p.last || (p.host ? p.hostName + ":" : "") + p.short, meta: p.time ? ago(p.time) : "",
            badge: p.sessions ? String(p.sessions) : "", host: p.hostName, dim: false,
            key: Claude.pinKey(p), pinned: Claude.isPinned(p),
            actions: [pinAction(p),
                      { label: "continue", run: () => Claude.continueSession(p) },
                      { label: "terminal", run: () => Claude.openTerminal(p) },
                      { label: "code", run: () => Claude.openEditor(p) },
                      { label: "files", run: () => Claude.openFiles(p) }],
            hay: (p.name + " " + p.short + " " + p.last + " " + p.hostName).toLowerCase()
        }));
    }

    function sessionItems() {
        return Claude.sessions.map(s => ({
            kind: "session", data: s, glyph: s.source === "cli" ? "❯" : "✻", tint: Theme.tint(projectName(s.cwd, s.host)),
            title: s.title, subtitle: projectName(s.cwd, s.host) + (s.branch && s.branch !== "HEAD" ? "  ·  " + s.branch : "") + "  ·  " + s.turns + (s.turns === 1 ? " prompt" : " prompts"),
            meta: ago(s.time), badge: "", host: s.hostName, dim: !s.exists,
            key: Claude.pinKey(s), pinned: Claude.isPinned(s),
            actions: [pinAction(s), { label: "terminal", run: () => Claude.openTerminal(s) }],
            hay: (s.title + " " + s.cwd + " " + s.prompt + " " + s.branch + " " + s.hostName).toLowerCase()
        }));
    }

    function linkItems() {
        return (Claude.cfg.links || []).filter(l => l && l.name).map(l => ({
            kind: "link", data: l, glyph: l.icon || "↗", tint: Theme.accent,
            title: l.name, subtitle: l.note || l.url || [].concat(l.terminal || l.command || []).join(" "),
            meta: "", badge: "", host: "", dim: false, key: "", pinned: false, actions: [],
            hay: (l.name + " " + (l.note || "") + " " + (l.url || "")).toLowerCase()
        }));
    }

    // Every word must appear somewhere; titles that start with the query float up (unless keepOrder).
    function filter(items, q, keepOrder) {
        if (!q) return items.slice();
        const words = q.split(/\s+/);
        const hits = items.filter(i => words.every(w => i.hay.includes(w)));
        if (keepOrder) return hits;
        return hits.filter(i => i.title.toLowerCase().startsWith(q))
            .concat(hits.filter(i => !i.title.toLowerCase().startsWith(q)));
    }

    function togglePin(item) {
        if (!item || !item.key) return;
        Claude.togglePin(item.data);
        keep(item.key);
    }
    function movePin(item, by) {
        if (!item || !item.pinned || tab !== 0 || query) return;
        Claude.movePin(item.data, by);
        keep(item.key);
    }

    // alt: continue the last session instead of starting one (projects). shell: open a terminal there instead.
    onActivated: (item, alt, shell) => {
        if (!item || item.dim) return;
        if (item.kind !== "link" && shell) Claude.openTerminal(item.data);
        else if (item.kind === "project") alt ? Claude.continueSession(item.data) : Claude.newSession(item.data);
        else if (item.kind === "session") Claude.resume(item.data);
        else Claude.openLink(item.data);
    }
    onPinToggled: item => togglePin(item)

    keyHandler: (event, cur) => {
        const ctrl = event.modifiers & Qt.ControlModifier, alt = event.modifiers & Qt.AltModifier;
        if (alt && event.key === Qt.Key_Down) movePin(cur, 1);
        else if (alt && event.key === Qt.Key_Up) movePin(cur, -1);
        else if (ctrl && event.key === Qt.Key_P) togglePin(cur);
        else if (ctrl && event.key === Qt.Key_N) Claude.newBlankSession();
        else if (ctrl && event.key === Qt.Key_E && cur?.kind === "project") Claude.openEditor(cur.data);
        else if (ctrl && event.key === Qt.Key_O && cur?.kind === "project") Claude.openFiles(cur.data);
        else return false;
        return true;
    }
}
