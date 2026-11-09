pragma ComponentBehavior: Bound
import QtQuick

// The module icons in the dock: one per module, with an optional badge. Each icon's hit area
// runs the dock's full height, so it reaches the screen edge.
Row {
    id: rail

    property var entries: []            // [{glyph, name, badge}]
    property int current: -1            // the highlighted module, -1 for none
    signal picked(int index)
    property real reach: 0              // how far above the dock the selected icon's glow rises
    signal rolled(int index)            // the pointer moved onto an icon

    readonly property int cell: 38
    function centerOf(i) { return i * (cell + spacing) + cell / 2; }

    spacing: 2

    Repeater {
        model: rail.entries
        delegate: Item {
            id: entry
            required property var modelData
            required property int index
            readonly property bool active: rail.current === index
            width: rail.cell
            height: 36

            Rectangle {
                anchors.centerIn: parent
                width: 34
                height: 30
                radius: 9
                color: area.containsMouse && !entry.active ? Theme.hover : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            // Rises out of the dock and fades into the menu, so the menu reads as coming from here.
            Rectangle {
                anchors { bottom: parent.bottom; bottomMargin: 3; horizontalCenter: parent.horizontalCenter }
                width: 34
                height: 33 + rail.reach
                radius: 9
                opacity: entry.active ? 1 : 0
                gradient: Gradient {
                    GradientStop { position: 0; color: "#00d97757" }
                    GradientStop { position: 1; color: "#59d97757" }
                }
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            Rectangle {
                anchors { bottom: parent.bottom; bottomMargin: 1; horizontalCenter: parent.horizontalCenter }
                width: entry.active ? 18 : 0
                height: 2
                radius: 1
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
            ModuleIcon {
                anchors.centerIn: parent
                glyph: entry.modelData.glyph
                color: entry.active ? Theme.accent : area.containsMouse ? Theme.text : Theme.dim
            }
            Rectangle {
                visible: !!entry.modelData.badge
                anchors { right: parent.right; top: parent.top; topMargin: 1 }
                width: Math.max(13, badgeText.implicitWidth + 6)
                height: 13
                radius: 6.5
                color: Theme.accent
                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: entry.modelData.badge || ""
                    color: "#1d1c1a"
                    font { family: Theme.font; pixelSize: 9; weight: Font.DemiBold }
                }
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) rail.rolled(entry.index)
                onClicked: rail.picked(entry.index)
            }
        }
    }
}
