pragma ComponentBehavior: Bound
import QtQuick

// Tailscale: your tailnet's devices (SSH, copy address, ping, open in a browser) and this device's
// connection, addresses and exit node.
ListModule {
    id: root

    glyph: "tailscale"
    title: "Tailscale"
    subtitle: Tailscale.error ? "Not reachable"
        : !Tailscale.status ? "Reading status…"
        : (Tailscale.running ? "Connected" : Tailscale.state) + "  ·  " + Tailscale.onlineCount + " of " + Tailscale.peers.length + " devices online"
    buttons: [{ glyph: "↻", tip: "Refresh", run: () => Tailscale.refresh() }]
    searchable: false
    tabNames: ["Devices", "This device"]
    lists: [deviceItems(), selfItems()]
    hints: [
        "⏎ ssh   ^⏎ copy address   hover for ping · web · exit node",
        "⏎ copy or run   ↑↓ move   ⇥ switch"
    ]
    emptyTexts: [Tailscale.error || (Tailscale.status ? "No other devices on your tailnet." : "Reading status…"), Tailscale.error || ""]

    function open() {
        tab = 0;
        Tailscale.refresh();
        if (!Ssh.hosts.length) Ssh.refreshHosts();     // so SSH goes in as the user you use there
        grab(true);
    }

    function ago(iso) {
        const t = Date.parse(iso);
        if (!t || t < 86400000) return "";
        const s = (Date.now() - t) / 1000;
        if (s < 3600) return "seen " + Math.max(1, Math.floor(s / 60)) + "m ago";
        if (s < 86400) return "seen " + Math.floor(s / 3600) + "h ago";
        return "seen " + Math.floor(s / 86400) + "d ago";
    }
    function osTint(os) {
        return os === "linux" ? Theme.good : os === "windows" ? "#6f8fd9" : os === "android" ? "#5eb1bf"
             : os === "macOS" || os === "iOS" ? Theme.dim : Theme.tint(os || "");
    }
    function route(p) {
        if (!p.Online) return "";
        return p.CurAddr ? "direct" : p.Relay ? "relay " + p.Relay : "";
    }

    function deviceItems() {
        if (!Tailscale.status) return [];
        return Tailscale.peers.map(p => {
            const ip = Tailscale.ipv4(p);
            const ping = Tailscale.pings[p.ID];
            const actions = [{ label: "copy", run: () => root.copy(ip, ip) }];
            if (p.Online) {
                actions.push({ label: Tailscale.busy[p.ID] ? "…" : "ping", run: () => root.ping(p) });
                actions.push({ label: "web", run: () => Tailscale.web(p) });
            }
            if (p.ExitNodeOption)
                actions.push({ label: p.ExitNode ? "stop exit" : "exit node", lit: p.ExitNode, run: () => root.exitNode(p.ExitNode ? null : p) });
            return {
                kind: "peer", key: p.ID, data: p, glyph: (p.HostName.match(/[A-Za-z0-9]/) || ["?"])[0].toUpperCase(), tint: osTint(p.OS),
                title: p.HostName, subtitle: [ip, Tailscale.shortName(p) !== p.HostName.toLowerCase() ? Tailscale.shortName(p) : "", p.OS, route(p)].filter(Boolean).join("  ·  "),
                status: p.Online ? "ok" : "bad", meta: Tailscale.busy[p.ID] ? "pinging…" : ping || (p.Online ? "online" : ago(p.LastSeen) || "offline"),
                badge: p.ExitNode ? "exit node" : "", dim: !p.Online, actions: actions
            };
        });
    }

    function selfItems() {
        const me = Tailscale.me;
        if (!me) return [];
        const row = (key, glyph, title, subtitle, run, extra) => Object.assign({ kind: "self", key: key, glyph: glyph, tint: Theme.accent,
                                                                                title: title, subtitle: subtitle, run: run, actions: [] }, extra || {});
        const ip4 = Tailscale.ipv4(me), ip6 = (me.TailscaleIPs || []).find(ip => ip.indexOf(":") >= 0) || "";
        const dns = Tailscale.dnsName(me);
        const rows = [
            row("conn", Tailscale.running ? "●" : "○", Tailscale.running ? "Connected" : "Disconnected",
                (Tailscale.running ? "⏎ disconnects" : "⏎ connects") + "  ·  tailnet " + Tailscale.tailnet,
                () => root.toggleConnection(), { status: Tailscale.running ? "ok" : "bad", tint: Tailscale.running ? Theme.good : Theme.bad }),
            row("ip4", "4", ip4, "Tailscale IPv4  ·  ⏎ copies", () => root.copy(ip4, ip4)),
            row("ip6", "6", ip6, "Tailscale IPv6  ·  ⏎ copies", () => root.copy(ip6, "the IPv6 address")),
            row("dns", "@", dns, "MagicDNS name  ·  ⏎ copies", () => root.copy(dns, dns)),
            row("exit", "⇱", Tailscale.exitNode ? "Exit node: " + Tailscale.exitNode.HostName : "No exit node",
                Tailscale.exitNode ? "⏎ stops using it" : Tailscale.peers.some(p => p.ExitNodeOption) ? "Pick one on the Devices tab" : "No device on your tailnet offers one",
                () => Tailscale.exitNode ? root.exitNode(null) : null),
            row("admin", "⚙", "Admin console", "login.tailscale.com/admin", () => { Claude.run(["xdg-open", "https://login.tailscale.com/admin/machines"], Claude.home); Claude.close(); })
        ];
        return rows.filter(r => r.title);
    }

    function copy(text, what) {
        Tailscale.copy(text);
        toast("Copied " + what + ".");
    }
    function ping(p) {
        Tailscale.ping(p, (err, result) => toast(p.HostName + ": " + result, !!err));
    }
    function toggleConnection() {
        const on = !Tailscale.running;
        Tailscale.connect(on, err => err ? toast(err, true) : toast(on ? "Connected." : "Disconnected."));
    }
    function exitNode(p) {
        Tailscale.useExitNode(p, err => err ? toast(err, true) : toast(p ? "Routing through " + p.HostName + "." : "Stopped using the exit node."));
    }

    onActivated: (item, alt, shell) => {
        if (!item) return;
        if (item.kind === "peer") shell ? copy(Tailscale.ipv4(item.data), Tailscale.ipv4(item.data)) : item.data.Online ? Tailscale.ssh(item.data) : toast(item.data.HostName + " is offline.", true);
        else if (item.run) item.run();
    }
}
