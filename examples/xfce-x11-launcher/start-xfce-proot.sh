#!/data/data/com.termux/files/usr/bin/bash
# Fallback launcher for users without root: XFCE on Termux:X11 via proot-distro
# Ubuntu. Slower than chroot (ptrace overhead) but needs no root.
set -eu

DISPLAY_NUM=":1"
PULSE_PORT="4713"

pkill -f 'termux.x11'    2>/dev/null || true
pkill -f 'xfce4-session' 2>/dev/null || true
pulseaudio --kill        2>/dev/null || true
sleep 1

pulseaudio --start \
  --load="module-native-protocol-tcp port=${PULSE_PORT} auth-ip-acl=127.0.0.1 auth-anonymous=1" \
  --exit-idle-time=-1

am start --user 0 -n com.termux.x11/.MainActivity >/dev/null 2>&1

termux-x11 "$DISPLAY_NUM" -xstartup "proot-distro login ubuntu --shared-tmp -- /bin/bash -lc '
  export DISPLAY=$DISPLAY_NUM
  export PULSE_SERVER=tcp:127.0.0.1:${PULSE_PORT}
  export XDG_RUNTIME_DIR=/tmp/runtime-root
  mkdir -p \$XDG_RUNTIME_DIR && chmod 700 \$XDG_RUNTIME_DIR
  dbus-launch --exit-with-session startxfce4
'" >/dev/null 2>&1 &

echo "XFCE starting (proot) on DISPLAY=$DISPLAY_NUM. Switch to Termux:X11."
