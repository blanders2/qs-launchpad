pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// A module's title row: glyph, title, subtitle, its buttons ([{glyph, tip, run}]) and close.
RowLayout {
    id: header

    property string glyph
    property string title
    property string subtitle
    property var buttons: []

    spacing: 10

    ModuleIcon {
        glyph: header.glyph
        color: Theme.accent
        size: 26
    }
    ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        Text { text: header.title; color: Theme.text; font { family: Theme.font; pixelSize: 17; weight: Font.DemiBold } }
        Text {
            Layout.fillWidth: true
            text: header.subtitle
            color: Theme.faint
            elide: Text.ElideRight
            font { family: Theme.font; pixelSize: 11 }
        }
    }
    Repeater {
        model: header.buttons
        delegate: IconButton {
            required property var modelData
            glyph: modelData.glyph
            tip: modelData.tip
            onClicked: modelData.run()
        }
    }
    IconButton { glyph: "✕"; tip: "Close"; onClicked: Claude.close() }
}
