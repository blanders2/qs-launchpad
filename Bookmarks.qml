pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Your Chrome bookmarks, read live (read-only) from the profile in config "chromeProfile":
// both its local `Bookmarks` file and the signed-in `AccountBookmarks` one.
Singleton {
    id: root

    readonly property string profile: Claude.expand(Claude.cfg.chromeProfile || "~/.config/google-chrome/Default")
    property var local: []
    property var account: []
    readonly property var items: account.concat(local)
    // Top-level folders on the bookmarks bar, in Chrome's order.
    readonly property var barFolders: {
        const seen = [];
        items.forEach(b => { if (b.root === "bar" && b.top && seen.indexOf(b.top) < 0) seen.push(b.top); });
        return seen;
    }

    function reload() {
        localFile.reload();
        accountFile.reload();
    }
    function open(b) {
        Claude.run(["xdg-open", b.url], Claude.home);
        Claude.close();
    }

    // Chrome stores times as microseconds since 1601-01-01; 0 means never.
    function chromeTime(v) {
        const t = Number(v);
        return t > 0 ? Math.round(t / 1000 - 11644473600000) : 0;
    }
    function domain(url) { return url.replace(/^[a-z][a-z0-9+.-]*:\/\//i, "").split(/[/?#]/)[0].replace(/^www\./, ""); }

    function parse(text, source) {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            console.warn("qs-launchpad: can't read Chrome bookmarks:", e);
            return [];
        }
        const out = [];
        const roots = { bookmark_bar: "bar", other: "other", synced: "mobile" };
        const walk = (node, root, path) => {
            for (const c of node.children || []) {
                if (c.type === "folder") {
                    walk(c, root, path.concat([c.name]));
                } else if (c.type === "url" && typeof c.url === "string" && !/^javascript:/i.test(c.url)) {
                    out.push({ id: source + ":" + (c.guid || c.id), name: c.name || domain(c.url), url: c.url,
                               root: root, folder: path.join(" / "), top: path[0] || "",
                               added: chromeTime(c.date_added), used: chromeTime(c.date_last_used) });
                }
            }
        };
        for (const key in roots)
            if (data.roots && data.roots[key]) walk(data.roots[key], roots[key], []);
        return out;
    }

    FileView {
        id: localFile
        path: root.profile + "/Bookmarks"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.local = root.parse(text(), "local")
        onLoadFailed: root.local = []
    }
    FileView {
        id: accountFile
        path: root.profile + "/AccountBookmarks"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.account = root.parse(text(), "account")
        onLoadFailed: root.account = []
    }
}
