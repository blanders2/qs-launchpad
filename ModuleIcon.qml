pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// A module's icon: a text glyph, or "tailscale", "grok", "todo" or "bookmark", which are drawn so they can take any colour.
Item {
    id: icon

    property string glyph
    property color color: Theme.dim
    property int size: 17

    readonly property bool drawn: glyph === "tailscale" || glyph === "grok" || glyph === "todo" || glyph === "bookmark"
    readonly property int dot: Math.round(size / 4)

    implicitWidth: drawn ? size : label.implicitWidth
    implicitHeight: drawn ? size : label.implicitHeight

    Text {
        id: label
        visible: !icon.drawn
        anchors.centerIn: parent
        text: icon.drawn ? "" : icon.glyph
        color: icon.color
        font { family: icon.glyph === ">_" ? Theme.mono : Theme.font; pixelSize: icon.size }
    }

    Grid {
        visible: icon.glyph === "tailscale"
        anchors.centerIn: parent
        columns: 3
        spacing: Math.round(icon.dot / 2)

        Repeater {
            model: [0, 0, 0, 1, 1, 1, 0, 1, 0]
            delegate: Rectangle {
                required property int modelData
                width: icon.dot
                height: icon.dot
                radius: icon.dot / 2
                color: icon.color
                opacity: modelData ? 1 : 0.42
            }
        }
    }

    // Three rows of a check and a line (24 units).
    Shape {
        visible: icon.glyph === "todo"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: icon.color
            strokeWidth: icon.size * 2.6 / 24
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            scale: Qt.size(icon.size / 24, icon.size / 24)

            PathSvg {
                path: "M 1.5 5 L 4 7.5 L 8.5 2 M 12 5 L 22.5 5 "
                    + "M 1.5 12 L 4 14.5 L 8.5 9 M 12 12 L 22.5 12 "
                    + "M 1.5 19 L 4 21.5 L 8.5 16 M 12 19 L 22.5 19"
            }
        }
    }

    // A bookmark ribbon with a notched tail (24 units).
    Shape {
        visible: icon.glyph === "bookmark"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: icon.color
            strokeWidth: icon.size * 2.2 / 24
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            scale: Qt.size(icon.size / 24, icon.size / 24)

            PathSvg { path: "M 4 22 L 4 4 A 2 2 0 0 1 6 2 L 18 2 A 2 2 0 0 1 20 4 L 20 22 L 12 17.2 Z" }
        }
    }

    // Grok Bot's ball, cut off by the icon's left and bottom edges, with its two slanted eyes.
    // The eyes are holes, so the dock shows through. Traced from the installed app icon (256 units).
    Shape {
        visible: icon.glyph === "grok"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: icon.color
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            scale: Qt.size(icon.size / 256, icon.size / 256)

            PathSvg {
                path: "M 0 256 L 0 90.2 A 153.2 153.2 0 0 1 246.4 256 Z "
                    + "M 89.04 147.47 L 115.12 184.03 A 19.55 19.55 0 0 0 146.96 161.33 L 120.88 124.77 A 19.55 19.55 0 0 0 89.04 147.47 Z "
                    + "M 162.25 104.78 L 196.05 152.16 A 13.2 13.2 0 0 0 217.55 136.82 L 183.75 89.44 A 13.2 13.2 0 0 0 162.25 104.78 Z"
            }
        }
    }
}
