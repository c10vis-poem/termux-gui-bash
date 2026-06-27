#!/data/data/com.termux/files/usr/bin/bash
# Launch XFCE inside a chroot Ubuntu (rooted device), rendered via Termux:X11.
#
# Default assumption: rooted device, chroot rootfs at /data/local/chroot/ubuntu.
# Override the path via UBUNTUPATH env var. For non-rooted users, run with the
# --proot flag (uses proot-distro instead — see start-xfce-proot.sh).
#
# Requires (one-time):
#   pkg install root-repo tsu busybox termux-x11-nightly
#   The Termux:X11 APK installed on Android.
#   Ubuntu chroot rootfs already extracted (see README).
#
# Idempotent: tears down stale mounts/processes before starting.
set -eu

UBUNTUPATH="${UBUNTUPATH:-/data/local/chroot/ubuntu}"
DISPLAY_NUM=":1"

if [ "${1:-}" = "--proot" ]; then
  exec "$(dirname "$0")/start-xfce-proot.sh" "${@:2}"
fi

if [ ! -d "$UBUNTUPATH" ]; then
  echo "chroot rootfs not found at $UBUNTUPATH" >&2
  echo "see README.md for one-time install." >&2
  exit 1
fi

# All chroot mount + launch work runs as root via tsu.
tsu -c '
set -eu
UBUNTUPATH='"$UBUNTUPATH"'
DISPLAY_NUM='"$DISPLAY_NUM"'

cleanup_stale() {
  pkill -f "termux.x11"                   2>/dev/null || true
  pkill -f "xfce4-session"                2>/dev/null || true
  pkill -f "dbus-launch.*xfce4-session"   2>/dev/null || true
  for m in dev/pts dev sys proc sdcard; do
    busybox mountpoint -q "$UBUNTUPATH/$m" && busybox umount -l "$UBUNTUPATH/$m" || true
  done
  sleep 1
}

bind_mounts() {
  busybox mount -o remount,dev,suid /data
  busybox mountpoint -q "$UBUNTUPATH/dev"     || busybox mount --bind /dev    "$UBUNTUPATH/dev"
  busybox mountpoint -q "$UBUNTUPATH/sys"     || busybox mount --bind /sys    "$UBUNTUPATH/sys"
  busybox mountpoint -q "$UBUNTUPATH/proc"    || busybox mount --bind /proc   "$UBUNTUPATH/proc"
  busybox mountpoint -q "$UBUNTUPATH/dev/pts" || busybox mount -t devpts devpts "$UBUNTUPATH/dev/pts"
  busybox mountpoint -q "$UBUNTUPATH/sdcard"  || busybox mount --bind /sdcard "$UBUNTUPATH/sdcard"
  # /dev/shm is needed by Chromium/Electron and some GTK apps.
  mkdir -p "$UBUNTUPATH/dev/shm"
  busybox mountpoint -q "$UBUNTUPATH/dev/shm" || \
    busybox mount -t tmpfs -o size=256M tmpfs "$UBUNTUPATH/dev/shm"
}

start_x_server() {
  # Foreground the Termux:X11 activity so it has a surface to draw on.
  am start --user 0 -n com.termux.x11/.MainActivity >/dev/null 2>&1

  # Termux:X11 needs TMPDIR to point to the chroots /tmp; XKB_CONFIG_ROOT must
  # point to the chroots xkb dir or xkbcomp errors out.
  export TMPDIR="$UBUNTUPATH/tmp"
  export XKB_CONFIG_ROOT="$UBUNTUPATH/usr/share/X11/xkb"
  mkdir -p "$TMPDIR" && chmod 1777 "$TMPDIR"

  # -xstartup runs the command inside the chroot via env wipe + busybox chroot.
  # dbus-launch keeps the session bus alive for the lifetime of xfce4-session.
  termux-x11 "$DISPLAY_NUM" -xstartup "busybox chroot $UBUNTUPATH /usr/bin/env -i \
    HOME=/root \
    TERM=xterm-256color \
    LANG=en_US.UTF-8 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    DISPLAY=$DISPLAY_NUM \
    /bin/bash -lc \"dbus-launch --exit-with-session xfce4-session\"" \
    >/dev/null 2>&1 &
}

cleanup_stale
bind_mounts
start_x_server
echo "XFCE starting on DISPLAY=$DISPLAY_NUM (chroot at $UBUNTUPATH). Switch to the Termux:X11 app."
'
