#!/data/data/com.termux/files/usr/bin/bash
# Stop XFCE, X server, and unmount chroot binds. Safe when nothing is running.
set -eu

UBUNTUPATH="${UBUNTUPATH:-/data/local/chroot/ubuntu}"

if [ "${1:-}" = "--proot" ]; then
  pkill -f 'xfce4-session' 2>/dev/null || true
  pkill -f 'termux.x11'    2>/dev/null || true
  pulseaudio --kill        2>/dev/null || true
  exit 0
fi

tsu -c '
set -eu
UBUNTUPATH='"$UBUNTUPATH"'
pkill -f "xfce4-session"                2>/dev/null || true
pkill -f "dbus-launch.*xfce4-session"   2>/dev/null || true
pkill -f "termux.x11"                   2>/dev/null || true
for m in dev/shm dev/pts dev sys proc sdcard; do
  busybox mountpoint -q "$UBUNTUPATH/$m" && busybox umount -l "$UBUNTUPATH/$m" || true
done
'

am start --user 0 -n com.termux/.HomeActivity >/dev/null 2>&1 || true
echo "stopped."
