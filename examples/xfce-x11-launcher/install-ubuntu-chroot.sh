#!/data/data/com.termux/files/usr/bin/bash
# One-time install of an Ubuntu 24.04 arm64 chroot at /data/local/chroot/ubuntu.
# Requires: root, tsu, busybox, curl.
#
# Override the install path: UBUNTUPATH=/path/to/chroot ./install-ubuntu-chroot.sh
set -eu

UBUNTUPATH="${UBUNTUPATH:-/data/local/chroot/ubuntu}"
ROOTFS_URL="${ROOTFS_URL:-https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz}"

command -v tsu     >/dev/null 2>&1 || { echo "tsu missing — pkg install tsu"; exit 1; }
command -v busybox >/dev/null 2>&1 || { echo "busybox missing — pkg install busybox"; exit 1; }
command -v curl    >/dev/null 2>&1 || { echo "curl missing — pkg install curl"; exit 1; }

# Stage the tarball in Termux home (no root needed for download)
TARBALL="$HOME/ubuntu-base-arm64.tar.gz"
if [ ! -f "$TARBALL" ]; then
  curl -fL "$ROOTFS_URL" -o "$TARBALL"
fi

tsu -c '
set -eu
UBUNTUPATH='"$UBUNTUPATH"'
TARBALL='"$TARBALL"'

mkdir -p "$UBUNTUPATH"
chmod 755 "$UBUNTUPATH"
chown root:root "$UBUNTUPATH"

cd "$UBUNTUPATH"
busybox tar xpvf "$TARBALL" --numeric-owner >/dev/null
mkdir -p sdcard tmp

# DNS, hosts, Android groups so apt and networking work.
echo "nameserver 8.8.8.8"  >  "$UBUNTUPATH/etc/resolv.conf"
echo "nameserver 1.1.1.1"  >> "$UBUNTUPATH/etc/resolv.conf"
{
  echo "127.0.0.1 localhost"
  echo "::1       localhost"
} > "$UBUNTUPATH/etc/hosts"

# Bind mounts so the next steps inside the chroot can use apt.
busybox mount -o remount,dev,suid /data
busybox mountpoint -q "$UBUNTUPATH/dev"     || busybox mount --bind /dev  "$UBUNTUPATH/dev"
busybox mountpoint -q "$UBUNTUPATH/sys"     || busybox mount --bind /sys  "$UBUNTUPATH/sys"
busybox mountpoint -q "$UBUNTUPATH/proc"    || busybox mount --bind /proc "$UBUNTUPATH/proc"
busybox mountpoint -q "$UBUNTUPATH/dev/pts" || busybox mount -t devpts devpts "$UBUNTUPATH/dev/pts"

# Inside the chroot: create Android aid_* groups, install XFCE.
busybox chroot "$UBUNTUPATH" /usr/bin/env -i \
  HOME=/root TERM=xterm-256color LANG=C.UTF-8 \
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  /bin/bash -lc "
    getent group aid_inet     >/dev/null || groupadd -g 3003 aid_inet
    getent group aid_net_raw  >/dev/null || groupadd -g 3004 aid_net_raw
    getent group aid_graphics >/dev/null || groupadd -g 1003 aid_graphics
    id _apt >/dev/null 2>&1 && usermod -g 3003 -G 3003,3004 -a _apt || true
    usermod -G 3003 -a root
    apt update
    apt install -y xfce4 xfce4-terminal dbus-x11 fonts-noto-core \
      pulseaudio-utils mesa-utils sudo locales
    locale-gen en_US.UTF-8
  "

# Best-effort umount so the install state is clean; start-xfce.sh re-binds.
for m in dev/pts dev sys proc; do
  busybox mountpoint -q "$UBUNTUPATH/$m" && busybox umount -l "$UBUNTUPATH/$m" || true
done
'

echo
echo "Ubuntu chroot installed at $UBUNTUPATH"
echo "Now run:  ./start-xfce.sh"
