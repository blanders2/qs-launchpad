pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color surface: "#fa1d1c1a"
    readonly property color raised: "#2a2825"
    readonly property color hover: "#33302c"
    readonly property color line: "#3b3833"
    readonly property color text: "#eeeae4"
    readonly property color dim: "#a59e94"
    readonly property color faint: "#6f6a63"
    readonly property color accent: "#d97757"
    readonly property color accentSoft: "#33d97757"
    readonly property color good: "#7fb069"
    readonly property color bad: "#e0685e"
    readonly property color warn: "#d9a557"

    readonly property string font: "Ubuntu Sans"
    readonly property string mono: "Ubuntu Sans Mono"

    // Small stable palette for project initials, picked by name hash.
    readonly property var tints: ["#d97757", "#c9a35a", "#7fa86b", "#5e9ea8", "#7d87c9", "#b07cb8", "#c46b7f"]
    function tint(name) {
        let h = 0;
        for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) | 0;
        return tints[Math.abs(h) % tints.length];
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }
}
