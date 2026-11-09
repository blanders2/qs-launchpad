pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Grok Bot: your bots, read from the app's own cached roster (bin/grok-roster), and the app's
// grokbot:// links (authority "app"):
//   /v1/agent?id=…   /v1/prompt?id=…&text=…   /v1/open   /v1/messages
//   /v1/marketplace?tab=bots|plugins   /v1/create-team-bot
// The prompt link only fills in the bot's message box; you still press send in Grok Bot.
// The roster only changes while Grok Bot is running. When a bot gets new messages or starts
// waiting on you, this sends a desktop notification, unless Grok Bot already notifies for that
// bot itself. Config "grokNotifications": false turns that off.
Singleton {
    id: root

    property var bots: []               // [{id, name, description, color, unread, waiting, activity, hidden, group, notify, preview}]
    property var seen: null             // id → {unread, waiting} from the last read, to spot what's new
    property string selected: ""        // the bot Grok Bot last had open
    property string error: ""
    readonly property bool loading: roster.running
    readonly property int unread: bots.reduce((n, b) => n + b.unread, 0)

    // Grok Bot's avatar colour names, in the dock's palette.
    readonly property var colors: ({ red: "#e0685e", orange: "#d97757", yellow: "#d9b557", green: "#7fb069",
                                     cyan: "#5eb1bf", blue: "#6f8fd9", purple: "#a07cc9", pink: "#d47ba8",
                                     black: "#a59e94", gray: "#a59e94", grey: "#a59e94" })
    function colorFor(b) { return colors[b.color] || Theme.tint(b.name); }

    function refresh() { if (!roster.running) roster.running = true; }

    function link(route, params) {
        const q = Object.keys(params || {}).filter(k => params[k] !== undefined && params[k] !== "")
            .map(k => k + "=" + encodeURIComponent(params[k])).join("&");
        return "grokbot://app/v1/" + route + (q ? "?" + q : "");
    }
    function go(route, params) {
        Claude.run(["xdg-open", link(route, params)], Claude.home);
        Claude.close();
    }
    function openBot(bot) { go("agent", { id: bot.id }); }
    // Send `text` to a bot (or, with no bot, to Grok Bot's default). Returns an error or "".
    function ask(bot, text) {
        text = String(text || "").trim();
        if (!text) return "Type something to ask.";
        if (text.length > 1000) return "Grok Bot takes up to 1000 characters in a link.";
        go("prompt", { id: bot ? bot.id : "", text: text });
        return "";
    }

    Process {
        id: roster
        command: ["python3", Quickshell.shellPath("bin/grok-roster")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.error = d.error || "";
                    if (!d.error) {
                        root.notifyChanges(d.bots);
                        root.bots = d.bots;
                        root.selected = d.selected || "";
                    }
                } catch (e) {
                    root.error = "Couldn't read Grok Bot's bot list.";
                }
            }
        }
    }

    function notifyChanges(next) {
        const before = seen;
        const now = {};
        next.forEach(b => now[b.id] = { unread: b.unread, waiting: b.waiting });
        seen = now;
        if (!before || Claude.cfg.grokNotifications === false) return;     // the first read only sets the baseline
        for (const b of next) {
            const was = before[b.id] || { unread: 0, waiting: false };
            if (b.notify || b.hidden) continue;
            if (b.waiting && !was.waiting) notify(b, "Needs you" + (b.preview ? ": " + b.preview : ""));
            else if (b.unread > was.unread) notify(b, (b.unread - was.unread === 1 ? "New message" : (b.unread - was.unread) + " new messages") + (b.preview ? ": " + b.preview : ""));
        }
    }
    // A desktop notification; clicking it (its "default" action) opens the bot.
    function notify(b, body) {
        const proc = notifier.createObject(root, {
            command: ["python3", Quickshell.shellPath("bin/notify"), "--app", "Grok Bot", "--icon", "grok-bot", "--action", "default=Open", b.name, body],
            bot: b
        });
        proc.running = true;
    }

    // Keep unread counts fresh (and notifications flowing) even while the dock is closed.
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component {
        id: notifier
        Process {
            id: note
            property var bot: null
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim() === "default" && note.bot) root.openBot(note.bot);
                    Qt.callLater(() => note.destroy());
                }
            }
        }
    }
    Component.onCompleted: refresh()
}
