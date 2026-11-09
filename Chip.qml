import QtQuick

// A small text button, used for row actions and choice fields.
Rectangle {
    id: chip

    property string label
    property bool lit: false
    signal clicked()

    width: chipText.implicitWidth + 14
    height: 22
    radius: 6
    color: chipArea.containsMouse ? Theme.accentSoft : lit ? Theme.accentSoft : Theme.hover

    Text {
        id: chipText
        anchors.centerIn: parent
        text: chip.label
        color: chipArea.containsMouse || chip.lit ? Theme.accent : Theme.dim
        font { family: Theme.font; pixelSize: 11 }
    }
    MouseArea {
        id: chipArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
