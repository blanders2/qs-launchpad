pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// SSH state and actions for the SSH module. The work is done by bin/ssh-tools, which answers
// in JSON; each call runs as its own process so slow hosts never block anything else.
Singleton {
    id: root

    readonly property string tunnelsFile: Quickshell.shellPath("tunnels.json")

    property var hosts: []              // [{name, target, source, hostname, user, port, reachable}]
    property bool hostsLoading: false
    property var keys: []               // public keys in keysHost's ~/.ssh ("" = this computer)
    property string keysHost: ""
    property bool keysLoading: false
    property bool keysLoaded: false
    property string keysError: ""
    property var tunnels: []            // saved tunnels with state: running | starting | failed | stopped
    property var busy: ({})             // tunnel id → true while it's being started or stopped
    readonly property int running: tunnels.filter(t => t.state === "running").length

    // Run `ssh-tools args…` with `input` on stdin; `callback` gets the parsed JSON ({error} on failure).
    function call(args, input, callback) {
        const proc = job.createObject(root, {
            command: ["python3", Quickshell.shellPath("bin/ssh-tools")].concat(args),
            input: input || "",
            callback: callback || null
        });
        proc.running = true;
    }

    function refreshHosts() {
        if (hostsLoading) return;
        hostsLoading = true;
        call(["hosts"], "", r => {
            hostsLoading = false;
            if (!r.error) hosts = r.hosts;
        });
    }
    function refreshKeys(host) {
        const want = host || "";
        keysHost = want;
        keysLoading = true;
        keysError = "";
        call(want ? ["keys", "--host", want] : ["keys"], "", r => {
            if (want !== keysHost) return;      // a newer request replaced this one
            keysLoading = false;
            keysLoaded = true;
            keys = r.error ? [] : r.keys;
            keysError = r.error || "";
        });
    }
    function refreshTunnels() {
        call(["tunnels", tunnelsFile], "", r => { if (!r.error) tunnels = r.tunnels; });
    }

    function setBusy(id, on) {
        const b = Object.assign({}, busy);
        if (on) b[id] = true; else delete b[id];
        busy = b;
    }
    function startTunnel(t, done) {
        setBusy(t.id, true);
        call(["tunnel-start", tunnelsFile, t.id], "", r => { setBusy(t.id, false); refreshTunnels(); if (done) done(r); });
    }
    function stopTunnel(t, done) {
        setBusy(t.id, true);
        call(["tunnel-stop", t.id], "", r => { setBusy(t.id, false); refreshTunnels(); if (done) done(r); });
    }
    function saveTunnel(spec, done) {
        call(["tunnel-save", tunnelsFile, JSON.stringify(spec)], "", r => { refreshTunnels(); if (done) done(r); });
    }
    function deleteTunnel(t, done) {
        call(["tunnel-delete", tunnelsFile, t.id], "", r => { refreshTunnels(); if (done) done(r); });
    }

    function keyArgs(v) {
        return ["--name", v.name || "", "--type", v.type || "ed25519", "--comment", v.comment || ""].concat(v.host ? ["--host", v.host] : []);
    }
    function generate(v, done) {
        call(["generate"].concat(keyArgs(v)), "", r => { if (!r.error && (v.host || "") === keysHost) refreshKeys(keysHost); done(r); });
    }
    // With a passphrase, ssh-keygen asks for it in a terminal, so it never shows up in a process list.
    function generateInTerminal(v, done) {
        call(["keygen-command"].concat(keyArgs(v)), "", r => {
            if (!r.error) Claude.terminal(Claude.home, "", "ssh-keygen " + v.name, r.argv);
            done(r);
        });
    }
    function install(host, keyTexts, done) {
        call(["install", "--host", host], keyTexts.join("\n") + "\n", done);
    }
    // For a host that only takes a password: ssh runs in a terminal and you type it there.
    function installInTerminal(host, keyTexts, done) {
        call(["install-command", "--host", host], keyTexts.join("\n") + "\n", r => {
            if (!r.error) Claude.terminal(Claude.home, "", "Install keys on " + host, r.argv);
            done(r);
        });
    }

    function copy(text) { Claude.run(["wl-copy", "--", text], Claude.home); }
    function shell(h) { Claude.terminal("", h.target, h.name); Claude.close(); }
    function claudeOn(h) { Claude.openUrl(Claude.claudeUrl("code/new", { ssh_host: h.target })); Claude.close(); }
    function files(h) { Claude.run(Claude.fill(Claude.cfg.remoteFileManager, { cwd: "", host: h.target }), Claude.home); Claude.close(); }

    // Tunnel states: every 3 s while the launcher is open, every 30 s otherwise (for the rail badge).
    Timer {
        interval: Claude.open ? 3000 : 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshTunnels()
    }

    Component {
        id: job
        Process {
            id: proc
            property string input: ""
            property var callback: null
            stdinEnabled: true
            onStarted: {
                if (input) write(input);
                stdinEnabled = false;
            }
            stdout: StdioCollector {
                onStreamFinished: {
                    let r;
                    try {
                        r = JSON.parse(text);
                    } catch (e) {
                        r = { error: text.trim() || "The SSH helper failed." };
                    }
                    if (proc.callback) proc.callback(r);
                    Qt.callLater(() => proc.destroy());
                }
            }
        }
    }
}
