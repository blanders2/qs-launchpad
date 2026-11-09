pragma ComponentBehavior: Bound
import QtQuick

// Todo: your own checklist (PatchGoblin's Todo plugin, without project tags), plus recurring
// tasks that come back on their schedule.
ListModule {
    id: root

    property string editingId: ""
    property var addRule: null          // repeat rule new items get
    property int epoch: 0

    readonly property int recurringCount: Todo.items.filter(i => i.repeat).length
    readonly property int doneCount: Todo.items.filter(i => !i.repeat && i.done).length
    readonly property var all: {
        epoch;
        return Todo.items.map(i => ({
            kind: "todo", key: i.id, data: i, title: i.text, rule: Todo.describe(i.repeat),
            meta: i.repeat ? dueLabel(i.due) : ago(i.done ? i.done_at || i.created : i.created),
            overdue: !!i.repeat && i.due < Todo.today,
            hay: (i.text + " " + Todo.describe(i.repeat)).toLowerCase()
        }));
    }

    glyph: "todo"
    title: "Todo"
    subtitle: Todo.openCount + " open  ·  " + recurringCount + " recurring  ·  " + doneCount + " done"
    buttons: [{ glyph: "⌫", tip: "Clear done", run: () => root.clearDone() }]
    placeholder: "Search to-dos"
    tabNames: ["Open", "Recurring", "Done"]
    lists: [all.filter(i => Todo.isOpen(i.data)),
            all.filter(i => i.data.repeat).sort((a, b) => a.data.due < b.data.due ? -1 : a.data.due > b.data.due ? 1 : 0),
            all.filter(i => !i.data.repeat && i.data.done)].map(l => filter(l, query))
    hints: [
        "⏎ done   ^N add   ^E edit   ^R repeat   ^D delete   alt+↑↓ move",
        "⏎ done early   ^E edit   ^R change repeat   ^D delete",
        "⏎ reopen   ^E edit   ^D delete   ⌫ in header clears done"
    ]
    emptyTexts: ["Nothing to do.\nAdd a to-do above (^N).",
                 "No recurring tasks.\nUse ↻ on the add field, or ^R on a to-do.",
                 "Nothing done yet."]
    extra: addRow
    delegate: todoRow

    function open() {
        tab = 0;
        editingId = "";
        epoch++;
        grab(true);
    }

    function ago(seconds) {
        const s = Date.now() / 1000 - seconds;
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        if (s < 7 * 86400) return Math.floor(s / 86400) + "d";
        return Qt.formatDate(new Date(seconds * 1000), "MMM d");
    }
    function dueLabel(due) {
        const d = Todo.daysBetween(Todo.today, due);
        if (d < 0) return "overdue " + -d + "d";
        if (d === 0) return "today";
        if (d === 1) return "tomorrow";
        if (d < 7) return Todo.dayNames[Todo.parseYmd(due).getDay()];
        return Qt.formatDate(Todo.parseYmd(due), "MMM d");
    }

    function filter(items, q) {
        if (!q) return items;
        const words = q.split(/\s+/);
        return items.filter(i => words.every(w => i.hay.includes(w)));
    }

    function addItem(text) {
        const err = Todo.add(text, addRule);
        if (err) { toast(err, true); return false; }
        const item = Todo.items[0];
        if (item.repeat && item.due > Todo.today) {
            toast("“" + item.text.slice(0, 30) + "” is first due " + dueLabel(item.due) + ". It's under Recurring until then.");
            tab = 1;
        } else if (tab !== 0) {
            tab = 0;
        }
        keep(item.id, 0);
        return true;
    }
    function startEdit(item) { if (item) editingId = item.key; }
    function finishEdit(id, text) {
        const err = Todo.edit(id, text);
        if (err) { toast(err, true); return; }
        editingId = "";
        focusSearch();
    }
    function cancelEdit() {
        editingId = "";
        focusSearch();
    }
    function toggle(item) {
        if (!item) return;
        const at = listView.currentIndex;
        const next = Todo.toggle(item.key);
        if (next) toast("Done. “" + item.title.slice(0, 30) + "” is next due " + dueLabel(next) + ".");
        keep(item.key, at);
    }
    function remove(item) {
        if (!item) return;
        const at = listView.currentIndex;
        Todo.remove(item.key);
        keep("", at);
        toast("Deleted “" + item.title.slice(0, 40) + "”");
    }
    function move(item, by) {
        if (!item) return;
        Todo.move(item.key, by, items.map(i => i.key));
        keep(item.key);
    }
    function clearDone() {
        const n = doneCount;
        if (!n) { toast("Nothing done to clear."); return; }
        Todo.clearDone();
        toast("Cleared " + n + " done " + (n === 1 ? "item" : "items") + ".");
    }

    // Choose how an item repeats, or (item null) how new items will.
    function pickRepeat(item) {
        const rule = item ? item.data.repeat : addRule;
        const now = Todo.parseYmd(Todo.today);
        sheet.open({
            title: item ? "Repeat “" + item.title.slice(0, 40) + "”" : "Repeat new to-dos",
            submitLabel: "Set",
            fields: [
                { key: "every", label: "Repeats", kind: "choice", value: rule ? rule.every : "",
                  options: [{ value: "", label: "Doesn't repeat" }, { value: "day", label: "Daily" },
                            { value: "weekday", label: "Weekdays" }, { value: "week", label: "Weekly" },
                            { value: "month", label: "Monthly" }, { value: "days", label: "Every few days" }] },
                { key: "days", label: "On", kind: "multi", when: v => v.every === "week",
                  value: rule && rule.every === "week" ? rule.days : [now.getDay()],
                  options: [1, 2, 3, 4, 5, 6, 0].map(d => ({ value: d, label: Todo.dayNames[d] })) },
                { key: "date", label: "Day of the month", kind: "text", when: v => v.every === "month",
                  value: String(rule && rule.every === "month" ? rule.date : now.getDate()), placeholder: "1–31",
                  hint: "Months without that day use their last day." },
                { key: "n", label: "Every how many days", kind: "text", when: v => v.every === "days",
                  value: String(rule && rule.every === "days" ? rule.n : 2), placeholder: "2" },
                { kind: "note", when: v => !!v.every,
                  text: "It shows under Open from the day it's due, and stays until you tick it off. Ticking it schedules the next one." }
            ],
            submit: v => {
                let next = null;
                if (v.every) {
                    next = Todo.cleanRule({ every: v.every, days: v.days, date: v.date, n: v.n });
                    if (!next) {
                        sheet.error = v.every === "week" ? "Pick at least one day." : v.every === "month" ? "Enter a day from 1 to 31." : "Enter a number of days from 1 to 365.";
                        return;
                    }
                }
                sheet.close();
                if (!item) {
                    addRule = next;
                    extraItem.grab();
                    return;
                }
                Todo.setRepeat(item.key, next);
                keep(item.key);
                const saved = Todo.items.find(i => i.id === item.key);
                toast(next ? Todo.describe(next) + ", next due " + dueLabel(saved.due) + "." : "“" + item.title.slice(0, 30) + "” no longer repeats.");
            }
        });
    }

    onActivated: (item, alt, shell) => toggle(item)

    keyHandler: (event, cur) => {
        const ctrl = event.modifiers & Qt.ControlModifier, alt = event.modifiers & Qt.AltModifier;
        if (alt && event.key === Qt.Key_Down) move(cur, 1);
        else if (alt && event.key === Qt.Key_Up) move(cur, -1);
        else if (ctrl && event.key === Qt.Key_N) extraItem.grab();
        else if (ctrl && event.key === Qt.Key_E) startEdit(cur);
        else if (ctrl && event.key === Qt.Key_D) remove(cur);
        else if (ctrl && event.key === Qt.Key_R) pickRepeat(cur);
        else return false;
        return true;
    }

    Component {
        id: addRow
        Rectangle {
            id: box
            function grab() { input.forceActiveFocus(); }
            implicitHeight: 38
            radius: 10
            color: Theme.raised
            border.width: 1
            border.color: input.activeFocus ? Theme.accentSoft : Theme.line

            Text {
                id: plus
                anchors { left: parent.left; leftMargin: 13; verticalCenter: parent.verticalCenter }
                text: "+"
                color: input.activeFocus ? Theme.accent : Theme.faint
                font { family: Theme.font; pixelSize: 17 }
            }
            TextInput {
                id: input
                anchors { left: plus.right; leftMargin: 10; right: repeatChip.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                color: Theme.text
                selectionColor: Theme.accent
                font { family: Theme.font; pixelSize: 13 }
                clip: true
                maximumLength: Todo.maxText
                Text {
                    visible: !input.text
                    text: root.addRule ? "Add a recurring to-do…" : "Add a to-do…"
                    color: Theme.faint
                    font: input.font
                }
                Keys.onReturnPressed: if (root.addItem(input.text)) input.text = ""
                Keys.onEnterPressed: if (root.addItem(input.text)) input.text = ""
                Keys.onEscapePressed: { input.text = ""; root.focusSearch(); }
                Keys.onDownPressed: root.focusSearch()
            }
            Chip {
                id: repeatChip
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                label: root.addRule ? "↻ " + Todo.describe(root.addRule) : "↻ repeat"
                lit: !!root.addRule
                onClicked: root.pickRepeat(null)
            }
        }
    }

    Component {
        id: todoRow
        Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool current: ListView.isCurrentItem
            readonly property bool recurring: !!modelData.data.repeat
            readonly property bool done: modelData.data.done
            readonly property bool editing: root.editingId === modelData.key
            width: ListView.view.width
            implicitHeight: 44

            onEditingChanged: if (editing) Qt.callLater(() => { editor.text = row.modelData.title; editor.selectAll(); editor.forceActiveFocus(); })

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: row.current ? Theme.raised : "transparent"
                Rectangle {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 3
                    height: row.current ? 18 : 0
                    radius: 1.5
                    color: Theme.accent
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: row.ListView.view.currentIndex = row.index
                onClicked: mouse => mouse.button === Qt.RightButton ? root.pickRepeat(row.modelData) : null
                onDoubleClicked: root.startEdit(row.modelData)

                // Check circle
                Rectangle {
                    id: check
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    width: 18
                    height: 18
                    radius: 9
                    color: row.done ? Theme.accent : "transparent"
                    border.width: row.done ? 0 : 1.5
                    border.color: checkArea.containsMouse ? Theme.accent : row.modelData.overdue ? Theme.bad : Theme.faint
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Text {
                        anchors.centerIn: parent
                        visible: row.done || checkArea.containsMouse
                        text: "✓"
                        color: row.done ? "#1d1c1a" : Theme.accent
                        font { family: Theme.font; pixelSize: 12; weight: Font.Bold }
                    }
                    MouseArea {
                        id: checkArea
                        anchors { fill: parent; margins: -6 }
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggle(row.modelData)
                    }
                }

                Item {
                    id: body
                    anchors { left: check.right; leftMargin: 12; right: side.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    height: 28

                    // The text takes only what it needs, so the repeat tag sits right after it.
                    Text {
                        id: label
                        visible: !row.editing
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, body.width - (ruleTag.visible ? ruleTag.width + 8 : 0))
                        text: row.modelData.title
                        color: row.done ? Theme.faint : Theme.text
                        font { family: Theme.font; pixelSize: 13; strikeout: row.done }
                        elide: Text.ElideRight
                    }
                    // How it repeats
                    Rectangle {
                        id: ruleTag
                        visible: row.recurring && !row.editing
                        anchors { left: label.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                        width: Math.min(150, ruleText.implicitWidth + 12)
                        height: 18
                        radius: 5
                        color: Theme.accentSoft
                        Text {
                            id: ruleText
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
                            verticalAlignment: Text.AlignVCenter
                            text: "↻ " + row.modelData.rule
                            color: Theme.accent
                            elide: Text.ElideRight
                            font { family: Theme.font; pixelSize: 10 }
                        }
                    }
                    Rectangle {
                        visible: row.editing
                        anchors.fill: parent
                        radius: 6
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.accentSoft
                        TextInput {
                            id: editor
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            selectionColor: Theme.accent
                            font { family: Theme.font; pixelSize: 13 }
                            clip: true
                            maximumLength: Todo.maxText
                            Keys.onReturnPressed: root.finishEdit(row.modelData.key, editor.text)
                            Keys.onEnterPressed: root.finishEdit(row.modelData.key, editor.text)
                            Keys.onEscapePressed: root.cancelEdit()
                            onActiveFocusChanged: if (!activeFocus && row.editing) root.cancelEdit()
                        }
                    }
                }

                Item {
                    id: side
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: chips.visible ? chips.width : meta.implicitWidth
                    height: parent.height
                    Text {
                        id: meta
                        visible: !chips.visible
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: row.modelData.meta
                        color: row.modelData.overdue ? Theme.bad : Theme.faint
                        font { family: Theme.font; pixelSize: 11 }
                    }
                    Row {
                        id: chips
                        visible: area.containsMouse && !row.editing
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Chip { label: "edit"; onClicked: root.startEdit(row.modelData) }
                        Chip { label: "repeat"; lit: row.recurring; onClicked: root.pickRepeat(row.modelData) }
                        Chip { label: "✕"; onClicked: root.remove(row.modelData) }
                    }
                }
            }
        }
    }
}
