import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// The dock and the launcher, drawn as one outline on the bottom screen edge. The menu sits on the
// dock and opens out of the selected icon, where the line between them is left open; closing runs backwards.
// Resting on an icon opens the menu on that module, or switches to it if the menu is already up.
// While it's only peeking (opened by hover), just the dock and menu take input: the rest of the
// screen stays usable and the keyboard stays with your window. Once held open by a click it covers
// the screen above the status bar, so clicking anywhere outside it (or Esc) closes it.
PanelWindow {
    id: ov

    required property var target
    // 0 = closed, 1 = fully open. Animated linearly; each stage applies its own easing.
    property real p: 0

    NumberAnimation { id: anim; target: ov; property: "p"; easing.type: Easing.Linear }
    Connections {
        target: Claude
        // Duration scales with the distance left, so reversing mid-way doesn't stall.
        function onOpenChanged() {
            anim.stop();
            anim.to = Claude.open ? 1 : 0;
            anim.duration = (Claude.open ? 220 : 200) * Math.abs(anim.to - ov.p);
            anim.start();
        }
        function onHeldChanged() { if (Claude.held) content.refocus(); }
    }

    function stage(from, to) { return Math.max(0, Math.min(1, (p - from) / (to - from))); }
    function outCubic(t) { return 1 - Math.pow(1 - t, 3); }
    function outQuint(t) { return 1 - Math.pow(1 - t, 5); }
    function lerp(a, b, t) { return a + (b - a) * t; }

    readonly property real wp: outCubic(stage(0, 0.55))       // width
    readonly property real hp: outQuint(stage(0.04, 1))       // height
    readonly property real cp: outCubic(stage(0.15, 1))       // content
    readonly property real jp: outCubic(stage(0, 0.3))        // joining the dock

    readonly property int dockH: 36
    readonly property real dockW: rail.width + 32
    readonly property real dockX: Math.round((width - dockW - 24) * Math.max(0, Math.min(1, Claude.cfg.sliverPosition))) + 12 + dockW / 2
    readonly property int openingW: 34
    // Over the selected icon. Slides between icons once the menu is up, and jumps while it's closed.
    property real openingX: dockX - rail.width / 2 + rail.centerOf(Claude.module)
    Behavior on openingX {
        enabled: ov.p > 0
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    readonly property int openW: Math.min(Claude.cfg.panelWidth, width - 24)
    readonly property int openH: Math.min(Claude.cfg.panelHeight, height - dockH - 24)
    readonly property real openX: Math.max(openW / 2 + 12, Math.min(width - openW / 2 - 12, dockX))
    readonly property bool shown: Claude.open || p > 0

    screen: target
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Claude.held ? heldRegion : dockAndMenu
    WlrLayershell.layer: shown ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: Claude.held ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "claude-launcher"

    onShownChanged: if (shown) content.open()

    Region {
        id: dockAndMenu
        item: dock
        Region { item: menu }
    }
    Region {
        id: heldRegion
        width: ov.width
        height: ov.height - ov.dockH
        Region { item: dock }
    }

    // The dim backdrop only appears once the menu is held open, and leaves the status bar alone.
    Rectangle {
        width: parent.width
        height: parent.height - ov.dockH
        color: "black"
        opacity: Claude.held ? 0.22 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: Claude.close()
    }

    RectangularShadow {
        anchors.fill: menu
        visible: ov.shown
        radius: 18
        blur: 36
        spread: 0
        offset.x: 0
        offset.y: 8
        color: Qt.rgba(0, 0, 0, 0.55 * ov.hp)
    }

    EdgeShape {
        anchors.fill: parent
        dockLeft: dock.x
        dockRight: dock.x + dock.width
        dockTop: dock.y
        dockRadius: 10 * (1 - ov.jp)
        openLeft: ov.openingX - ov.openingW / 2
        openRight: ov.openingX + ov.openingW / 2
        menuLeft: menu.x
        menuRight: menu.x + menu.width
        menuTop: menu.y
        fill: Theme.surface
        stroke: Theme.line
    }

    Item {
        id: menu
        width: ov.lerp(ov.openingW, ov.openW, ov.wp)
        height: ov.openH * ov.hp
        x: ov.lerp(ov.openingX, ov.openX, ov.wp) - width / 2
        y: ov.height - ov.dockH - height
        visible: ov.shown
        clip: true

        // Only while it's up: a closed menu no longer covers where the pointer was.
        HoverHandler { enabled: ov.shown; onHoveredChanged: Claude.panelHot = hovered }

        // Swallow clicks so they don't reach the close-on-outside area.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        Panel {
            id: content
            // Laid out at full size and pinned to the menu's top edge, so it rises with it.
            width: ov.openW
            height: ov.openH
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            opacity: ov.cp
        }

        // Any press inside a peeking menu holds it open, and still reaches what's under it.
        MouseArea {
            anchors.fill: parent
            enabled: !Claude.held
            acceptedButtons: Qt.AllButtons
            onPressed: mouse => {
                Claude.hold();
                mouse.accepted = false;
            }
        }
    }

    Item {
        id: dock
        width: ov.dockW
        height: ov.dockH
        x: ov.dockX - width / 2
        y: ov.height - height

        HoverHandler { onHoveredChanged: Claude.sliverHot = hovered }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        // Its hit areas run to the screen edge, so slamming the pointer down always lands.
        Rail {
            id: rail
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            current: Claude.open ? Claude.module : -1
            reach: 10 * ov.jp
            entries: [
                { glyph: "✻", name: "Claude", badge: "" },
                { glyph: ">_", name: "SSH", badge: Ssh.running ? String(Ssh.running) : "" },
                { glyph: "todo", name: "Todo", badge: Todo.openCount ? String(Todo.openCount) : "" },
                { glyph: "bookmark", name: "Bookmarks", badge: "" },
                { glyph: "grok", name: "Grok Bots", badge: Grok.unread ? String(Grok.unread) : "" },
                { glyph: "tailscale", name: "Tailscale", badge: Tailscale.status && !Tailscale.running ? "off" : "" }
            ]
            onRolled: index => Claude.rollover = index
            onPicked: index => {
                Claude.module = index;
                Claude.show();
            }
        }
    }
}
