pragma ComponentBehavior: Bound
import QtQuick

// Tabs with counts and a sliding accent underline.
Item {
    id: strip

    property var names: []
    property var counts: []
    property int current: 0
    signal picked(int index)

    implicitHeight: 30

    Row {
        spacing: 4
        Repeater {
            id: tabs
            model: strip.names
            delegate: Item {
                id: tab
                required property string modelData
                required property int index
                readonly property bool active: strip.current === index
                width: label.implicitWidth + 22
                height: 30

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: tab.modelData + (strip.counts[tab.index] !== undefined ? "  " + strip.counts[tab.index] : "")
                    color: tab.active ? Theme.text : area.containsMouse ? Theme.dim : Theme.faint
                    font { family: Theme.font; pixelSize: 13; weight: tab.active ? Font.DemiBold : Font.Normal }
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: strip.picked(tab.index)
                }
            }
        }
    }
    Rectangle {
        readonly property Item at: tabs.itemAt(strip.current)
        x: at ? at.x + 8 : 0
        width: at ? at.width - 16 : 0
        anchors.bottom: parent.bottom
        height: 2
        radius: 1
        color: Theme.accent
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.line; z: -1 }
}
