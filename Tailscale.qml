pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale: this device and its peers from `tailscale status --json`, plus ping, connect /
// disconnect and exit nodes through the `tailscale` CLI. Changing settings needs root unless
// your user is Tailscale's operator (`sudo tailscale set --operator=$USER`, run once by you).
Singleton {
    id: root

    property var status: null           // the parsed `tailscale status --json`
    property string error: ""
    property var pings: ({})            // peer id → "9 ms direct" / "timed out" …
    property var busy: ({})             // peer id → true while pinging
    readonly property bool running: status !== null && status.BackendState === "Running"
    readonly property string state: status ? status.BackendState : ""
    readonly property var me: status ? status.Self : null
    readonly property string tailnet: status && status.CurrentTailnet ? status.CurrentTailnet.Name : ""
    readonly property string suffix: status && status.CurrentTailnet ? status.CurrentTailnet.MagicDNSSuffix : ""
    readonly property var peers: {
        if (!status || !status.Peer) return [];
        return Object.keys(status.Peer).map(k => status.Peer[k])
            .sort((a, b) => (b.Online - a.Online) || a.HostName.localeCompare(b.HostName));
    }
    readonly property int onlineCount: peers.filter(p => p.Online).length
    readonly property var exitNode: peers.find(p => p.ExitNode) || null
    readonly property string operatorFix: "sudo tailscale set --operator=$USER"

    function dnsName(p) { return String(p.DNSName || "").replace(/\.$/, ""); }
    function shortName(p) { return dnsName(p).split(".")[0] || p.HostName; }
    function ipv4(p) { return (p.TailscaleIPs || []).find(ip => ip.indexOf(":") < 0) || ""; }

    // Run `tailscale args…`; `callback({code, out, err})`.
    function call(args, callback) {
        const proc = job.createObject(root, { command: ["tailscale"].concat(args), callback: callback || null });
        proc.running = true;
    }
    // A short, human reason for a failed command, pointing at the operator fix when that's the cause.
    function why(r) {
        const text = (r.err || r.out || "").trim();
        if (/access denied|permission denied|must be root|operator/i.test(text))
            return "Tailscale needs root for that. Run once: " + operatorFix;
        return text.split("\n").pop() || "tailscale exited with " + r.code;
    }

    function refresh() {
        call(["status", "--json"], r => {
            try {
                status = JSON.parse(r.out);
                error = "";
            } catch (e) {
                status = null;
                error = why(r) || "Can't reach tailscaled.";
            }
        });
    }
    function set(map, key, value) { const m = Object.assign({}, map); if (value === undefined) delete m[key]; else m[key] = value; return m; }
    function ping(p, done) {
        busy = set(busy, p.ID, true);
        call(["ping", "--c", "1", "--timeout", "3s", ipv4(p)], r => {
            busy = set(busy, p.ID, undefined);
            const m = r.out.match(/pong from .* via (\S+) in (\S+)/);
            const result = m ? m[2] + (/^DERP/i.test(m[1]) ? " via relay" : " direct") : /timed out|no reply/i.test(r.out + r.err) ? "no answer" : why(r);
            pings = set(pings, p.ID, result);
            if (done) done(m ? "" : result, result);
        });
    }
    function connect(on, done) { call([on ? "up" : "down"], r => { refresh(); done(r.code ? why(r) : ""); }); }
    function useExitNode(p, done) { call(["set", "--exit-node=" + (p ? ipv4(p) : "")], r => { refresh(); done(r.code ? why(r) : ""); }); }

    function copy(text) { Claude.run(["wl-copy", "--", text], Claude.home); }
    // SSH there, as the user your SSH setup already uses for that machine (e.g. user@myhost), if any.
    function sshTarget(p) {
        const names = [shortName(p), dnsName(p), ipv4(p), p.HostName.toLowerCase()];
        const known = Ssh.hosts.find(h => names.indexOf(h.hostname) >= 0 || names.indexOf(h.name) >= 0);
        return known ? known.target : shortName(p);
    }
    function ssh(p) { Claude.terminal("", sshTarget(p), p.HostName); Claude.close(); }
    function web(p) { Claude.run(["xdg-open", "http://" + dnsName(p) + "/"], Claude.home); Claude.close(); }

    Timer {
        interval: Claude.open ? 10000 : 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component {
        id: job
        Process {
            id: proc
            property var callback: null
            property int code: 0
            property int pending: 3         // stdout, stderr and exit all have to arrive
            function finish() {
                if (--pending > 0) return;
                if (callback) callback({ code: code, out: out.text, err: err.text });
                Qt.callLater(() => proc.destroy());
            }
            stdout: StdioCollector { id: out; onStreamFinished: proc.finish() }
            stderr: StdioCollector { id: err; onStreamFinished: proc.finish() }
            onExited: (exitCode, exitStatus) => { code = exitCode; finish(); }
        }
    }
}
