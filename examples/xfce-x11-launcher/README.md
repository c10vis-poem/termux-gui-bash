# XFCE on Termux:X11 launcher (chroot, with proot fallback)

End-to-end script for launching an XFCE desktop inside a **chroot** Ubuntu 24.04 (rooted device), rendered via Termux:X11. A `--proot` fallback is included for non-rooted users.

Why chroot over proot-distro: chroot runs ARM64 binaries directly on the kernel — no ptrace interception, so apt/gtk/Chromium feel native. The trade-off is that you need root, busybox, and a one-time rootfs install.

## Prerequisites

On the Android device:

1. **Termux:X11** APK (arm64-v8a): https://github.com/termux/termux-x11/releases
2. Termux native packages:
   ```sh
   pkg install root-repo
   pkg install tsu busybox curl termux-x11-nightly
   ```
3. (One-time) install the Ubuntu rootfs:
   ```sh
   chmod +x install-ubuntu-chroot.sh start-xfce.sh stop-xfce.sh start-xfce-proot.sh
   ./install-ubuntu-chroot.sh
   ```
   This downloads `ubuntu-base-24.04.4-base-arm64.tar.gz`, extracts to `/data/local/chroot/ubuntu`, fixes Android groups (`aid_inet`/`aid_net_raw`/`aid_graphics`) so apt works, installs XFCE, and seeds DNS.

   Override path:
   ```sh
   UBUNTUPATH=/data/local/chroot/myubuntu ./install-ubuntu-chroot.sh
   ```

## Use

```sh
./start-xfce.sh         # chroot mode (default — needs root)
./start-xfce.sh --proot # proot fallback (no root)
./stop-xfce.sh          # tear down (mirrors mode chosen at start)
```

The Termux:X11 activity is brought to the foreground automatically. Switch to it from the recent-apps tray.

## How the chroot launcher works

1. `tsu` grants root for the lifetime of the chroot setup.
2. Bind-mounts `/dev`, `/sys`, `/proc`, `/dev/pts`, `/sdcard` (and a tmpfs at `/dev/shm`) into the chroot — idempotent, skipped if already mounted.
3. Exports `TMPDIR=$UBUNTUPATH/tmp` and `XKB_CONFIG_ROOT=$UBUNTUPATH/usr/share/X11/xkb` — required by Termux:X11 when the X server is paired with a chrooted client (otherwise `xkbcomp` blows up on keymap load).
4. Launches `termux-x11 :1 -xstartup "busybox chroot ... dbus-launch --exit-with-session xfce4-session"`. The `-xstartup` argument is the command Termux:X11 spawns once the X socket is ready; we use it to drop straight into the chroot with a clean env and start XFCE.

## Hardware acceleration

Software rendering by default. For GPU (virgl):

```sh
pkg install virglrenderer-android
```

Add before `termux-x11` invocation in `start-xfce.sh`:
```sh
virgl_test_server_android &
```

And inside the chroot env passed to xfce4-session:
```sh
GALLIUM_DRIVER=virpipe
MESA_GL_VERSION_OVERRIDE=4.0
```

In the Termux:X11 app settings, enable **Show IME with extra-keys** and the **GPU** option.

## Troubleshooting

| Symptom                              | Fix                                                                          |
|--------------------------------------|------------------------------------------------------------------------------|
| Black screen                         | `./stop-xfce.sh && ./start-xfce.sh` — the cleanup tears down stale mounts.   |
| `xkbcomp: error` at startup          | `XKB_CONFIG_ROOT` not exported — re-run launcher (script sets it).           |
| `cannot find display :1`             | Termux:X11 activity not foregrounded. Open the Termux:X11 app, then retry.   |
| apt errors `Temporary failure resolving` | Chroot `/etc/resolv.conf` missing or `aid_inet` group not on root. Re-run `install-ubuntu-chroot.sh` (idempotent). |
| Slow rendering                       | Enable GPU as above.                                                         |
| Chromium / Electron crashes          | `/dev/shm` not mounted — `start-xfce.sh` mounts a 256 MB tmpfs; bump size if needed. |
| `tsu: command not found`             | `pkg install root-repo && pkg install tsu`.                                  |

## Sources

- Ubuntu chroot reference: https://github.com/LinuxDroidMaster/Termux-Desktops/blob/main/Documentation/chroot/ubuntu_chroot.md
- Termux:X11 README (xstartup + TMPDIR/XKB_CONFIG_ROOT requirements): https://github.com/termux/termux-x11
- Ivon's chroot guide: https://ivonblog.com/en-us/posts/termux-chroot-ubuntu/
