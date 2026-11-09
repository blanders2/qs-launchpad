import QtQuick
import QtQuick.Shapes

// The dock on the bottom screen edge and the menu sitting on it, as one outline. The line between
// them is left open over the selected icon, so the menu runs straight out of that icon. With no
// menu height it's just the dock. Fills its parent, so every coordinate here is in window space.
Shape {
    id: shape

    property real dockLeft: 0
    property real dockRight: 0
    property real dockTop: 0
    property real dockRadius: 10
    property real openLeft: 0
    property real openRight: 0
    property real menuLeft: 0
    property real menuRight: 0
    property real menuTop: 0
    property color fill: "white"
    property color stroke: "transparent"

    readonly property real b: height
    readonly property real dockFillet: 12
    readonly property real menuH: dockTop - menuTop
    readonly property real rt: Math.min(18, (menuRight - menuLeft) / 2, menuH / 2)
    readonly property real rl: Math.max(0, Math.min(18, menuH / 2, openLeft - menuLeft))
    readonly property real rr: Math.max(0, Math.min(18, menuH / 2, menuRight - openRight))

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: shape.fill
        strokeColor: shape.stroke
        strokeWidth: 1
        startX: shape.dockLeft - shape.dockFillet
        startY: shape.b

        PathArc { x: shape.dockLeft; y: shape.b - shape.dockFillet; radiusX: shape.dockFillet; radiusY: shape.dockFillet; direction: PathArc.Counterclockwise }
        PathLine { x: shape.dockLeft; y: shape.dockTop + shape.dockRadius }
        PathArc { x: shape.dockLeft + shape.dockRadius; y: shape.dockTop; radiusX: shape.dockRadius; radiusY: shape.dockRadius; direction: PathArc.Clockwise }
        PathLine { x: shape.openLeft; y: shape.dockTop }

        // Round the menu, starting back along its bottom edge from the opening.
        PathLine { x: shape.menuLeft + shape.rl; y: shape.dockTop }
        PathArc { x: shape.menuLeft; y: shape.dockTop - shape.rl; radiusX: shape.rl; radiusY: shape.rl; direction: PathArc.Clockwise }
        PathLine { x: shape.menuLeft; y: shape.menuTop + shape.rt }
        PathArc { x: shape.menuLeft + shape.rt; y: shape.menuTop; radiusX: shape.rt; radiusY: shape.rt; direction: PathArc.Clockwise }
        PathLine { x: shape.menuRight - shape.rt; y: shape.menuTop }
        PathArc { x: shape.menuRight; y: shape.menuTop + shape.rt; radiusX: shape.rt; radiusY: shape.rt; direction: PathArc.Clockwise }
        PathLine { x: shape.menuRight; y: shape.dockTop - shape.rr }
        PathArc { x: shape.menuRight - shape.rr; y: shape.dockTop; radiusX: shape.rr; radiusY: shape.rr; direction: PathArc.Clockwise }
        PathLine { x: shape.openRight; y: shape.dockTop }

        PathLine { x: shape.dockRight - shape.dockRadius; y: shape.dockTop }
        PathArc { x: shape.dockRight; y: shape.dockTop + shape.dockRadius; radiusX: shape.dockRadius; radiusY: shape.dockRadius; direction: PathArc.Clockwise }
        PathLine { x: shape.dockRight; y: shape.b - shape.dockFillet }
        PathArc { x: shape.dockRight + shape.dockFillet; y: shape.b; radiusX: shape.dockFillet; radiusY: shape.dockFillet; direction: PathArc.Counterclockwise }
    }
}
