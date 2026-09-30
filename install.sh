#!/usr/bin/env bash
# XFCETweaks installer. Copies user scripts, root helpers, systemd units
# and xfconf keybindings. Safe to re-run.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing packages (skip with SKIP_APT=1)"
if [[ "${SKIP_APT:-0}" != "1" ]]; then
    sudo apt-get update
    sudo apt-get install -y \
        xdotool wmctrl x11-utils imagemagick libnotify-bin \
        python3-gi python3-gi-cairo python3-pil python3-dbus \
        libxtst6 libxi6 \
        adwaita-icon-theme fonts-dejavu \
        fonts-symbola fonts-noto-extra fonts-jetbrains-mono \
        xfce4-power-manager xfce4-notifyd upower \
        pipewire-pulse wireplumber
fi

echo "==> Terminal fonts (opencode spinners: braille U+2800 + shapes U+2B00)"
mkdir -p "$HOME/.config/fontconfig/conf.d"
install -m 0644 "$REPO/config/fontconfig/10-xfcetweaks-terminal-fallback.conf" "$HOME/.config/fontconfig/conf.d/10-xfcetweaks-terminal-fallback.conf"
fc-cache -f >/dev/null 2>&1 || true
if [[ ! -f "$HOME/.config/ghostty/config" ]]; then
    mkdir -p "$HOME/.config/ghostty"
    cp "$REPO/config/ghostty/config" "$HOME/.config/ghostty/config"
    echo "Installed Ghostty font fallbacks (JetBrains Mono + Symbola for opencode spinners)."
else
    echo "Ghostty config exists, leaving ~/.config/ghostty/config untouched (see config/ghostty/config for opencode spinner fallbacks)."
fi

echo "==> User scripts -> ~/.local/bin and ~/.local/libexec"
mkdir -p "$HOME/.local/bin" "$HOME/.local/libexec"
find "$REPO/bin" -maxdepth 1 -type f -exec install -m 0755 {} "$HOME/.local/bin/" \;
find "$REPO/libexec" -maxdepth 1 -type f -exec install -m 0755 {} "$HOME/.local/libexec/" \;
python3 -m compileall -q "$HOME/.local/bin/osd-badge" "$HOME/.local/libexec" || true

echo "==> Root helpers -> /usr/local/bin"
sudo install -m 0755 "$REPO"/sbin/brightness-step /usr/local/bin/brightness-step
sudo install -m 0755 "$REPO"/sbin/battery-shutdown-countdown /usr/local/bin/battery-shutdown-countdown
sudo install -m 0755 "$REPO"/sbin/gpu-power /usr/local/bin/gpu-power
sudo install -m 0440 "$REPO"/sudoers.d/xfcetweaks-gpu /etc/sudoers.d/xfcetweaks-gpu
sudo install -m 0755 "$REPO"/sbin/hibernate-setup /usr/local/bin/hibernate-setup

echo "==> udev / modprobe / sleep / sudoers config"
sudo install -m 0644 "$REPO"/modprobe/99-xfcetweaks-nvidia-pm.conf /etc/modprobe.d/99-xfcetweaks-nvidia-pm.conf
sudo mkdir -p /etc/systemd/sleep.conf.d
sudo install -m 0644 "$REPO"/sleep.conf.d/10-xfcetweaks-hibernate.conf /etc/systemd/sleep.conf.d/10-xfcetweaks-hibernate.conf
if [[ -d /etc/sudoers.d ]]; then
    sudo install -m 0440 "$REPO"/sudoers.d/xfcetweaks-helpers /etc/sudoers.d/xfcetweaks-helpers
    sudo visudo -c -q || sudo rm -f /etc/sudoers.d/xfcetweaks-helpers
fi

echo "==> systemd user units"
mkdir -p "$HOME/.config/systemd/user"
install -m 0644 "$REPO"/systemd/user/*.service "$HOME/.config/systemd/user/"
install -m 0644 "$REPO"/systemd/user/*.timer "$HOME/.config/systemd/user/"
install -m 0644 "$REPO"/systemd/user/*.path "$HOME/.config/systemd/user/"
# charger-watch.path + 99-charger-guard.rules never fired on plug/unplug
# (sysfs has no inotify; SYSTEMD_USER_WANTS ignores "change"); the udev
# monitor service below replaces both.
systemctl --user disable --now charger-watch.path 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/charger-watch.path"
if [[ -f /etc/udev/rules.d/99-charger-guard.rules ]]; then
    sudo rm -f /etc/udev/rules.d/99-charger-guard.rules
    sudo udevadm control --reload-rules || true
fi
for drop in pipewire.service.d pipewire-pulse.service.d wireplumber.service.d; do
    if [[ -d "$REPO/systemd/user/$drop" ]]; then
        mkdir -p "$HOME/.config/systemd/user/$drop"
        install -m 0644 "$REPO/systemd/user/$drop"/*.conf "$HOME/.config/systemd/user/$drop/"
    fi
done
systemctl --user daemon-reload
systemctl --user enable --now battery-guard.timer
systemctl --user enable --now charger-watch.service
systemctl --user enable --now audio-output-autoswitch.service
systemctl --user enable --now mic-quality.service
systemctl --user enable --now pipewire-rt-guard.service
systemctl --user enable --now hicolor-index-sync.path
systemctl --user enable hicolor-index-sync.service
# Started on demand by battery-guard at <=18%; never at login (its
# --trigger ExecStart would open the hibernate countdown immediately).
systemctl --user disable battery-hibernate-countdown.service 2>/dev/null || true

# Cleanup for machines that had the removed FnLock feature installed.
systemctl --user disable --now fnlock-watch.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/fnlock-watch.service" \
    "$HOME/.local/bin/fnlock-watch" "$HOME/.local/bin/fnlock-toggle"
xfconf-query -c xfce4-keyboard-shortcuts -r -p "/commands/custom/<Super>Escape" 2>/dev/null || true
xfconf-query -c xfce4-keyboard-shortcuts -r -p "/commands/custom/<Primary><Alt>f" 2>/dev/null || true
if [[ -f /etc/udev/rules.d/99-fnlock.rules ]]; then
    echo "==> Removing obsolete FnLock udev rule"
    sudo rm -f /etc/udev/rules.d/99-fnlock.rules
    sudo udevadm control --reload-rules || true
fi

if [[ ! -f "$HOME/.config/XFCETweaks/audio.conf" ]]; then
    mkdir -p "$HOME/.config/XFCETweaks"
    cp "$REPO/config/audio.conf.example" "$HOME/.config/XFCETweaks/audio.conf"
    echo "Created ~/.config/XFCETweaks/audio.conf - fill in HEADSET_ADDRESS/HEADSET_TOKEN for Bluetooth auto-switch."
fi

echo "==> xfconf keybindings and power-manager settings"
"$REPO"/xfconf/apply.sh

echo "==> Sync hicolor index and refresh icon cache"
"$HOME/.local/bin/hicolor-index-sync"
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "==> Notification daemon (all OSD/HUD goes through it)"
if ! pgrep -x xfce4-notifyd >/dev/null 2>&1; then
    setsid /usr/lib/x86_64-linux-gnu/xfce4/notifyd/xfce4-notifyd >/dev/null 2>&1 < /dev/null &
    sleep 1
fi
pgrep -x xfce4-notifyd >/dev/null && echo "    xfce4-notifyd running" || echo "    WARNING: xfce4-notifyd not running"

echo "Done."
echo ""
echo "Next steps (one time):"
echo "  gpu status            # dGPU power state + clients"
echo "  sudo hibernate-setup --kernel   # latest HWE kernel + swap + resume= config"
echo "  (reboot, then) hibernate --check && hibernate"
