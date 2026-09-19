#!/usr/bin/env bash
# Applies the XFCETweaks xfconf settings: custom keybindings that point at
# the installed scripts, plus power-manager prefs (custom brightness-step
# handles the keys, so the built-in handler stays off).
set -euo pipefail

set_shortcut() { # $1 = property, $2 = command
    xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$1" -n -t string -s "$2"
}

set_shortcut "Print" "$HOME/.local/bin/rect-screenshot-clipboard region"
set_shortcut "<Shift>Print" "$HOME/.local/bin/rect-screenshot-clipboard full"
set_shortcut "<Primary>Print" "$HOME/.local/bin/rect-screenshot-clipboard menu"
set_shortcut "<Alt>Print" "$HOME/.local/bin/rect-screenshot-clipboard window"
set_shortcut "XF86AudioRaiseVolume" "$HOME/.local/bin/xfce-pipewire-volume up"
set_shortcut "XF86AudioLowerVolume" "$HOME/.local/bin/xfce-pipewire-volume down"
set_shortcut "XF86AudioMute" "$HOME/.local/bin/xfce-pipewire-volume mute"
set_shortcut "XF86AudioMicMute" "$HOME/.local/bin/mic-toggle"
set_shortcut "XF86MonBrightnessUp" "/usr/local/bin/brightness-step up"
set_shortcut "XF86MonBrightnessDown" "/usr/local/bin/brightness-step down"
set_shortcut "<Super>Escape" "$HOME/.local/bin/fnlock-toggle"
set_shortcut "<Primary><Alt>f" "$HOME/.local/bin/fnlock-toggle"
set_shortcut "<Super>d" "$HOME/.local/bin/toggle-desktop"
set_shortcut "<Control><Alt>d" "$HOME/.local/bin/toggle-desktop"
for key in "<Super>equal" "<Super>KP_Add" "<Super><Shift>equal"; do
    set_shortcut "$key" "$HOME/.local/bin/xfwm-fullscreen-zoom in --held"
done
for key in "<Super>minus" "<Super>KP_Subtract" "<Super><Shift>minus"; do
    set_shortcut "$key" "$HOME/.local/bin/xfwm-fullscreen-zoom out --held"
done
xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/override -n -t bool -s true

# Power manager: brightness keys handled by brightness-step, not internally.
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/handle-brightness-keys -n -t bool -s false
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/show-brightness-popup -n -t bool -s false
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/brightness-step-count -n -t int -s 20

echo "xfconf settings applied."
