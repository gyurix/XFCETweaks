# XFCETweaks

Custom XFCE keybinding scripts and OSD notifications for Linux Mint 22.x /
XFCE 4.18 (X11). No secrets in this repo.

## Features

| | Feature | What it does |
|---|---|---|
| ![brightness](screenshots/osd-brightness.png) | [Brightness](#brightness) | 20 perceptual backlight levels, `12/20` OSD |
| ![volume](screenshots/osd-volume.png) | [Volume](#volume) | Lag-free PipeWire HUD with overdrive bar |
| ![mic](screenshots/feat-mic-muted.png) | [Microphone](#microphone) | One-key mute toggle with OSD |
| ![screenshot](screenshots/feat-screenshot.png) | [Screenshots](#screenshots) | Freeze-frame region capture, menus stay open |
| ![charger](screenshots/osd-charger.png) | [Charger & battery](#charger--battery-guard) | Plug alerts + hibernate countdown that pauses media |
| ![headset](screenshots/feat-headphones.png) | [Headphone auto-switch](#headphone-auto-switch) | Plug/unplug routing without speaker blips |
| ![mic-live](screenshots/feat-mic-live.png) | [Mic quality guard](#mic-quality-guard) | Pinned levels, clean filter feed |
| ![battery](screenshots/osd-battery.png) | [Realtime audio](#realtime-audio-priority) | Stutter-free PipeWire under load |
| | [Show-desktop](#show-desktop) | Minimizes even Wine windows |
| | [Fullscreen zoom](#fullscreen-zoom) | Super+plus/minus magnifier |
| | [Smart charge](#smart-charge) | Conservation-mode helper |
| | [OSD badges](#osd-badge-engine) | Cached icon engine behind every HUD |

### Brightness

![brightness OSD](screenshots/osd-brightness.png)

<details>
<summary>Read more</summary>

`XF86MonBrightnessUp/Down` (`sbin/brightness-step`) step through 20 stops
tuned for the panel
(`1 2 3 5 8 13 21 34 47 70 101 142 193 253 324 403 492 589 693 800` at
max 800): exponential at the dark end, blended toward linear at the top so
jumps stay small. The OSD shows the preset number (`12/20`) with an even
bar instead of a misleading linear hardware percentage. Other `max`
values are auto-scaled.

</details>

### Volume

![volume OSD](screenshots/osd-volume.png)
![volume low](screenshots/osd-volume-low.png)
![volume muted](screenshots/osd-volume-muted.png)

<details>
<summary>Read more</summary>

`XF86Audio*` keys (`bin/xfce-pipewire-volume`) drive PipeWire via a single
`wpctl` roundtrip per press (no lag on key repeat), with an icon-only
badge (glyph + exact percent + bar, up to 200% overdrive).

</details>

### Microphone

![mic muted](screenshots/feat-mic-muted.png)
![mic live](screenshots/feat-mic-live.png)

<details>
<summary>Read more</summary>

`bin/mic-toggle` flips the default source mute and shows a muted/unmuted
notification.

</details>

### Screenshots

![screenshot](screenshots/feat-screenshot.png)

<details>
<summary>Read more</summary>

`Print` (`bin/rect-screenshot-clipboard` + `libexec/screenshot-cropper`)
freezes the screen first, so open (context) menus stay visible, then crops
on the frozen image:

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

</details>

### Charger & battery guard

![charger plugged](screenshots/osd-charger.png)
![on battery](screenshots/osd-battery.png)

<details>
<summary>Read more</summary>

A 30 s timer (`bin/battery-guard`) watches the battery: charger
plug/unplug notifications with charge badges, and at ≤18% on battery a
fullscreen **plug-in-charger countdown**
(`sbin/battery-shutdown-countdown`) to hibernation. While the countdown is
up it pauses MPRIS players (Firefox, Spotify, …) over D-Bus, and resumes
exactly the players it paused when the charger is plugged in — never on
the hibernate path. Test mode (`--test`) skips media handling.

</details>

### Headphone auto-switch

![headset](screenshots/feat-headphones.png)

<details>
<summary>Read more</summary>

`bin/audio-output-autoswitch` keeps the default sink and existing streams
on the connected headset. Fixes two races in naive switchers: the default
is set via WirePlumber *before* moving existing streams (so new streams
can't briefly play through the speakers), and during Bluetooth
profile/codec renegotiation — when the sink briefly disappears while the
headset stays connected — playback is *not* bounced to the speakers.
Wired plug/unplug is handled through the ALSA fallback. Runs as
`audio-output-autoswitch.service`, reacting to `pactl subscribe`
sink/sink-input events.

Configure your headset in `~/.config/XFCETweaks/audio.conf`
(`HEADSET_ADDRESS` + `HEADSET_TOKEN`, see `config/audio.conf.example`);
with empty values only the wired path is active.

</details>

### Mic quality guard

<details>
<summary>Read more</summary>

`bin/mic-quality-setup` (`mic-quality.service --watch`) pins mic levels
(boosts off, capture 50%), keeps the `voice_clear` filter fed by the real
microphone only, and routes app recordings to it.

</details>

### Realtime audio priority

<details>
<summary>Read more</summary>

`bin/pipewire-rt-guard` (`pipewire-rt-guard.service`) plus the
`systemd/user/{pipewire,pipewire-pulse,wireplumber}.service.d/` drop-ins
give PipeWire data loops realtime priority so audio never stutters under
load.

</details>

### Show-desktop

<details>
<summary>Read more</summary>

`bin/toggle-desktop` implements show-desktop window-by-window, so Wine
windows (Mailbird) minimize and restore correctly (the EWMH broadcast is
ignored by Wine and xfwm4 cancels it on touch).

</details>

### Fullscreen zoom

<details>
<summary>Read more</summary>

`bin/xfwm-fullscreen-zoom` — Super+plus/minus magnifier.

</details>

### Smart charge

<details>
<summary>Read more</summary>

`bin/smart-charge` — Lenovo conservation-mode helper
(`on`/`off`/`toggle`/`status`).

</details>

### OSD badge engine

<details>
<summary>Read more</summary>

`bin/osd-badge` generates and caches every HUD badge icon (glyph + text),
rebuilding `icon-theme.cache` whenever a new icon name appears so
notifications never show a broken icon.

</details>

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
`sbin/` → `/usr/local/bin` (sudo), enables the user units, applies
keybindings via `xfconf/apply.sh`, and refreshes the icon cache. Set
`SKIP_APT=1` to skip the apt step.

Requirements and notes:

- X11 session (uses `xdotool`, `xprop`, `wmctrl`, GDK X11 grabs).
- Brightness needs a sysfs backlight (here `nvidia_wmi_ec_backlight`,
  max 800 — other max values are auto-scaled) plus
  `xfpm-power-backlight-helper` from `xfce4-power-manager`.
- The hibernate countdown calls `sudo -n systemctl hibernate`; allow it
  passwordless if wanted, otherwise it falls back to suspend.
- Log out/in after install if keybindings lag.

## Layout

```
bin/            user keybinding scripts (~/.local/bin)
libexec/        screenshot cropper + clipboard owner (~/.local/libexec)
sbin/           root helpers: brightness-step, battery-shutdown-countdown
systemd/user/   battery, audio, mic and rt-priority units + PipeWire drop-ins
config/         audio.conf.example (headset address for auto-switch)
xfconf/         apply.sh + reference dumps of current settings
screenshots/    OSD badge samples used above
```

## License

MIT — see LICENSE.
