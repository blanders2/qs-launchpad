# qs-launchpad

A Quickshell launcher, and the successor to PatchGoblin. A thin clay-coloured sliver sits on the
right edge of the screen. Hover over it and a panel slides out of the screen edge; move the pointer
away and it slides back. Click the tab or anywhere in the panel and it stays open until you click
outside it, press `Esc` or launch something. While it's only hovered, the rest of the screen keeps
working and the keyboard stays with your window, so click it before typing. The panel
has an icon rail on its right edge for switching modules. `alt+1…6` switches too, and the panel
reopens on the module you used last.

- **✻ Claude**: projects, sessions, pins and links (below)
- **⇄ SSH**: servers, tunnels and keys. Its badge counts running tunnels.
- **☑ Todo**: your own checklist, with recurring tasks. Its badge counts what's open and due.
- **⚑ Bookmarks**: your Chrome bookmarks
- **✦ Grok Bots**: your Grok Bot bots, and shortcuts into the app. Its badge counts unread messages.
- **⁙ Tailscale**: your tailnet's devices and this machine's connection. Its badge says "off"
  when Tailscale is disconnected.

Each module has its own tabs and key hints along the bottom. Claude and Todo also have a search
field; SSH doesn't.

## Claude

- **Projects**: every folder under `~/Projects`, plus any folder you've run Claude in, newest first,
  on this machine and on your SSH hosts (tagged `⇄ myhost`).
  `⏎` starts a new session there, `⇧⏎` (or middle-click) continues the last one, and `^E` / `^O`
  open it in your editor or file manager. Hovering a row shows the same options as buttons.
- **Sessions**: past sessions from `~/.claude/projects`, here and on each SSH host, with the same
  titles the desktop app shows. `⏎` resumes one (`claude --resume <id>`) in its folder. Archived
  sessions, and old transcripts the desktop app has replaced, are left out.
- **Links**: whatever you list in `config.json`.
- **Pinned**: projects and sessions you've pinned, in the order you pinned them. When you have
  pins, the launcher opens on this tab. Pinned items also stay at the top of their own tabs and
  get a ★.

The **+** button in the header (or `^N`) starts a new session in the desktop app, where you
pick the folder. The **New session** link at the top of Links does the same.

To pin or unpin, hover a row and click ☆, right-click it, or press `^P`. In the Pinned tab,
`alt+↑↓` reorders. Pins are saved in `pins.json` (hand-editable, applied live) as
`p:<host>:<path>` and `s:<host>:<session id>`, where host is empty for this machine. A pinned
session stays listed even when it's older than `maxSessions`.

Claude sessions open in the **Claude desktop app**, including on SSH hosts. `^⏎`, ctrl-click, or
the `terminal` button on a row opens a plain shell in that project's or session's folder in
**TerminalGoblin** instead: a tab in the running window, titled and coloured after the project.
On an SSH host the tab is `ssh -t` into a login shell in that folder. The app is driven by
`claude://` links:

| | link |
|---|---|
| new session in a folder | `claude://code/new?folder=<path>` |
| new session on an SSH host | `claude://code/new?ssh_host=user@myhost&ssh_folder=<path>` |
| a session the app already has | `claude://code/continue?session=local_<id>` |
| a terminal-only session (imported into the app) | `claude://resume?session=<uuid>` |

A terminal-only session on an SSH host can't be opened in the app, so that one resumes with
`claude --resume` in a TerminalGoblin tab.

Type to search. If the current tab has no matches, it jumps to one that does. `⇥` switches tabs
and `Esc` clears the search or closes the launcher. Clicking outside also closes it.

## SSH

PatchGoblin's SSH tools plugin, minus saved servers, wake-on-LAN and the network map. The work is
done by `bin/ssh-tools`, which prints JSON.

- **Servers**: every `Host` in `~/.ssh/config` (following `Include`, skipping wildcards), plus
  the Claude app's SSH hosts, resolved with `ssh -G`.
  - A dot shows whether the host's SSH port answers (green), doesn't (red), or hasn't answered
    within 2.5 s (grey).
  - `⏎` opens a TerminalGoblin tab logged in there.
  - Hovering shows **claude** (a new desktop-app session on that host), **files** (Dolphin over
    sftp) and **keys** (that host's keys).
- **Tunnels**: saved `ssh -N -L/-R` port forwards, in `tunnels.json`.
  - The **New tunnel** row at the top (or `^N`) adds one.
  - `⏎` or **start/stop** runs or stops one, and `^E` / `^D` edit or delete.
  - Each tunnel runs as a systemd user unit, `qs-launchpad-tunnel-<id>`. So it keeps running when
    the dock reloads or quits, which is unlike PatchGoblin. Tunnels never start by themselves.
  - A failed tunnel shows ssh's own error (e.g. `bind [127.0.0.1]:2222: Address already in use`).
  - Starting one bound to `0.0.0.0` asks first, since that port is open to your whole network
    with no login in front of it.
  - Tunnels use key login (`BatchMode`).
- **Keys**: public keys in `~/.ssh` on this computer, or on any host (pick it in the row above
  the list).
  - `⏎` copies one (`wl-copy`).
  - `^␣` or right-click selects several.
  - **install…** or `^I` adds them to a host's `authorized_keys`, skipping any already there. If
    the host only takes a password, tick the option and type it in the TerminalGoblin tab that
    opens.
  - The **New key pair** row at the top (or `^N`) generates one, here or on a host. With a passphrase,
    `ssh-keygen` asks for it in a terminal, so it never shows in a process list.
  - Only `*.pub` files are ever read. Key listing and install support Linux and macOS hosts only.

## Todo

Your own checklist (PatchGoblin's Todo plugin, without project tags), plus recurring tasks. Items
are saved in `todo.json`, which is hand-editable and applied live. The limits are 500 items of
500 characters each.

- **Adding**: type in the **Add a to-do…** field (`^N` jumps there) and press `⏎`.
- **Rows**:
  - `⏎` or the circle ticks one off.
  - `^E` or double-click edits it.
  - `^D` deletes, and `alt+↑↓` moves it among the visible items.
- **Tabs**:
  - **Open**: what's left to do, including recurring tasks that are due.
  - **Recurring**: every recurring task, soonest first.
  - **Done**: finished one-off items. The **⌫** in the header clears them.
- Search matches the text and the repeat rule.

**Recurring tasks.** To add one, click **↻ repeat** on the add field first. To make an existing
to-do repeat, press `^R`, right-click it, or use its **repeat** button. The options are:
- Daily
- Weekdays
- Weekly, on any days you pick
- Monthly, on a day of the month. Months without that day use their last day.
- Every N days

A recurring task shows under Open from the day it's due, and stays there (marked overdue) until you
tick it. Ticking it doesn't finish it; it moves the task to its next date after today, so missed
days don't pile up. Ticking it early from the Recurring tab skips to the occurrence after the one
that was due. Choosing "Doesn't repeat" turns it back into a normal to-do.

## Bookmarks

Your Chrome bookmarks, read live from the profile in `chromeProfile` (both its `Bookmarks` and its
signed-in `AccountBookmarks`). They're read-only here, so you add and edit them in Chrome.

- **Tabs**:
  - **Bar**: the bookmarks bar, with a chip per folder to narrow it down.
  - **Mobile & other**: everything outside the bar.
  - **Recent**: by when Chrome last opened them.
- **Opening**: `⏎` opens one in your default browser. `^⏎` or **copy** copies the link.
- **Search** covers the name, URL and folder across all tabs.

## Grok Bots

Your bots, listed automatically. `bin/grok-roster` reads the bot list Grok Bot caches for your
signed-in account in `~/.config/Grok Bot/sand-client-persistence`. It reads only the roster and
the active-account pointer, never your conversations. Bots are shown with their own names,
descriptions and colours, most recently active first.

- **Status**: unread counts appear as a badge, and on the rail. A bot waiting on you says
  **needs you**.
- **Notifications**: every 15 s, even with the dock closed, the dock checks for bots with new
  messages or waiting on you, and sends a desktop notification with the latest message.
  - Clicking a notification opens that bot, if your notification popup supports it.
  - Bots that Grok Bot already notifies for are skipped. In Grok Bot that's set per bot, and it's
    currently on only for "New Bot".
  - `"grokNotifications": false` in config.json turns this off.
  - All of this depends on Grok Bot running, since it's what keeps the roster up to date.
- **Opening**: `⏎` opens a bot in Grok Bot (`grokbot://app/v1/agent?id=…`).
- **Writing**: the **Message …** field opens a bot in Grok Bot with your text already typed
  (`grokbot://app/v1/prompt`, up to 1000 characters). You press send in Grok Bot, since the app
  has no link that sends a message for you. It starts on the bot Grok Bot last had open. Click
  its chip to switch bots, or use a row's **write** button. `^N` writes to the highlighted bot.
- **App tab**: opens Grok Bot, Messages, the bot and plugin marketplaces, and New team bot.

New or renamed bots show up once Grok Bot has synced them (just open the app).

## Tailscale

Read from `tailscale status --json` every 10 s while the dock is open, and every minute otherwise.

- **Devices**: online first, each with its address, OS and whether the connection is direct or
  through a relay.
  - `⏎` opens an SSH session in TerminalGoblin. It uses the user your SSH setup already has for
    that machine, so myhost becomes `user@myhost`.
  - `^⏎` or **copy** copies the device's IP.
  - **ping** runs `tailscale ping`, and **web** opens `http://<name>/`.
  - Devices that offer to be an exit node get an **exit node** button.
- **This device**: the connection (`⏎` connects or disconnects), the IPv4, IPv6 and MagicDNS
  name to copy, the exit node, and the admin console.

Connecting, disconnecting and exit nodes change Tailscale's settings. That needs root unless your
user is Tailscale's operator. If it isn't, the dock says so and shows the command to run once
yourself: `sudo tailscale set --operator=$USER`.

## Run

```bash
qs -p ~/Projects/qs-launchpad
```

It runs alongside the textual shell as a separate instance and reloads live when you edit files.
Toggle it from a keyboard shortcut (System Settings → Shortcuts → add a command):

```bash
qs -p ~/Projects/qs-launchpad ipc call claude toggle
```

The other IPC calls are `open`, `close`, `refresh`, `state` and
`module <claude|ssh|todo|bookmarks|grok|tailscale>`. That
last one opens straight onto a module, so you can give SSH or Todo a shortcut of its own:

```bash
qs -p ~/Projects/qs-launchpad ipc call claude module todo
```

`./install.sh` starts it at login; `./install.sh --remove` stops that.

## Claude on SSH hosts

By default (`"remotes": "auto"`) the hosts are the ones you've added in the Claude desktop app
(`~/.config/Claude/ssh_configs.json`), for example `myhost` (`user@myhost`). Each time the launcher
opens, `bin/claude-index` is piped over `ssh` and run with the host's `python3`, so nothing
is installed there. That needs key-based SSH (`BatchMode`). The last listing is cached, so an
unreachable host still shows its projects and the header says it's offline.

A terminal on a host is `ssh -t -- host 'cd <dir> && exec $SHELL -l'`, the same as TerminalGoblin's
own SSH locations. When it has to run `claude` there, it uses a login shell, since that's what puts
`~/.local/bin/claude` on PATH. `code` opens the folder with VS Code
Remote-SSH and `files` opens it in Dolphin over `sftp://`.

To choose hosts yourself, or give one its own project folders:

```json
"remotes": [
    { "name": "myhost", "host": "user@myhost", "projectRoots": ["~/Projects", "~/work"] }
]
```

`"remotes": []` turns hosts off.

## config.json

Edits apply as soon as you save.

| key | |
|---|---|
| `terminal` | Opens a terminal tab with a shell. `{cwd}`, `{name}` and `{color}` are the folder, tab title and project colour. To run a command instead, `-e <command>` is added. Default is TerminalGoblin. |
| `claude` | Used only to resume terminal-only sessions on an SSH host |
| `editor`, `fileManager` | Commands for `^E` and `^O`; `{cwd}` is the project folder |
| `remoteEditor`, `remoteFileManager` | The same for SSH projects; `{host}` is e.g. `user@myhost` |
| `remotes` | `"auto"`, or a list of hosts (see above) |
| `grokNotifications` | Desktop notifications when your Grok bots have something new (default `true`) |
| `chromeProfile` | Chrome profile folder the Bookmarks module reads (default `~/.config/google-chrome/Default`) |
| `showArchived` | Include sessions you've archived in the desktop app |
| `projectRoots` | Folders whose subfolders are listed as projects |
| `extraProjects`, `hideProjects` | Extra project folders to add, and folders to leave out |
| `showSdkSessions` | Include automated `sdk-cli` sessions (e.g. PatchGoblin's planners). Off by default. |
| `maxSessions` | How many recent sessions to list |
| `screen` | Output name such as `"eDP-1"`; empty means the first screen |
| `sliverPosition`, `sliverLength` | Where the sliver sits (0 is top, 1 is bottom) and its length in px |
| `panelWidth`, `panelHeight` | Size of the launcher when open |
| `hoverOpen`, `hoverDelay` | Open on hover (`false` means only a click opens it), and how many ms the pointer rests on the tab first |
| `links` | See below |

### Links

Each link has a `name`, plus an optional `icon` (a glyph like `"✻"` or a theme icon name like
`"firefox"`) and `note` (the second line). Give it one of these:

```json
{ "name": "claude.ai",   "icon": "✻", "url": "https://claude.ai" }
{ "name": "Notes",       "icon": "✎", "command": ["kate", "~/notes.md"] }
{ "name": "System monitor", "icon": "▤", "terminal": ["htop"] }
```

`url` opens with `xdg-open`, `command` runs directly, and `terminal` runs inside `terminal`.
`cwd` defaults to `~`.

## Files

- `shell.qml`: entry point; picks the screen and handles IPC
- `Sliver.qml`: the edge bar
- `Overlay.qml`: the layer that hosts the panel, and the slide out of the edge
- `EdgeShape.qml`: the edge-attached shape the sliver and panel share
- `Panel.qml`, `Rail.qml`: the module rail and module switching
- `ListModule.qml`: the frame each module shares, built from `ModuleHeader.qml`, `SearchBox.qml`,
  `TabStrip.qml`, `ResultRow.qml`, `Chip.qml`, `IconButton.qml` and `Sheet.qml` (forms)
- Modules: `ClaudeModule.qml`, `SshModule.qml`, `TodoModule.qml`, `BookmarksModule.qml`,
  `GrokModule.qml` and `TailscaleModule.qml`
- Singletons holding each module's state and actions: `Claude.qml`, `Ssh.qml`, `Todo.qml`,
  `Bookmarks.qml`, `Grok.qml` and `Tailscale.qml`. `Theme.qml` holds colours and fonts.
- `pins.json`, `todo.json`, `tunnels.json`: your data (written by the dock, hand-editable)
- `bin/claude-index`: scans session logs, here or over SSH with `--remotes`, and caches results in
  `~/.cache/qs-launchpad/`
- `bin/ssh-tools`: SSH hosts, keys and tunnels for the SSH module
- `bin/grok-roster`: your Grok Bot bot list, from the app's cache
- `bin/notify`: desktop notifications with a click action. `notify-send` can't do this here,
  because AppArmor blocks it from checking what the notification server supports.
- `tests/`: `python3 -m unittest discover -s tests`
