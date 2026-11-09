import QtQuick

// The search field at the top of a module. Keys go to `keyHandler(event)` first; unhandled ones
// propagate up (Panel uses that for Alt+1/2/3).
Rectangle {
    id: box

    property alias text: input.text
    property string placeholder
    property string glyph: "⌕"
    property var keyHandler: null            // function(event) -> true when handled
    readonly property bool hasFocus: input.activeFocus

    function grab() { input.forceActiveFocus(); }

    implicitHeight: 40
    radius: 10
    color: Theme.raised
    border.width: 1
    border.color: input.activeFocus ? Theme.accentSoft : Theme.line

    Text {
        id: lens
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        text: box.glyph
        color: input.activeFocus ? Theme.accent : Theme.faint
        font { family: Theme.font; pixelSize: 17 }
    }
    TextInput {
        id: input
        anchors { left: lens.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        color: Theme.text
        selectionColor: Theme.accent
        font { family: Theme.font; pixelSize: 14 }
        clip: true

        Text {
            visible: !input.text
            text: box.placeholder
            color: Theme.faint
            font: input.font
        }

        Keys.onPressed: event => { if (box.keyHandler && box.keyHandler(event)) event.accepted = true; }
    }
}
