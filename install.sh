#!/bin/sh
# Start qs-launchpad at login (./install.sh), or stop doing so (./install.sh --remove).
set -e
dir=$(cd "$(dirname "$0")" && pwd)
conf="${XDG_CONFIG_HOME:-$HOME/.config}"
entry="$conf/autostart/qslaunchpad.desktop"
# systemd runs autostart entries as app-<id>@autostart.service, escaping any hyphen in <id>.
dropin="$conf/systemd/user/app-qslaunchpad@autostart.service.d"

rm -f "$conf/autostart/claude-qs.desktop" "$conf/autostart/claudedock.desktop"          # names used by earlier versions
rm -rf "$conf/systemd/user/app-claudedock@autostart.service.d"

if [ "$1" = "--remove" ]; then
    rm -f "$entry"
    rm -rf "$dropin"
    systemctl --user daemon-reload 2>/dev/null || true
    echo "Removed $entry"
    exit 0
fi

mkdir -p "$(dirname "$entry")" "$dropin"
cat > "$entry" <<EOF
[Desktop Entry]
Type=Application
Name=qs-launchpad
Comment=Right-edge Claude launcher (Quickshell)
Exec=qs -n -p $dir
X-KDE-autostart-phase=2
NoDisplay=true
EOF
# With the default OOMPolicy=stop, one OOM-killed child (say, an indexer run) would stop the dock.
printf '[Service]\nOOMPolicy=continue\n' > "$dropin/oom.conf"
systemctl --user daemon-reload 2>/dev/null || true
echo "Wrote $entry"
