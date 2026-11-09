pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets

// One launcher entry. modelData fields: glyph, tint, title, subtitle, meta, badge, host, dim,
// pinned, selected, status ("ok" | "bad" | "busy" | "unknown" | ""), and actions:
// [{label, lit, run}] shown as chips on hover.
Item {
    id: row

    required property var modelData
    required property int index
    property bool current: false
    signal activated(bool alt, bool shell)
    signal pinToggled()
    signal hovered()

    readonly property var actions: modelData.actions || []
    // Icons can be a glyph ("✻") or a theme icon name ("firefox", "org.kde.dolphin").
    readonly property bool themeIcon: modelData.glyph.length > 2 && /^[\w.-]+$/.test(modelData.glyph)
    readonly property color tint: modelData.tint

    implicitHeight: 56
    opacity: modelData.dim ? 0.45 : 1

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: row.modelData.selected ? Theme.accentSoft : row.current ? Theme.raised : "transparent"
        Behavior on color { ColorAnimation { duration: 90 } }

        Rectangle {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 3
            height: row.current ? 22 : 0
            radius: 1.5
            color: Theme.accent
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.modelData.dim ? Qt.ArrowCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onEntered: row.hovered()
        onClicked: mouse => mouse.button === Qt.RightButton ? row.pinToggled() : row.activated(mouse.button === Qt.MiddleButton || !!(mouse.modifiers & Qt.ShiftModifier), !!(mouse.modifiers & Qt.ControlModifier))

        Rectangle {
            id: icon
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            width: 34
            height: 34
            radius: 9
            color: Qt.rgba(row.tint.r, row.tint.g, row.tint.b, 0.16)

            Text {
                visible: !row.themeIcon
                anchors.centerIn: parent
                text: row.modelData.glyph
                color: row.tint
                font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
            }
            IconImage {
                visible: row.themeIcon
                anchors.centerIn: parent
                implicitSize: 20
                source: row.themeIcon ? Quickshell.iconPath(row.modelData.glyph, true) : ""
            }
            // Live state (reachable host, running tunnel…) as a dot on the icon's corner.
            Rectangle {
                visible: !!row.modelData.status
                anchors { right: parent.right; bottom: parent.bottom; margins: -2 }
                width: 11
                height: 11
                radius: 5.5
                border.width: 2
                border.color: Theme.surface
                color: row.modelData.status === "ok" ? Theme.good : row.modelData.status === "bad" ? Theme.bad
                    : row.modelData.status === "busy" ? Theme.warn : Theme.faint
            }
        }

        Column {
            anchors { left: icon.right; leftMargin: 12; right: side.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 3

            Row {
                width: parent.width
                spacing: 7
                Text {
                    id: title
                    width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 7 : 0) - (hostTag.visible ? hostTag.width + 7 : 0))
                    text: row.modelData.title
                    color: Theme.text
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: 14; weight: Font.Medium }
                }
                Rectangle {
                    id: hostTag
                    visible: !!row.modelData.host
                    anchors.verticalCenter: title.verticalCenter
                    width: hostText.implicitWidth + 12
                    height: 16
                    radius: 4
                    color: "#2a5e9ea8"
                    border.width: 1
                    border.color: "#555e9ea8"
                    Text {
                        id: hostText
                        anchors.centerIn: parent
                        text: "⇄ " + row.modelData.host
                        color: "#8cc4cc"
                        font { family: Theme.font; pixelSize: 10 }
                    }
                }
                Rectangle {
                    id: badge
                    visible: !!row.modelData.badge
                    anchors.verticalCenter: title.verticalCenter
                    width: badgeText.implicitWidth + 10
                    height: 16
                    radius: 8
                    color: Theme.hover
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: row.modelData.badge || ""
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 10 }
                    }
                }
            }
            Text {
                width: parent.width
                text: row.modelData.subtitle
                color: row.modelData.subtitleBad ? Theme.bad : Theme.dim
                elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 12 }
            }
        }

        Item {
            id: side
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width: chips.visible ? chips.width : metaRow.width
            height: parent.height

            Row {
                id: metaRow
                visible: !chips.visible
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 6
                Text {
                    text: row.modelData.meta || ""
                    color: Theme.faint
                    font { family: Theme.font; pixelSize: 11 }
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    visible: !!row.modelData.pinned
                    text: "★"
                    color: Theme.accent
                    font { family: Theme.font; pixelSize: 12 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                id: chips
                visible: row.actions.length > 0 && !row.modelData.dim && area.containsMouse
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 4
                Repeater {
                    model: row.actions
                    delegate: Chip {
                        required property var modelData
                        label: modelData.label
                        lit: !!modelData.lit
                        onClicked: modelData.run()
                    }
                }
            }
        }
    }
}
