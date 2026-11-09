import QtQuick
import Quickshell
import Quickshell.Io

// qs-launchpad: a row of module icons at the bottom of the screen that opens into a launcher
// for projects, past sessions and custom links. Run with: qs -p ~/Projects/qs-launchpad
ShellRoot {
    id: shell

    // The screen named by config "screen", else the first one.
    readonly property var target: {
        const all = Quickshell.screens;
        for (let i = 0; i < all.length; i++)
            if (all[i].name === Claude.cfg.screen) return all[i];
        return all[0];
    }

    Overlay { target: shell.target }

    // qs -p ~/Projects/qs-launchpad ipc call claude toggle   (bind this to a shortcut)
    IpcHandler {
        target: "claude"
        function toggle(): void { Claude.toggle(); }
        function open(): void { Claude.show(); }
        // Open on a module: claude, ssh, todo, bookmarks, grok or tailscale.
        function module(name: string): void { Claude.showModule(name); }
        function close(): void { Claude.close(); }
        function refresh(): void { Claude.refresh(); }
        function state(): string {
            return JSON.stringify({ open: Claude.open, screen: shell.target?.name ?? "", projects: Claude.projects.length, sessions: Claude.sessions.length });
        }
    }
}
