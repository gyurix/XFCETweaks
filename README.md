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
| | [dGPU control](#dgpu-control) | `gpu on/off/auto` + per-launch pinning |
| | [Hibernate](#hibernate) | `hibernate` with preflight checks + one-shot setup |
| | [Show-desktop](#show-desktop) | Minimizes even Wine windows |
| | [Fullscreen zoom](#fullscreen-zoom) | Super+plus/minus magnifier |
| | [Smart charge](#smart-charge) | Conservation-mode helper |
| | [OSD badges](#osd-badge-engine) | Cached icon engine behind every HUD |
| | [Icon theme guard](#icon-theme-guard) | Stops missing system icons (start menu, apps) |
| | [Terminal fonts](#terminal-fonts) | Braille + shape fallbacks so opencode spinners never show tofu |

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

`charger-watch.service` (`bin/charger-watch`) listens to udev
`power_supply` events and runs `bin/battery-guard` the moment the charger
is plugged or unplugged, with the 30 s timer kept as a safety net. The guard reads the AC/USB-C mains
`online` flag as source of truth (not the battery `status`, which flips
through `Not charging`/`Full`/conservation states), debounces EC flaps,
and notifies charger plug/unplug with charge badges. At ≤18% on battery
a fullscreen **plug-in-charger countdown**
(`sbin/battery-shutdown-countdown`) to hibernation appears; it also exits
early on charger plug via a sysfs cross-check when UPower lags. While the
countdown is up it pauses MPRIS players (Firefox, Spotify, …) over D-Bus,
and resumes exactly the players it paused when the charger is plugged
in — never on the hibernate path. Test mode (`--test`) skips media
handling.

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

`bin/xfwm-fullscreen-zoom` — Super+plus/minus magnifier (`Super+=`,
`Super+-`, `Super+KP_Add/KP_Subtract`) on top of the xfwm4 compositor zoom.
xfwm4 only zooms on wheel clicks whose modifiers are *exactly* its
`easy_click` modifier (Alt by default), so the helper swaps the held
Super for `easy_click`, injects `ZOOM_STEPS` (default 3, each 1/16 of the
scale) wheel clicks, waits for xfwm4's sync pointer grab to consume each
one, then restores Super if it is still physically held — while a wheel
button is down, so xcape's Super-tap (Whisker menu) doesn't fire. One
Python process over XTest (~100 ms under load vs. 400+ ms for the old
xdotool pair).

</details>

### dGPU control

<details>
<summary>Read more</summary>

`bin/gpu` + `sbin/gpu-power` manage the RTX 5070 Laptop GPU on this host:

- `gpu off` — keep the dGPU on the host but allow runtime suspension when idle;
  new launches prefer the Intel iGPU. Existing dGPU clients remain active.
- `gpu host` — host-only, powered-on dGPU for host apps.
- `gpu vm` — exclusive PCI passthrough of GPU and HDMI audio to the stopped
  `tiny10` libvirt VM. Refuses while Xorg or other processes use the GPU;
  switch from a text console or SSH and stop `lightdm` after saving work.
  Never kills clients itself.
- `gpu on` — host owns the dGPU, VMs keep their virtual display. For Linux
  VMs, VirtIO-GPU/VirGL can share host 3D rendering if configured separately;
  Tiny10's current Windows VirtIO GPU driver lacks stable VirGL 3D support,
  so its QXL virtual display is 2D in this mode.
- `gpu auto` — alias for `gpu off`.
- `gpu status` — mode, PCI power state, draw, dGPU clients.
- `gpu run [--dgpu|--igpu] -- <cmd>` — launch pinned to a GPU.

`tiny10` is a libvirt system VM with an 8 GiB RAM/8 vCPU definition,
96 GiB sparse qcow2 disk, UEFI, and a verified local copy of the USB Tiny10
ISO. Open it with `virt-manager` (do not launch the GUI automatically), or
`sudo virsh -c qemu:///system start tiny10`. For NVIDIA acceleration run
`gpu vm` first, after stopping `lightdm` from a text console or SSH.
When done with passthrough, shut down the VM, run `gpu host`, then start
`lightdm`. A VM using only its virtual display may stay running when switching
between `gpu host`, `gpu on`, and `gpu off`. PCI passthrough is exclusive: it cannot
share the physical NVIDIA device with host apps. No mode migrates live
GL/Vulkan/CUDA contexts or force-closes processes.

</details>

### Hibernate

<details>
<summary>Read more</summary>

`bin/hibernate` hibernates the machine after preflight checks (swap ≥ RAM,
`resume=` kernel parameter, kernel hibernate support, Secure Boot off,
NVIDIA VRAM preservation). One-time setup (latest HWE kernel, btrfs-safe
swapfile, GRUB `resume=UUID`/`resume_offset=`, initramfs, NVIDIA PM
options, systemd hibernate policy):

```sh
sudo hibernate-setup --kernel
# reboot, then:
hibernate --check && hibernate
```

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

### Icon theme guard

<details>
<summary>Read more</summary>

GTK reads the directory list of `hicolor` from the first `index.theme` it
finds, and `~/.local/share/icons/hicolor/index.theme` wins over the system
one. A minimal user copy (needed for `gtk-update-icon-cache`) hides every
system `hicolor` directory it omits, e.g. `scalable/apps` holding the Mint
start-menu icon.

| Trigger | Action |
| --- | --- |
| Login | `hicolor-index-sync.service` runs once |
| User or system `index.theme` rewritten | `hicolor-index-sync.path` reruns it |

`bin/hicolor-index-sync` rewrites the user file as the system
`index.theme` plus sections for user-only size directories (Wine, app
installers), then rebuilds `icon-theme.cache`. Unchanged content is not
rewritten, so the path unit does not loop.

</details>

### Terminal fonts

<details>
<summary>Read more</summary>

opencode's loading animation is a braille spinner (`⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`,
U+2800–U+28FF) and its prompt scanner uses `⬥◆⬩⬪·■⬝` (U+2B25/U+2B29/
U+2B2A/U+2B1D have zero coverage in stock mono fonts — no installed
monospace font covers braille either, so terminals show tofu boxes).

`install.sh` installs `fonts-symbola fonts-noto-extra
fonts-jetbrains-mono`, drops `config/fontconfig/
10-xfcetweaks-terminal-fallback.conf` into
`~/.config/fontconfig/conf.d/` (monospace → JetBrains Mono + Symbola /
Noto Sans Symbols2 / DejaVu Sans fallback), and seeds
`~/.config/ghostty/config` with the same fallbacks when missing.
Restart Ghostty after install so it picks up the new fonts.

</details>

## Installation

```sh
git clone https://github.com/gyurix/XFCETweaks.git
cd XFCETweaks
./install.sh
```

`install.sh` installs packages (`xdotool wmctrl x11-utils imagemagick
libnotify-bin python3-gi python3-pil python3-dbus adwaita-icon-theme
fonts-dejavu fonts-symbola fonts-noto-extra fonts-jetbrains-mono
xfce4-power-manager upower pipewire-pulse wireplumber`),
copies `bin/` → `~/.local/bin`, `libexec/` → `~/.local/libexec`,
`sbin/` → `/usr/local/bin` (sudo), enables the user units, applies
keybindings via `xfconf/apply.sh`, and refreshes the icon cache. Set
`SKIP_APT=1` to skip the apt step.

Requirements and notes:

- X11 session (uses `xdotool`, `xprop`, `wmctrl`, GDK X11 grabs).
- Brightness needs a sysfs backlight (here `nvidia_wmi_ec_backlight`,
  max 800 — other max values are auto-scaled) plus
  `xfpm-power-backlight-helper` from `xfce4-power-manager`.
- The hibernate countdown and `hibernate` call `sudo -n systemctl
  hibernate`; `install.sh` allows that (plus the GPU/power helpers)
  passwordless via `sudoers.d/xfcetweaks-helpers`.
- Log out/in after install if keybindings lag.

## Layout

```
bin/            user keybinding scripts (~/.local/bin)
libexec/        screenshot cropper + clipboard owner (~/.local/libexec)
sbin/           root helpers: brightness-step, battery-shutdown-countdown,
                gpu-power, hibernate-setup
systemd/user/   battery, charger-watch, audio, mic and rt-priority units + PipeWire drop-ins
modprobe/       NVIDIA VRAM-preserve + D3cold PM options
sleep.conf.d/   systemd hibernation policy
sudoers.d/      passwordless sudo for the bundled helpers only
config/         audio.conf.example (headset address for auto-switch)
                fontconfig/ terminal monospace fallbacks (opencode spinners)
                ghostty/ font fallbacks for Ghostty
xfconf/         apply.sh + reference dumps of current settings
screenshots/    OSD badge samples used above
```

## License

MIT — see LICENSE.
