import QtQuick
import QtQuick.Layouts

// The launcher's contents: the current module. Alt+1…6 switches modules.
Item {
    id: panel

    readonly property var modules: [claudeModule, sshModule, todoModule, bookmarksModule, grokModule, tailscaleModule]

    function open() { modules[Math.min(Claude.module, modules.length - 1)].open(); }
    function refocus() { modules[Math.min(Claude.module, modules.length - 1)].focusSearch(); }

    Connections {
        target: Claude
        function onModuleChanged() { if (Claude.open) panel.open(); }
    }

    // Unhandled keys from a module's search field arrive here.
    Keys.onPressed: event => {
        if ((event.modifiers & Qt.AltModifier) && event.key >= Qt.Key_1 && event.key < Qt.Key_1 + modules.length) {
            Claude.module = event.key - Qt.Key_1;
            event.accepted = true;
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: Claude.module

        ClaudeModule { id: claudeModule }
        SshModule { id: sshModule }
        TodoModule { id: todoModule }
        BookmarksModule { id: bookmarksModule }
        GrokModule { id: grokModule }
        TailscaleModule { id: tailscaleModule }
    }
}
