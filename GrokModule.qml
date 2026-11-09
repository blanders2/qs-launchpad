pragma ComponentBehavior: Bound
import QtQuick

// Grok Bots: your bots, straight from the Grok Bot app, opened or asked something directly,
// plus shortcuts into the app.
ListModule {
    id: root

    property string askId: ""           // which bot the Ask field talks to ("" = the one Grok Bot last had open)
    readonly property var askBot: Grok.bots.find(b => b.id === askId) || Grok.bots.find(b => b.id === Grok.selected) || Grok.bots[0] || null

    glyph: "grok"
    title: "Grok Bots"
    subtitle: Grok.error ? "Grok Bot" : Grok.bots.length + (Grok.bots.length === 1 ? " bot" : " bots")
        + (Grok.unread ? "  ·  " + Grok.unread + " unread" : "")
    buttons: [{ glyph: "↻", tip: "Refresh", run: () => Grok.refresh() }]
    searchable: false
    tabNames: ["Bots", "App"]
    lists: [botItems(), appItems()]
    hints: [
        "⏎ open in Grok Bot   ^N write to this bot   ↑↓ move   ⇥ switch",
        "⏎ open   ↑↓ move   ⇥ switch"
    ]
    emptyTexts: [Grok.error || (Grok.loading ? "Reading your bots…" : "No bots yet. Make one in Grok Bot."), ""]
    extra: tab === 0 ? askRow : null

    function open() {
        tab = 0;
        Grok.refresh();
        grab(true);
    }

    function ago(ms) {
        const s = (Date.now() - ms) / 1000;
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        if (s < 7 * 86400) return Math.floor(s / 86400) + "d";
        return Qt.formatDate(new Date(ms), "MMM d");
    }

    function botItems() {
        return Grok.bots.map(b => ({
            kind: "bot", key: b.id, data: b, glyph: b.name.charAt(0).toUpperCase(), tint: Grok.colorFor(b),
            title: b.name, subtitle: b.description || (b.group ? "Group" : "No description"),
            meta: b.waiting ? "needs you" : b.activity ? ago(b.activity) : "", status: b.waiting ? "busy" : "",
            badge: b.unread ? String(b.unread) : "", dim: b.hidden,
            actions: [{ label: "write", run: () => root.askWith(b) }]
        }));
    }
    function appItems() {
        const row = (key, title, subtitle, route, params) => ({ kind: "app", key: key, glyph: "grok-bot", tint: Theme.accent,
                                                              title: title, subtitle: subtitle, route: route, params: params, actions: [] });
        return [row("open", "Open Grok Bot", "The app's main window", "open"),
                row("messages", "Messages", "Your conversations", "messages"),
                row("bots", "Bot marketplace", "Find bots to add", "marketplace", { tab: "bots" }),
                row("plugins", "Plugin marketplace", "Plugins for your bots", "marketplace", { tab: "plugins" }),
                row("team", "New team bot", "Create a bot for your team", "create-team-bot")];
    }

    function askWith(b) {
        askId = b.id;
        extraItem.grab();
    }
    function sendAsk(text) {
        const err = Grok.ask(askBot, text);
        if (err) { toast(err, true); return false; }
        return true;
    }

    onActivated: (item, alt, shell) => {
        if (!item) return;
        if (item.kind === "bot") Grok.openBot(item.data);
        else if (item.kind === "app") Grok.go(item.route, item.params);
    }

    keyHandler: (event, cur) => {
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_N && tab === 0) {
            cur && cur.kind === "bot" ? askWith(cur.data) : extraItem.grab();
            return true;
        }
        return false;
    }

    // On the Bots tab: ask a bot something, straight into Grok Bot.
    Component {
        id: askRow
        Rectangle {
            function grab() { input.forceActiveFocus(); }
            implicitHeight: 38
            radius: 10
            color: Theme.raised
            border.width: 1
            border.color: input.activeFocus ? Theme.accentSoft : Theme.line

            Text {
                id: mark
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                text: "✦"
                color: input.activeFocus ? Theme.accent : Theme.faint
                font { family: Theme.font; pixelSize: 15 }
            }
            TextInput {
                id: input
                anchors { left: mark.right; leftMargin: 10; right: botChip.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                color: Theme.text
                selectionColor: Theme.accent
                font { family: Theme.font; pixelSize: 13 }
                clip: true
                maximumLength: 1000
                Text {
                    visible: !input.text
                    text: (root.askBot ? "Message " + root.askBot.name : "Message Grok Bot") + " (you press send in Grok Bot)…"
                    color: Theme.faint
                    font: input.font
                }
                Keys.onReturnPressed: if (root.sendAsk(input.text)) input.text = ""
                Keys.onEnterPressed: if (root.sendAsk(input.text)) input.text = ""
                Keys.onEscapePressed: { input.text = ""; root.focusSearch(); }
                Keys.onDownPressed: root.focusSearch()
            }
            // Click to cycle which bot you're asking.
            Chip {
                id: botChip
                visible: Grok.bots.length > 0
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                label: "▸ " + (root.askBot ? root.askBot.name : "")
                lit: true
                onClicked: {
                    const i = Grok.bots.findIndex(b => b.id === (root.askBot && root.askBot.id));
                    root.askId = Grok.bots[(i + 1) % Grok.bots.length].id;
                }
            }
        }
    }
}
