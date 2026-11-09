pragma ComponentBehavior: Bound
import QtQuick

// Bookmarks: your Chrome bookmarks, searchable, opened in your browser. Edit them in Chrome.
ListModule {
    id: root

    property string folder: ""          // bar folder filter ("" = all)
    property int epoch: 0

    readonly property var all: {
        epoch;
        return Bookmarks.items.map(b => ({
            kind: "bookmark", key: b.id, data: b, glyph: (b.name.match(/[A-Za-z0-9]/) || ["•"])[0].toUpperCase(),
            tint: Theme.tint(Bookmarks.domain(b.url)), title: b.name,
            subtitle: (b.folder ? b.folder + "  ·  " : "") + Bookmarks.domain(b.url),
            meta: b.used ? ago(b.used) : "",
            actions: [{ label: "copy", run: () => root.copyUrl(b) }],
            hay: (b.name + " " + b.url + " " + b.folder).toLowerCase()
        }));
    }

    glyph: "bookmark"
    title: "Bookmarks"
    subtitle: Bookmarks.items.length + " bookmarks from Chrome"
    buttons: [{ glyph: "↻", tip: "Reload", run: () => Bookmarks.reload() }]
    placeholder: "Search bookmarks"
    tabNames: ["Bar", "Mobile & other", "Recent"]
    lists: [
        all.filter(i => i.data.root === "bar" && (query || !folder || i.data.top === folder)),
        all.filter(i => i.data.root !== "bar"),
        all.filter(i => i.data.used).sort((a, b) => b.data.used - a.data.used).slice(0, 60)
    ].map(l => filter(l, query))
    hints: [
        "⏎ open   ^⏎ copy link   ↑↓ move   ⇥ switch   edit bookmarks in Chrome",
        "⏎ open   ^⏎ copy link   ↑↓ move   ⇥ switch",
        "⏎ open   ^⏎ copy link   most recently used first"
    ]
    emptyTexts: [
        Bookmarks.items.length ? "No bookmarks in this folder." : "No Chrome bookmarks found in " + Bookmarks.profile + ".",
        "No mobile or other bookmarks.",
        "Nothing used recently."
    ]
    extra: tab === 0 && !query && Bookmarks.barFolders.length ? folderRow : null

    function open() {
        tab = 0;
        folder = "";
        epoch++;
        Bookmarks.reload();
        grab(true);
    }

    function ago(ms) {
        const s = (Date.now() - ms) / 1000;
        if (s < 3600) return Math.max(1, Math.floor(s / 60)) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        if (s < 30 * 86400) return Math.floor(s / 86400) + "d";
        return Qt.formatDate(new Date(ms), "MMM yyyy");
    }
    function filter(items, q) {
        if (!q) return items;
        const words = q.split(/\s+/);
        const hits = items.filter(i => words.every(w => i.hay.includes(w)));
        return hits.filter(i => i.title.toLowerCase().startsWith(q)).concat(hits.filter(i => !i.title.toLowerCase().startsWith(q)));
    }
    function copyUrl(b) {
        Claude.run(["wl-copy", "--", b.url], Claude.home);
        toast("Copied " + b.url.slice(0, 60));
    }
    function pickFolder(name) {
        folder = name;
        listView.currentIndex = 0;
        focusSearch();
    }

    onActivated: (item, alt, shell) => shell ? copyUrl(item.data) : Bookmarks.open(item.data)

    Component {
        id: folderRow
        Flow {
            spacing: 5
            Chip { label: "All"; lit: root.folder === ""; onClicked: root.pickFolder("") }
            Repeater {
                model: Bookmarks.barFolders
                delegate: Chip {
                    required property string modelData
                    label: modelData
                    lit: root.folder === modelData
                    onClicked: root.pickFolder(modelData)
                }
            }
        }
    }
}
