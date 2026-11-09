pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// The frame every module shares: header, search, tabs, an optional extra row (`extra`), the list,
// a Sheet over the list for forms, and a hint line that briefly turns into a toast.
// A module supplies `lists` (one array of items per tab) and reacts to `activated`.
Item {
    id: mod

    property string glyph
    property string title
    property string subtitle
    property var buttons: []
    property string placeholder
    property bool searchable: true      // false hides the search field; keys still work
    property var tabNames: []
    property var lists: []
    property int tab: 0
    property var hints: []
    property var emptyTexts: []         // per tab, shown when the tab is empty and nothing is typed
    property Component delegate: defaultRow
    property Component extra: null      // a row between the tabs and the list
    property var keyHandler: null            // function(event, currentItem) -> true when handled
    property bool animateIn: false
    property string toastText: ""
    property bool toastBad: false

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var items: lists[tab] || []
    readonly property var current: items[list.currentIndex]
    readonly property alias sheet: sheetItem
    readonly property alias listView: list
    readonly property alias extraItem: extraLoader.item
    property alias searchText: search.text

    signal activated(var item, bool alt, bool shell)
    signal pinToggled(var item)

    // Called whenever the module is shown. `reset` clears the search and replays the entrance.
    function grab(reset) {
        if (reset) {
            search.text = "";
            sheetItem.close();
            animateIn = true;
            settle.restart();
            list.currentIndex = 0;
            list.positionViewAtBeginning();
        }
        focusSearch();
    }
    function focusSearch() {
        if (sheetItem.shown) return;
        searchable ? search.grab() : keyCatcher.forceActiveFocus();
    }
    function setTab(t) {
        tab = (t + tabNames.length) % tabNames.length;
        list.currentIndex = 0;
    }
    // After the lists change, put the cursor back on the item with this key (or near where it was).
    function keep(key, fallbackIndex) {
        Qt.callLater(() => {
            const i = mod.items.findIndex(x => x.key === key);
            list.currentIndex = i >= 0 ? i : Math.max(0, Math.min(fallbackIndex ?? list.currentIndex, mod.items.length - 1));
        });
    }
    function toast(text, bad) {
        toastText = text;
        toastBad = !!bad;
        toastTimer.restart();
    }

    function handleKey(event) {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (keyHandler && keyHandler(event, current)) return true;
        if (event.modifiers & Qt.AltModifier) return false;
        if (event.key === Qt.Key_Down) list.incrementCurrentIndex();
        else if (event.key === Qt.Key_Up) list.decrementCurrentIndex();
        else if (event.key === Qt.Key_PageDown) list.currentIndex = Math.min(items.length - 1, list.currentIndex + 8);
        else if (event.key === Qt.Key_PageUp) list.currentIndex = Math.max(0, list.currentIndex - 8);
        else if (event.key === Qt.Key_Tab && tabNames.length > 1) setTab(tab + 1);
        else if (event.key === Qt.Key_Backtab && tabNames.length > 1) setTab(tab - 1);
        else if (ctrl && event.key >= Qt.Key_1 && event.key < Qt.Key_1 + tabNames.length) setTab(event.key - Qt.Key_1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (current) activated(current, !!(event.modifiers & Qt.ShiftModifier), !!ctrl);
        }
        else if (event.key === Qt.Key_Escape) search.text ? search.text = "" : Claude.close();
        else return false;
        return true;
    }

    // While searching, hop to the first tab that has something if this one has nothing.
    onQueryChanged: {
        list.currentIndex = 0;
        if (query && items.length === 0) {
            const t = lists.findIndex(l => l.length > 0);
            if (t >= 0) tab = t;
        }
    }

    Timer { id: settle; interval: 700; onTriggered: mod.animateIn = false }

    // Takes the keys when there's no search field.
    Item {
        id: keyCatcher
        Keys.onPressed: event => { if (mod.handleKey(event)) event.accepted = true; }
    }
    Timer { id: toastTimer; interval: 5000; onTriggered: mod.toastText = "" }

    Component {
        id: defaultRow
        ResultRow {
            width: ListView.view.width
            current: ListView.isCurrentItem
            onActivated: (alt, shell) => mod.activated(modelData, alt, shell)
            onPinToggled: mod.pinToggled(modelData)
            onHovered: ListView.view.currentIndex = index
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: 18; bottomMargin: 12 }
        spacing: 12

        ModuleHeader {
            Layout.fillWidth: true
            glyph: mod.glyph
            title: mod.title
            subtitle: mod.subtitle
            buttons: mod.buttons
        }

        SearchBox {
            id: search
            visible: mod.searchable
            Layout.fillWidth: true
            placeholder: mod.placeholder
            keyHandler: event => mod.handleKey(event)
        }

        TabStrip {
            visible: mod.tabNames.length > 1
            Layout.fillWidth: true
            names: mod.tabNames
            counts: mod.lists.map(l => l.filter(i => i.kind !== "add").length)
            current: mod.tab
            onPicked: index => { mod.setTab(index); mod.focusSearch(); }
        }

        Loader {
            id: extraLoader
            Layout.fillWidth: true
            active: mod.extra !== null
            visible: active
            sourceComponent: mod.extra
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: list
                anchors.fill: parent
                clip: true
                spacing: 2
                model: mod.items
                currentIndex: 0
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                delegate: mod.delegate

                populate: Transition {
                    id: pop
                    enabled: mod.animateIn
                    SequentialAnimation {
                        PropertyAction { property: "opacity"; value: 0 }
                        PauseAnimation { duration: 180 + Math.min(pop.ViewTransition.index, 12) * 28 }
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "x"; from: 18; to: 0; duration: 320; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    lineHeight: 1.3
                    text: mod.query ? "Nothing matches “" + search.text.trim() + "”" : mod.emptyTexts[mod.tab] || "Nothing here yet"
                    color: Theme.faint
                    font { family: Theme.font; pixelSize: 13 }
                }
            }

            Sheet {
                id: sheetItem
                width: parent.width
                height: parent.height
                onClosed: mod.focusSearch()
            }
        }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: mod.toastText || mod.hints[mod.tab] || ""
            color: mod.toastText ? (mod.toastBad ? Theme.bad : Theme.good) : Theme.faint
            font { family: Theme.font; pixelSize: 11 }
            elide: Text.ElideRight
        }
    }
}
