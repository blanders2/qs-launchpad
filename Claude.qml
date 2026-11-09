pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared state: config, the project/session index, open/closed, and launch actions.
Singleton {
    id: root

    property bool open: false
    // Resting on a dock icon peeks the panel open on that module, and it closes when the pointer
    // leaves. A click holds it open (`held`) until you click outside it, press Esc or launch something.
    property bool held: false
    property bool sliverHot: false
    property bool panelHot: false
    property int rollover: -1            // the dock icon under the pointer, -1 for none
    property double lastRefresh: 0
    onSliverHotChanged: hoverChanged()
    onPanelHotChanged: hoverChanged()
    onRolloverChanged: rollover >= 0 && cfg.hoverOpen ? dwellTimer.restart() : dwellTimer.stop()
    property int module: 0               // which panel module shows (an index into moduleNames)
    readonly property var moduleNames: ["claude", "ssh", "todo", "bookmarks", "grok", "tailscale"]
    function showModule(name) {
        const i = moduleNames.indexOf(String(name).toLowerCase());
        if (i >= 0) module = i;
        show();
    }
    property alias cfg: adapter
    // Local and SSH-host results arrive separately (hosts are slower); each item has `host` ("" = here).
    property var localProjects: []
    property var localSessions: []
    property var remoteProjects: []
    property var remoteSessions: []
    property var hosts: []               // [{name, host, online, error}]
    readonly property var projects: localProjects.concat(remoteProjects).sort((a, b) => b.time - a.time)
    readonly property var sessions: localSessions.concat(remoteSessions).sort((a, b) => b.time - a.time)
    readonly property bool loading: indexer.running || remoteIndexer.running
    readonly property string home: Quickshell.env("HOME")

    // Pins are keys like "p:<host>:<path>" or "s:<host>:<session id>" (host "" = this machine),
    // kept in pins.json in the order they were pinned.
    property var pins: []
    property var pinWrites: []           // recent texts we wrote, so the file watcher doesn't reload our own writes
    function pinKey(d) { return d.id ? "s:" + (d.host || "") + ":" + d.id : "p:" + (d.host || "") + ":" + d.path; }
    function isPinned(d) { return pins.indexOf(pinKey(d)) >= 0; }
    function togglePin(d) {
        const k = pinKey(d);
        savePins(isPinned(d) ? pins.filter(p => p !== k) : pins.concat([k]));
    }
    function movePin(d, by) {
        const i = pins.indexOf(pinKey(d)), j = i + by;
        if (i < 0 || j < 0 || j >= pins.length) return;
        const next = pins.slice();
        next.splice(j, 0, next.splice(i, 1)[0]);
        savePins(next);
    }
    function savePins(next) {
        pins = next;
        const text = JSON.stringify({ pins: next }, null, 4) + "\n";
        pinWrites = pinWrites.concat([text]).slice(-8);
        pinFile.setText(text);
    }

    function hoverChanged() {
        if (!sliverHot) rollover = -1;
        if (open) sliverHot || panelHot ? leaveTimer.stop() : leaveTimer.restart();
    }
    function peek() {
        if (open) return;
        // Brushing the edge shouldn't mean an ssh to every host each time.
        if (Date.now() - lastRefresh > 30000) refresh();
        held = false;
        open = true;
    }
    function hold() { held = true; leaveTimer.stop(); }
    function toggle() { open && held ? close() : show(); }
    function show() { refresh(); held = true; open = true; }
    function close() {
        open = false;
        held = false;
        dwellTimer.stop();
        leaveTimer.stop();
    }
    function refresh() {
        lastRefresh = Date.now();
        if (!indexer.running) indexer.running = true;
        if (!remoteIndexer.running) remoteIndexer.running = true;
    }

    function expand(p) { return p === "~" || p.startsWith("~/") ? home + p.slice(1) : p; }
    // Fill {cwd} {host} {name} {color} placeholders in a configured command.
    function fill(args, vars) {
        return args.map(a => expand(a.replace(/\{(cwd|host|name|color)\}/g, (m, k) => vars[k] || "")));
    }
    function quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }
    function basename(p) { return p.split("/").filter(Boolean).pop() || "/"; }

    // Start each launch in its own systemd scope so it outlives (and can't take down) the shell.
    function run(command, cwd) {
        const name = command[0].split("/").pop().replace(/[^A-Za-z0-9:_.]/g, "_");
        Quickshell.execDetached({
            command: ["systemd-run", "--user", "--scope", "--quiet", "--collect", "--slice=app.slice",
                      "--unit=app-qs-launchpad-" + name + "-" + Date.now() + ".scope", "--"].concat(command),
            workingDirectory: cwd || home
        });
    }

    // A TerminalGoblin tab (cfg.terminal) in `cwd`, here or on `host`, with a shell, or running
    // `command` (an argv) when given. On a host it's `ssh -t` into a login shell there, which is
    // also what puts ~/.local/bin on PATH for commands like claude. An empty cwd on a host means
    // its home folder.
    function terminal(cwd, host, title, command) {
        const vars = { cwd: host ? home : cwd, host: host, name: title, color: Theme.tint(cwd ? basename(cwd) : title) };
        let argv = command;
        if (host && !cwd && !command)
            argv = ["ssh", "-t", "--", host];
        else if (host)
            argv = ["ssh", "-t", "--", host, (cwd ? "cd " + quote(cwd) + " && " : "") + "exec "
                    + (command ? "\"$SHELL\" -lc " + quote(command.map(quote).join(" ")) : "$SHELL -l")];
        run(fill(cfg.terminal, vars).concat(argv ? ["-e"].concat(argv) : []), vars.cwd);
    }
    // A shell in a project's or session's folder.
    function openTerminal(d) {
        const cwd = d.path || d.cwd;
        terminal(cwd, d.host, (d.host ? d.hostName + ": " : "") + (d.name || basename(cwd)));
        close();
    }

    // Claude sessions open in the Claude desktop app through its claude:// links.
    function openUrl(url) { run(["xdg-open", url], home); }
    function claudeUrl(route, params) {
        return "claude://" + route + "?" + Object.keys(params).map(k => k + "=" + encodeURIComponent(params[k])).join("&");
    }

    function newBlankSession() { openUrl("claude://code/new"); close(); }
    function newSession(p) {
        openUrl(claudeUrl("code/new", p.host ? { ssh_host: p.host, ssh_folder: p.path } : { folder: p.path }));
        close();
    }
    function continueSession(p) {
        const last = sessions.find(s => s.cwd === p.path && s.host === p.host);
        last ? resume(last) : newSession(p);
    }
    function resume(s) {
        // The app opens its own sessions by its id; a terminal-only local session it imports
        // first. A terminal-only session on an SSH host it can't open, so that one resumes in a terminal.
        if (s.desktopId) openUrl(claudeUrl("code/continue", { session: s.desktopId }));
        else if (!s.host) openUrl(claudeUrl("resume", { session: s.id }));
        else terminal(s.cwd, s.host, s.title, cfg.claude.concat(["--resume", s.id]));
        close();
    }
    function openEditor(p) {
        run(fill(p.host ? cfg.remoteEditor : cfg.editor, { cwd: p.path, host: p.host }), p.host ? home : p.path);
        close();
    }
    function openFiles(p) {
        run(fill(p.host ? cfg.remoteFileManager : cfg.fileManager, { cwd: p.path, host: p.host }), p.host ? home : p.path);
        close();
    }

    // A link is one of: {url}, {command: [...]}, or {terminal: [...]} — each with optional cwd.
    function openLink(l) {
        const cwd = expand(l.cwd || "~");
        if (l.url) run(["xdg-open", l.url], cwd);
        else if (l.terminal) terminal(cwd, "", l.name, fill([].concat(l.terminal), { cwd: cwd }));
        else if (l.command) run(fill([].concat(l.command), { cwd: cwd }), cwd);
        else return;
        close();
    }

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: { reload(); root.refresh(); }
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: adapter
            property var terminal: ["terminalgoblin", "--cwd", "{cwd}", "--title", "{name}", "--color", "{color}"]
            property var claude: ["claude"]
            property var editor: ["code", "{cwd}"]
            property var fileManager: ["dolphin", "{cwd}"]
            property var remoteEditor: ["code", "--remote", "ssh-remote+{host}", "{cwd}"]
            property var remoteFileManager: ["dolphin", "sftp://{host}{cwd}"]
            property string chromeProfile: "~/.config/google-chrome/Default"
            property bool grokNotifications: true
            property var remotes: "auto"         // "auto" = the Claude desktop app's SSH hosts
            property bool showArchived: false
            property var projectRoots: ["~/Projects"]
            property var extraProjects: []
            property var hideProjects: []
            property bool showSdkSessions: false
            property int maxSessions: 200
            property string screen: ""
            property real sliverPosition: 0.5      // 0 = top of the screen, 1 = bottom
            property int sliverLength: 120
            property int panelWidth: 512
            property int panelHeight: 720
            property bool hoverOpen: true          // false = only a click opens the panel
            property int hoverDelay: 150           // ms on a dock icon before it takes effect
            property var links: []
        }
    }

    // pins.json is also hand-editable; outside edits are picked up live.
    FileView {
        id: pinFile
        path: Quickshell.shellPath("pins.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            if (root.pinWrites.indexOf(t) >= 0) return;
            try {
                const p = JSON.parse(t).pins;
                if (Array.isArray(p)) root.pins = p.filter(k => typeof k === "string");
            } catch (e) {
                console.warn("qs-launchpad: pins.json is not valid JSON:", e);
            }
        }
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) root.savePins([]); }
    }

    Process {
        id: indexer
        command: ["python3", Quickshell.shellPath("bin/claude-index"), Quickshell.shellPath("config.json")]
        property string last: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === indexer.last) return;      // unchanged: keep the lists (and any scroll) as they are
                try {
                    const d = JSON.parse(text);
                    root.localProjects = d.projects;
                    root.localSessions = d.sessions;
                    indexer.last = text;
                } catch (e) {
                    console.warn("qs-launchpad: bad index output:", e);
                }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text) console.warn("claude-index:", text) }
    }

    Process {
        id: remoteIndexer
        command: ["python3", Quickshell.shellPath("bin/claude-index"), "--remotes", Quickshell.shellPath("config.json")]
        property string last: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === remoteIndexer.last) return;
                try {
                    const d = JSON.parse(text);
                    root.remoteProjects = d.projects;
                    root.remoteSessions = d.sessions;
                    root.hosts = d.hosts;
                    remoteIndexer.last = text;
                } catch (e) {
                    console.warn("qs-launchpad: bad remote index output:", e);
                }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text) console.warn("claude-index --remotes:", text) }
    }

    // Keep the local list warm; SSH hosts are only asked when the launcher opens.
    Timer {
        id: dwellTimer
        interval: root.cfg.hoverDelay
        onTriggered: {
            root.module = root.rollover;
            root.peek();
        }
    }
    Timer { id: leaveTimer; interval: 350; onTriggered: if (!root.held && !root.sliverHot && !root.panelHot) root.close() }
    Timer { interval: 120000; running: true; repeat: true; onTriggered: if (!indexer.running) indexer.running = true }
    Component.onCompleted: refresh()
}
