#!/usr/bin/env bash
# XFCETweaks installer. Copies user scripts, root helpers, systemd units,
# udev rules and xfconf keybindings. Safe to re-run.
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
install -m 0644 "$REPO"/systemd/user/* "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable --now battery-guard.timer
systemctl --user enable battery-hibernate-countdown.service || true

echo "==> udev rule for FnLock (needs reboot or replug to take effect)"
sudo install -m 0644 "$REPO"/udev/99-fnlock.rules /etc/udev/rules.d/99-fnlock.rules
sudo udevadm control --reload-rules || true

echo "==> xfconf keybindings and power-manager settings"
"$REPO"/xfconf/apply.sh

echo "==> Refresh icon cache"
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo "Done. Log out/in if FnLock permissions or keybindings do not apply yet."
