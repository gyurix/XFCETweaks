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
        python3-gi python3-pil python3-dbus \
        adwaita-icon-theme fonts-dejavu \
        xfce4-power-manager upower \
        pipewire-pulse wireplumber
fi

echo "==> User scripts -> ~/.local/bin and ~/.local/libexec"
mkdir -p "$HOME/.local/bin" "$HOME/.local/libexec"
install -m 0755 "$REPO"/bin/* "$HOME/.local/bin/"
install -m 0755 "$REPO"/libexec/* "$HOME/.local/libexec/"
python3 -m compileall -q "$HOME/.local/bin/osd-badge" "$HOME/.local/libexec" || true

echo "==> Root helpers -> /usr/local/bin"
sudo install -m 0755 "$REPO"/sbin/brightness-step /usr/local/bin/brightness-step
sudo install -m 0755 "$REPO"/sbin/battery-shutdown-countdown /usr/local/bin/battery-shutdown-countdown

echo "==> systemd user units"
mkdir -p "$HOME/.config/systemd/user"
install -m 0644 "$REPO"/systemd/user/*.service "$HOME/.config/systemd/user/"
install -m 0644 "$REPO"/systemd/user/*.timer "$HOME/.config/systemd/user/"
for drop in pipewire.service.d pipewire-pulse.service.d wireplumber.service.d; do
    if [[ -d "$REPO/systemd/user/$drop" ]]; then
        mkdir -p "$HOME/.config/systemd/user/$drop"
        install -m 0644 "$REPO/systemd/user/$drop"/*.conf "$HOME/.config/systemd/user/$drop/"
    fi
done
systemctl --user daemon-reload
systemctl --user enable --now battery-guard.timer
systemctl --user enable --now audio-output-autoswitch.service
systemctl --user enable --now mic-quality.service
systemctl --user enable --now pipewire-rt-guard.service
systemctl --user enable battery-hibernate-countdown.service || true

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

echo "==> Refresh icon cache"
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "Done."
