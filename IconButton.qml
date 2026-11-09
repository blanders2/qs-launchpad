import QtQuick

Rectangle {
    id: btn

    property string glyph
    property string tip
    signal clicked()

    implicitWidth: 30
    implicitHeight: 30
    radius: 8
    color: area.containsMouse ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        color: area.containsMouse ? Theme.text : Theme.dim
        font { family: Theme.font; pixelSize: 15 }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
