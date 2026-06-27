#!/data/data/com.termux/files/usr/bin/bash
# vnc.sh — control an XFCE desktop served by TigerVNC inside a Debian
# proot-distro, viewed from the AVNC app on the same device.
#
# Real stack this matches:
#   Termux -> tmux -> proot Debian -> TigerVNC (X11) -> XFCE  <- AVNC (127.0.0.1)
#
# Profiles map to a VNC display, which fixes the port (port = 5900 + display):
#   gui        -> :1  -> 127.0.0.1:5901   (default / desktop geometry)
#   portrait   -> :2  -> 127.0.0.1:5902   (phone/tablet held upright)
#   landscape  -> :3  -> 127.0.0.1:5903   (phone/tablet on its side)
#
# Usage (from Termux, e.g. inside tmux):
#   ./vnc.sh start gui
#   ./vnc.sh start portrait
#   ./vnc.sh start landscape
#   ./vnc.sh stop  portrait
#   ./vnc.sh status
#   ./vnc.sh restart gui
#
# Then point AVNC at 127.0.0.1:<port> for that profile.
#
# Override anything via env:
#   DISTRO=debian                         proot-distro name
#   GEOM_GUI=1280x800                     geometry per profile
#   GEOM_PORTRAIT=1080x2160
#   GEOM_LANDSCAPE=2160x1080
#   DEPTH=24                              color depth
#   DPI=96
#   VNC_LOCALHOST=1                       1 = bind 127.0.0.1 only (AVNC is local)
set -eu

DISTRO="${DISTRO:-debian}"
DEPTH="${DEPTH:-24}"
DPI="${DPI:-96}"
VNC_LOCALHOST="${VNC_LOCALHOST:-1}"
# Down-scaled (~half native) geometry that's known to work well on the device.
# Best-recall values — flip them if orientation looks wrong; override via env.
GEOM_GUI="${GEOM_GUI:-1280x500}"
GEOM_LANDSCAPE="${GEOM_LANDSCAPE:-1280x500}"
GEOM_PORTRAIT="${GEOM_PORTRAIT:-500x1280}"

die() { printf 'vnc.sh: %s\n' "$*" >&2; exit 1; }

# Map a profile name to "display geometry".
profile_to() {
  case "${1:-}" in
    gui)       echo ":1 $GEOM_GUI" ;;
    portrait)  echo ":2 $GEOM_PORTRAIT" ;;
    landscape) echo ":3 $GEOM_LANDSCAPE" ;;
    *) die "unknown profile '${1:-}' (use: gui | portrait | landscape)" ;;
  esac
}

# Are we already inside the Debian guest? (tigervncserver present + not Termux)
in_guest() { [ ! -d /data/data/com.termux ] && command -v tigervncserver >/dev/null 2>&1; }

# Re-run this script inside the Debian guest with the same args.
reexec_in_guest() {
  command -v proot-distro >/dev/null 2>&1 || die "proot-distro not found (pkg install proot-distro)"
  # Copy ourselves into a stable path inside the guest, then run it there.
  local self payload
  self="$(readlink -f "$0")"
  payload="/root/.vnc-control.sh"
  proot-distro login "$DISTRO" --shared-tmp -- bash -c "cat > '$payload'" < "$self"
  proot-distro login "$DISTRO" --shared-tmp -- bash "$payload" "$@"
}

# --- everything below runs INSIDE the Debian guest -------------------------

ensure_xstartup() {
  mkdir -p "$HOME/.vnc"
  local x="$HOME/.vnc/xstartup"
  if [ ! -f "$x" ]; then
    cat > "$x" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_RUNTIME_DIR="${TMPDIR:-/tmp}/runtime-$(id -u)"
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
[ -r "$HOME/.Xresources" ] && xrdb "$HOME/.Xresources"
dbus-launch --exit-with-session startxfce4
EOF
    chmod +x "$x"
  fi
}

guest_start() {
  local disp="$1" geom="$2"
  ensure_xstartup
  command -v tigervncserver >/dev/null 2>&1 || \
    die "tigervncserver missing in $DISTRO (apt install tigervnc-standalone-server tigervnc-common xfce4 xfce4-goodies dbus-x11)"
  local lh="-localhost no"; [ "$VNC_LOCALHOST" = "1" ] && lh="-localhost yes"
  # Clear a stale lock for this display, then start.
  tigervncserver -kill "$disp" >/dev/null 2>&1 || true
  rm -f "/tmp/.X11-unix/X${disp#:}" "/tmp/.X${disp#:}-lock" 2>/dev/null || true
  tigervncserver "$disp" -geometry "$geom" -depth "$DEPTH" -dpi "$DPI" $lh -name "xfce-${disp}"
  echo "started $disp ($geom) -> 127.0.0.1:$((5900 + ${disp#:}))  | connect AVNC there"
}

guest_stop() {
  tigervncserver -kill "$1" >/dev/null 2>&1 && echo "stopped $1" || echo "$1 was not running"
}

guest_status() {
  echo "== tigervnc sessions in $DISTRO =="
  tigervncserver -list 2>/dev/null || true
  echo "== ports =="
  for d in 1 2 3; do
    if ss -ltn 2>/dev/null | grep -q ":$((5900 + d))"; then
      echo "  :$d -> 127.0.0.1:$((5900 + d))  LISTENING"
    fi
  done
}

# --- dispatch --------------------------------------------------------------

cmd="${1:-}"; prof="${2:-gui}"

if ! in_guest; then
  # On Termux side: forward the command into the guest.
  reexec_in_guest "$@"
  exit $?
fi

case "$cmd" in
  start)   read -r d g <<EOF
$(profile_to "$prof")
EOF
           guest_start "$d" "$g" ;;
  stop)    read -r d _ <<EOF
$(profile_to "$prof")
EOF
           guest_stop "$d" ;;
  restart) read -r d g <<EOF
$(profile_to "$prof")
EOF
           guest_stop "$d"; guest_start "$d" "$g" ;;
  status)  guest_status ;;
  *) die "usage: vnc.sh {start|stop|restart} {gui|portrait|landscape} | vnc.sh status" ;;
esac
