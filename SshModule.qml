pragma ComponentBehavior: Bound
import QtQuick

// SSH: servers from ~/.ssh/config and the Claude app, port-forward tunnels, and public keys
// (PatchGoblin's SSH tools plugin, without saved servers or the network map).
ListModule {
    id: root

    property var selected: []           // key texts picked for a multi-key install

    glyph: ">_"
    title: "SSH"
    subtitle: Ssh.hosts.length + " hosts  ·  " + Ssh.running + " of " + Ssh.tunnels.length + " tunnels running"
    buttons: (tab === 1 ? [{ glyph: "+", tip: "New tunnel", run: () => root.editTunnel(null) }]
              : tab === 2 ? [{ glyph: "+", tip: "New key", run: () => root.newKey() }] : [])
             .concat([{ glyph: "↻", tip: "Refresh", run: () => root.refresh() }])
    searchable: false
    tabNames: ["Servers", "Tunnels", "Keys"]
    lists: [hostItems(), tunnelItems(), keyItems()].map(l => filter(l, query))
    hints: [
        "⏎ terminal   hover for claude · files · keys   ⇥ switch",
        "⏎ start / stop   ^N new   ^E edit   ^D delete   ⇥ switch",
        "⏎ copy   ^␣ or right-click select   ^I install   ^N new key"
    ]
    emptyTexts: [
        Ssh.hostsLoading ? "Looking for hosts…" : "No hosts in ~/.ssh/config or the Claude app.",
        "",
        Ssh.keysLoading ? "Reading keys…" : Ssh.keysError || "No public keys in " + (Ssh.keysHost ? Ssh.keysHost + ":" : "") + "~/.ssh."
    ]
    extra: tab === 2 ? keysHostRow : null

    function open() {
        tab = 0;
        grab(true);
        refresh();
    }
    function refresh() {
        Ssh.refreshHosts();
        Ssh.refreshTunnels();
        if (tab === 2 || Ssh.keysLoaded) Ssh.refreshKeys(Ssh.keysHost);
    }
    onTabChanged: if (tab === 2 && !Ssh.keysLoaded && !Ssh.keysLoading) Ssh.refreshKeys(Ssh.keysHost)

    function filter(items, q) {
        if (!q) return items;
        const words = q.split(/\s+/);
        return items.filter(i => words.every(w => i.hay.includes(w)));
    }
    function hostLabel(h) { return (h.user ? h.user + "@" : "") + h.hostname + (h.port !== 22 ? ":" + h.port : ""); }

    function hostItems() {
        return Ssh.hosts.map(h => ({
            kind: "host", key: h.target, data: h, glyph: h.name.charAt(0).toUpperCase(), tint: Theme.tint(h.name),
            title: h.name, subtitle: hostLabel(h) + (h.source === "claude" ? "  ·  from the Claude app" : ""),
            status: h.reachable === true ? "ok" : h.reachable === false ? "bad" : "unknown",
            meta: h.reachable === true ? "up" : h.reachable === false ? "unreachable" : "",
            actions: [{ label: "claude", run: () => Ssh.claudeOn(h) },
                      { label: "files", run: () => Ssh.files(h) },
                      { label: "keys", run: () => root.keysOn(h.target) }],
            hay: (h.name + " " + h.target + " " + h.hostname + " " + h.user).toLowerCase()
        }));
    }

    function describe(t) {
        const there = t.dest_host + ":" + t.dest_port;
        const bind = t.bind === "0.0.0.0" ? "0.0.0.0" : "localhost";
        return t.direction === "local" ? bind + ":" + t.listen_port + " → " + there + " via " + t.target
                                       : t.target + ":" + t.listen_port + " → " + there + " here";
    }
    // A row at the top of a tab that opens a form, so adding things is always in plain sight.
    function addRow(title, subtitle, run) {
        return { kind: "add", key: "+" + title, glyph: "+", tint: Theme.accent, title: title, subtitle: subtitle,
                 meta: "", badge: "", actions: [], run: run, hay: "" };
    }

    function tunnelItems() {
        return [addRow("New tunnel", "Forward a port through one of your hosts", () => root.editTunnel(null))].concat(Ssh.tunnels.map(t => {
            const busy = !!Ssh.busy[t.id] || t.state === "starting";
            const on = t.state === "running";
            return {
                kind: "tunnel", key: t.id, data: t, glyph: t.direction === "local" ? "⇥" : "⇤", tint: on ? Theme.good : Theme.dim,
                title: t.name, subtitle: t.state === "failed" && t.error ? t.error : describe(t), subtitleBad: t.state === "failed",
                status: busy ? "busy" : on ? "ok" : t.state === "failed" ? "bad" : "unknown",
                meta: busy ? "…" : t.state, badge: t.bind === "0.0.0.0" ? "0.0.0.0" : "",
                actions: [{ label: on ? "stop" : "start", run: () => root.toggleTunnel(t) },
                          { label: "edit", run: () => root.editTunnel(t) },
                          { label: "delete", run: () => root.deleteTunnel(t) }],
                hay: (t.name + " " + t.target + " " + describe(t)).toLowerCase()
            };
        }));
    }

    function keyItems() {
        const add = addRow("New key pair", "Generate one in ~/.ssh " + (Ssh.keysHost ? "on " + Ssh.keysHost : "here"), () => root.newKey());
        if (Ssh.keysLoading && !Ssh.keys.length) return [];
        if (Ssh.keysError) Object.assign(add, { subtitle: Ssh.keysError, subtitleBad: true });
        return [add].concat(Ssh.keys.map(k => ({
            kind: "key", key: k.text, data: k, glyph: "⚿", tint: Theme.warn,
            title: k.name, subtitle: k.type.replace(/^ssh-/, "") + "  ·  " + (k.fingerprint || "").replace(/^SHA256:/, "").slice(0, 16) + "…"
                + (k.comment ? "  ·  " + k.comment : ""),
            meta: k.has_private ? "key pair" : "public only", selected: root.selected.indexOf(k.text) >= 0,
            actions: [{ label: "copy", run: () => root.copyKey(k) },
                      { label: "install…", run: () => root.installKeys([k]) }],
            hay: (k.name + " " + k.type + " " + k.comment + " " + k.fingerprint).toLowerCase()
        })));
    }

    function keysOn(target) {
        selected = [];
        Ssh.refreshKeys(target);
        setTab(2);
    }
    function toggleSelect(item) {
        if (!item || item.kind !== "key") return;
        const k = item.data.text;
        selected = selected.indexOf(k) >= 0 ? selected.filter(x => x !== k) : selected.concat([k]);
    }
    function copyKey(k) {
        Ssh.copy(k.text);
        toast("Copied the public key " + k.name + ".");
    }

    function toggleTunnel(t) {
        if (Ssh.busy[t.id]) return;
        if (t.state === "running") {
            Ssh.stopTunnel(t, r => r.error ? toast(r.error, true) : toast("Stopped " + t.name + "."));
            return;
        }
        const start = () => Ssh.startTunnel(t, r => r.error ? toast(t.name + ": " + r.error, true) : toast("Started " + t.name + "."));
        if (t.bind !== "0.0.0.0") return start();
        sheet.open({
            title: "Start “" + t.name + "”?",
            submitLabel: "Start",
            fields: [{ kind: "note", warn: true, text: "This tunnel binds 0.0.0.0, so port " + t.listen_port
                       + " is reachable from your whole network with no login in front of it."
                       + (t.direction === "remote" ? " For a remote tunnel the server must also allow GatewayPorts." : "") }],
            submit: v => { sheet.close(); start(); }
        });
    }

    function editTunnel(t) {
        const hostOptions = Ssh.hosts.map(h => ({ value: h.target, label: h.name }));
        sheet.open({
            title: t ? "Edit tunnel" : "New tunnel",
            submitLabel: "Save",
            fields: [
                { key: "name", label: "Name", kind: "text", value: t ? t.name : "", placeholder: "e.g. myhost web" },
                { key: "target", label: "Through host", kind: "host", value: t ? t.target : "", options: hostOptions, placeholder: "user@host" },
                { key: "direction", label: "Direction", kind: "choice", value: t ? t.direction : "local",
                  options: [{ value: "local", label: "Local -L: reach a port over there from here" },
                            { value: "remote", label: "Remote -R: offer a port from here over there" }] },
                { key: "listen_port", label: "Listen on port", kind: "text", value: t ? String(t.listen_port) : "", placeholder: "8080" },
                { key: "bind", label: "Listen address", kind: "choice", value: t ? t.bind : "127.0.0.1",
                  options: [{ value: "127.0.0.1", label: "127.0.0.1 (this machine only)" }, { value: "0.0.0.0", label: "0.0.0.0 (whole network)" }] },
                { key: "dest_host", label: "Forward to host", kind: "text", value: t ? t.dest_host : "localhost", placeholder: "localhost" },
                { key: "dest_port", label: "Forward to port", kind: "text", value: t ? String(t.dest_port) : "", placeholder: "80" },
                { key: "port", label: "SSH port (optional)", kind: "text", value: t && t.port ? String(t.port) : "", placeholder: "22" },
                { kind: "note", text: "Tunnels run as systemd user units (qs-launchpad-tunnel-<id>). They only start when you start them, and they keep running if the dock reloads or quits." }
            ],
            submit: v => {
                sheet.busy = true;
                const spec = { id: t ? t.id : "", name: v.name, target: v.target, direction: v.direction, bind: v.bind,
                               listen_port: v.listen_port, dest_host: v.dest_host, dest_port: v.dest_port, port: v.port || null };
                Ssh.saveTunnel(spec, r => {
                    sheet.busy = false;
                    if (r.error) { sheet.error = r.error; return; }
                    sheet.close();
                    keep(r.tunnel.id);
                    toast("Saved " + r.tunnel.name + (t && t.state === "running" ? ". Restart it to use the changes." : "."));
                });
            }
        });
    }

    function deleteTunnel(t) {
        sheet.open({
            title: "Delete “" + t.name + "”?",
            submitLabel: "Delete",
            fields: [{ kind: "note", text: (t.state === "running" ? "It's running and will be stopped. " : "") + describe(t) }],
            submit: v => {
                sheet.busy = true;
                Ssh.deleteTunnel(t, r => {
                    sheet.busy = false;
                    if (r.error) { sheet.error = r.error; return; }
                    sheet.close();
                    toast("Deleted " + t.name + ".");
                });
            }
        });
    }

    function newKey() {
        const where = [{ value: "", label: "This computer" }].concat(Ssh.hosts.map(h => ({ value: h.target, label: h.name })));
        sheet.open({
            title: "New key pair",
            submitLabel: "Generate",
            fields: [
                { key: "name", label: "File name in ~/.ssh", kind: "text", value: "", placeholder: "id_ed25519_work", mono: true },
                { key: "type", label: "Type", kind: "choice", value: "ed25519", options: ["ed25519", "rsa", "ecdsa"] },
                { key: "comment", label: "Comment", kind: "text", value: "", placeholder: "you@machine" },
                { key: "host", label: "Create on", kind: "choice", value: Ssh.keysHost, options: where },
                { key: "passphrase", kind: "toggle", value: false, text: "Protect it with a passphrase (ssh-keygen asks in a terminal)" }
            ],
            submit: v => {
                sheet.busy = true;
                const finish = r => {
                    sheet.busy = false;
                    if (r.error) { sheet.error = r.error; return; }
                    sheet.close();
                    toast(v.passphrase ? "ssh-keygen is waiting for the passphrase in TerminalGoblin." : "Created " + v.name + ".");
                };
                v.passphrase ? Ssh.generateInTerminal(v, finish) : Ssh.generate(v, finish);
            }
        });
    }

    // Install the given keys (or the selected ones) into a host's authorized_keys.
    function installKeys(keys) {
        const texts = keys && keys.length ? keys.map(k => k.text) : selected;
        if (!texts.length) { toast("Pick a key first.", true); return; }
        const names = Ssh.keys.filter(k => texts.indexOf(k.text) >= 0).map(k => k.name);
        sheet.open({
            title: "Install " + (names.length === 1 ? names[0] : names.length + " keys"),
            submitLabel: "Install",
            fields: [
                { key: "host", label: "Into authorized_keys on", kind: "host", value: "",
                  options: Ssh.hosts.filter(h => h.target !== Ssh.keysHost).map(h => ({ value: h.target, label: h.name })), placeholder: "user@host" },
                { key: "password", kind: "toggle", value: false, text: "The host only takes a password (opens a terminal to type it)" },
                { kind: "note", text: "Keys already there are skipped. Only public keys are sent. Linux and macOS hosts only." }
            ],
            submit: v => {
                if (!v.host) { sheet.error = "Choose a host."; return; }
                sheet.busy = true;
                const done = r => {
                    sheet.busy = false;
                    if (r.error) { sheet.error = r.error; return; }
                    sheet.close();
                    selected = [];
                    if (v.password) toast("Type the password for " + v.host + " in TerminalGoblin.");
                    else toast((r.added.length ? r.added.length + " added" : "Nothing new added")
                               + (r.skipped.length ? ", " + r.skipped.length + " already there" : "") + " on " + v.host + ".");
                };
                v.password ? Ssh.installInTerminal(v.host, texts, done) : Ssh.install(v.host, texts, done);
            }
        });
    }

    onActivated: (item, alt, shell) => {
        if (!item) return;
        if (item.kind === "host") Ssh.shell(item.data);
        else if (item.kind === "tunnel") toggleTunnel(item.data);
        else if (item.kind === "key") copyKey(item.data);
        else if (item.kind === "add") item.run();
    }
    onPinToggled: item => toggleSelect(item)

    keyHandler: (event, cur) => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (ctrl && event.key === Qt.Key_Space) toggleSelect(cur);
        else if (ctrl && event.key === Qt.Key_I && tab === 2) installKeys(selected.length ? [] : cur ? [cur.data] : []);
        else if (ctrl && event.key === Qt.Key_E && cur?.kind === "tunnel") editTunnel(cur.data);
        else if (ctrl && event.key === Qt.Key_D && cur?.kind === "tunnel") deleteTunnel(cur.data);
        else if (ctrl && event.key === Qt.Key_N) tab === 1 ? editTunnel(null) : tab === 2 ? newKey() : null;
        else return false;
        return true;
    }

    // On the Keys tab: whose ~/.ssh is listed.
    Component {
        id: keysHostRow
        Flow {
            spacing: 5
            Text {
                text: "Keys on"
                color: Theme.faint
                height: 22
                verticalAlignment: Text.AlignVCenter
                font { family: Theme.font; pixelSize: 11 }
            }
            Chip { label: "this computer"; lit: Ssh.keysHost === ""; onClicked: root.keysOn("") }
            Repeater {
                model: Ssh.hosts
                delegate: Chip {
                    required property var modelData
                    label: modelData.name
                    lit: Ssh.keysHost === modelData.target
                    onClicked: root.keysOn(modelData.target)
                }
            }
        }
    }
}
