# XFCETweaks

Custom XFCE keybinding scripts and OSD notifications: perceptual brightness
steps, fast volume HUD, mic toggle, freeze-frame region screenshots, FnLock
toggle, show-desktop that works with Wine windows, fullscreen zoom, and a
battery guard with a fullscreen plug-in-charger countdown that pauses media
and resumes on charger plug-in.

Tested on Linux Mint 22.x / XFCE 4.18 (X11), Lenovo LOQ (Intel iGPU +
`nvidia_wmi_ec_backlight`). No secrets in this repo.

## Features

### Brightness — 20 perceptual levels (`sbin/brightness-step`)

`XF86MonBrightnessUp/Down` step through 20 stops tuned for the panel
(`1 2 3 5 8 13 21 34 47 70 101 142 193 253 324 403 492 589 693 800` at
max 800): exponential at the dark end, blended toward linear at the top so
jumps stay small. The OSD shows the preset number (`12/20`) with an even
bar instead of a misleading linear hardware percentage.

![brightness OSD](screenshots/osd-brightness.png)

### Volume (`bin/xfce-pipewire-volume`)

`XF86Audio*` keys drive PipeWire via a single `wpctl` roundtrip per press
(no lag on key repeat), with an icon-only badge (glyph + exact percent +
bar, up to 200% overdrive).

![volume OSD](screenshots/osd-volume.png)
![volume low](screenshots/osd-volume-low.png)
![volume muted](screenshots/osd-volume-muted.png)

### Microphone (`bin/mic-toggle`)

Toggles the default source mute with a muted/unmuted notification.

![mic muted](screenshots/feat-mic-muted.png)
![mic live](screenshots/feat-mic-live.png)

### Screenshots (`bin/rect-screenshot-clipboard`, `libexec/screenshot-cropper`)

![screenshot](screenshots/feat-screenshot.png)

`Print` freezes the screen first, so open (context) menus stay visible,
then crops on the frozen image. Improvements in this repo:

- keyboard + pointer grab while cropping, so no other app processes the
  Print keypress and menus stay open;
- single-instance lock — a second Print press exits silently instead of
  stacking cropper windows;
- in-process GDK root capture (`--grab`) instead of forking ImageMagick,
  with automatic fallback to `import` (exit code 3 = capture failed).

Modes: `region` (default, `Print`), `full` (`Shift+Print`),
`menu` (`Ctrl+Print`: notifies, waits `$SCREENSHOT_MENU_DELAY`, default
5 s, so a menu can be reopened, then captures *and crops* like region),
`window` (`Alt+Print`).
Results land in the clipboard via a small GTK owner process.

> Firefox note: Firefox/XUL context menus hide on the Print keypress
> itself — the open menu owns the X grab, so the key reaches Firefox
> before this script runs, and no screenshot tool can freeze it in time
> (Discord/Electron menus ignore the key, which is why they capture
> fine). For Firefox menus use `Ctrl+Print`: press it, right-click to
> reopen the menu during the delay, then select the area.

### Charger plug / battery guard (`bin/battery-guard`, `sbin/battery-shutdown-countdown`)

A 30 s timer watches the battery: charger plug/unplug notifications with
charge badges, FnLock change reports, and at ≤18% on battery a fullscreen
**plug-in-charger countdown** to hibernation. While the countdown is up it
pauses MPRIS players (Firefox, Spotify, …) over D-Bus, and resumes exactly
the players it paused when the charger is plugged in — never on the
hibernate path. Test mode (`--test`) skips media handling.

![charger plugged](screenshots/osd-charger.png)
![on battery](screenshots/osd-battery.png)

### Extras

- `bin/fnlock-toggle` — Ideapad FnLock via sysfs (see `udev/99-fnlock.rules`
  for passwordless access) with OSD.

  ![fnlock](screenshots/feat-fnlock.png)
- `bin/toggle-desktop` — show-desktop done window-by-window so Wine
  windows (Mailbird) minimize/restore correctly.
- `bin/xfwm-fullscreen-zoom` — Super+plus/minus zoom.
- `bin/smart-charge` — conservation-mode helper.
- `bin/osd-badge` — generates and caches all OSD badge icons, rebuilding
  `icon-theme.cache` whenever a new icon name appears.

### Headphone plug/unplug auto-switch (`bin/audio-output-autoswitch`)

![headset](screenshots/feat-headphones.png)

Keeps the default sink and existing streams on the connected headset.
Fixes two races in naive switchers: the default is set via WirePlumber
*before* moving existing streams (so new streams can't briefly play
through the speakers), and during Bluetooth profile/codec renegotiation
— when the sink briefly disappears while the headset stays connected —
playback is *not* bounced to the speakers. Wired plug/unplug is handled
through the ALSA fallback. Runs as `audio-output-autoswitch.service`,
reacting to `pactl subscribe` sink/sink-input events.

Configure your headset in `~/.config/XFCETweaks/audio.conf`
(`HEADSET_ADDRESS` + `HEADSET_TOKEN`, see `config/audio.conf.example`);
with empty values only the wired path is active.

Companion audio fixes in this repo:

- `bin/mic-quality-setup` (`mic-quality.service --watch`) — pins mic
  levels (boosts off, capture 50%), keeps the `voice_clear` filter fed
  by the real microphone only, and routes app recordings to it.
- `bin/pipewire-rt-guard` (`pipewire-rt-guard.service`) + the
  `systemd/user/{pipewire,pipewire-pulse,wireplumber}.service.d/`
  drop-ins — realtime priority for PipeWire data loops so audio never
  stutters under load.

## Installation

```sh
git clone https://github.com/gyurix/XFCETweaks.git
cd XFCETweaks
./install.sh
```

`install.sh` installs packages (`xdotool wmctrl x11-utils imagemagick
libnotify-bin python3-gi python3-pil python3-dbus adwaita-icon-theme
fonts-dejavu xfce4-power-manager upower pipewire-pulse wireplumber`),
copies `bin/` → `~/.local/bin`, `libexec/` → `~/.local/libexec`,
`sbin/` → `/usr/local/bin` (sudo), enables the `battery-guard.timer`
user unit, installs the udev rule, applies keybindings via
`xfconf/apply.sh`, and refreshes the icon cache. Set `SKIP_APT=1` to skip
the apt step.

Requirements and notes:

- X11 session (uses `xdotool`, `xprop`, `wmctrl`, GDK X11 grabs).
- Brightness needs a sysfs backlight (here `nvidia_wmi_ec_backlight`,
  max 800 — other max values are auto-scaled) plus
  `xfpm-power-backlight-helper` from `xfce4-power-manager`.
- The hibernate countdown calls `sudo -n systemctl hibernate`; allow it
  passwordless if wanted, otherwise it falls back to suspend.
- Log out/in after install if FnLock permissions or keybindings lag.

## Layout

```
bin/            user keybinding scripts (~/.local/bin)
libexec/        screenshot cropper + clipboard owner (~/.local/libexec)
sbin/           root helpers: brightness-step, battery-shutdown-countdown
systemd/user/   battery, audio, mic and rt-priority units + PipeWire drop-ins
config/         audio.conf.example (headset address for auto-switch)
udev/           99-fnlock.rules (user-writable FnLock sysfs)
xfconf/         apply.sh + reference dumps of current settings
screenshots/    OSD badge samples used above
```

## License

MIT — see LICENSE.
