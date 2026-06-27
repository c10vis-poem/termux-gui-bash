# XFCE on Debian via TigerVNC, viewed in AVNC

The desktop stack actually in use on the phone/tablet:

```
Termux ─ tmux ─ proot-distro Debian ─ TigerVNC (X11) ─ XFCE
                                            │
                                  AVNC app  ▼  127.0.0.1
                          gui :1 → 5901 · portrait :2 → 5902 · landscape :3 → 5903
```

No root, no Termux:X11 — XFCE is rendered into a TigerVNC framebuffer inside
Debian and you connect to it locally with the **AVNC** viewer. Each orientation
is just a separate VNC display with its own geometry, so you can leave all three
running and switch by changing the port in AVNC.

> This supersedes `examples/xfce-x11-launcher/` (Termux:X11 + Ubuntu chroot),
> which is a different approach kept around as an alternative.

## One-time setup

In Termux:

```sh
pkg install proot-distro tmux
proot-distro install debian
```

Inside Debian (`proot-distro login debian`):

```sh
apt update
apt install -y tigervnc-standalone-server tigervnc-common \
               xfce4 xfce4-goodies dbus-x11
```

Set a VNC password once (used by AVNC):

```sh
vncpasswd
```

On Android: install **AVNC** (F-Droid / Play). Add a server per orientation:
`127.0.0.1:5901` (gui), `127.0.0.1:5902` (portrait), `127.0.0.1:5903` (landscape).

## Daily use

From Termux (run it inside a `tmux` session so the desktop survives Termux
losing focus):

```sh
chmod +x vnc.sh
./vnc.sh start gui          # :1 -> 5901
./vnc.sh start portrait     # :2 -> 5902
./vnc.sh start landscape    # :3 -> 5903
./vnc.sh status             # list sessions + listening ports
./vnc.sh restart portrait
./vnc.sh stop landscape
```

The script auto-forwards into the Debian guest via `proot-distro`, writes a
sane `~/.vnc/xstartup` (dbus-launch + `startxfce4`) if you don't have one, clears
stale display locks, and starts `tigervncserver` with the right geometry.

Then open AVNC and connect to the matching `127.0.0.1:<port>`.

## Tuning

Everything is env-overridable — set before calling the script:

| Variable | Default | Meaning |
|---|---|---|
| `DISTRO` | `debian` | proot-distro guest name |
| `GEOM_GUI` | `1280x500` | geometry for the gui profile (:1) |
| `GEOM_PORTRAIT` | `500x1280` | portrait geometry (:2) |
| `GEOM_LANDSCAPE` | `1280x500` | landscape geometry (:3) |

> Defaults are ~half native resolution (best-recall: ~`1280x500` landscape,
> flipped to `500x1280` portrait), which keeps VNC snappy on-device. If the
> aspect looks off, just swap the numbers or set the exact device values, e.g.
> `GEOM_LANDSCAPE=1280x550 ./vnc.sh start landscape`.
| `DEPTH` | `24` | color depth |
| `DPI` | `96` | font/UI scaling |
| `VNC_LOCALHOST` | `1` | bind 127.0.0.1 only (AVNC is on-device, keep this) |

Set the geometry to your device's real resolution for a crisp 1:1 image, e.g.
`GEOM_PORTRAIT=1080x2400 ./vnc.sh start portrait`.

## Troubleshooting

- **AVNC: connection refused** → the session for that port isn't running.
  `./vnc.sh status`; start the profile you're connecting to.
- **Grey screen / no panel** → XFCE didn't launch. Confirm `xfce4` and
  `dbus-x11` are installed in Debian; delete `~/.vnc/xstartup` and re-run so the
  script regenerates it.
- **"A VNC server is already running as :N"** → stale lock; the script clears
  these, but you can force it: `tigervncserver -kill :N` then restart.
- **Auth fails in AVNC** → re-run `vncpasswd` in Debian and update the saved
  password in AVNC.
- **Desktop dies when Termux backgrounds** → start it from inside `tmux` and
  acquire a Termux wake-lock (`termux-wake-lock`).
