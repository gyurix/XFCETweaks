#!/usr/bin/env bash
# Applies the XFCETweaks xfconf settings: custom keybindings that point at
# the installed scripts, plus power-manager prefs (custom brightness-step
# handles the keys, so the built-in handler stays off).
set -euo pipefail

set_shortcut() { # $1 = property, $2 = command
    xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$1" -n -t string -s "$2"
}

set_wm() { # $1 = property, $2 = action (empty string disables the keysym)
    if [[ -z "$2" ]]; then
        xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/$1" -n -t string -s "empty"
    else
        xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/$1" -n -t string -s "$2"
    fi
}

# Copy every default binding into custom (once) so that setting
# /commands/custom/override keeps Alt+F2, Super+E, Super+R, ... alive.
# Without this, override=true hides any default not mirrored in custom
# (Alt+F1, Alt+Tab were lost that way). Super_L is deliberately excluded:
# xcape already turns a Super tap into Alt+F1, so keeping a custom Super_L
# binding as well fires whiskermenu twice (open+close flicker).
mirror_defaults() { # $1 = commands|xfwm4
    local prefix="$1" prop val custom base
    while IFS= read -r prop; do
        [[ "$prop" == /"$prefix"/default/* ]] || continue
        base="${prop#/"$prefix"/default/}"
        [[ "$base" == "Super_L" ]] && continue
        custom="/$prefix/custom/$base"
        xfconf-query -c xfce4-keyboard-shortcuts -p "$custom" >/dev/null 2>&1 && continue
        val="$(xfconf-query -c xfce4-keyboard-shortcuts -p "$prop" 2>/dev/null || true)"
        [[ -n "$val" ]] || continue
        if [[ "$prop" == */startup-notify ]]; then
            xfconf-query -c xfce4-keyboard-shortcuts -p "$custom" -n -t bool -s "$val"
        else
            xfconf-query -c xfce4-keyboard-shortcuts -p "$custom" -n -t string -s "$val"
        fi
    done < <(xfconf-query -c xfce4-keyboard-shortcuts -l 2>/dev/null)
}

mirror_defaults commands
mirror_defaults xfwm4

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
set_shortcut "<Super>d" "$HOME/.local/bin/toggle-desktop"
set_shortcut "<Control><Alt>d" "$HOME/.local/bin/toggle-desktop"
set_shortcut "<Super>l" "xflock4"
# Only xcape may open the menu on Super: it turns a tap into Alt+F1 while
# leaving Super-held combos (Super+D, Super+Tab) alone. A custom Super_L
# binding as well fires whiskermenu twice (open+close). Mint defaults point
# Alt+F1 at applicationsmenu (ugly old menu), so pin it to whiskermenu.
set_shortcut "<Alt>F1" "xfce4-popup-whiskermenu"
xfconf-query -c xfce4-keyboard-shortcuts -r -p "/commands/custom/Super_L" 2>/dev/null || true
for key in "<Super>equal" "<Super>KP_Add" "<Super><Shift>equal"; do
    set_shortcut "$key" "$HOME/.local/bin/xfwm-fullscreen-zoom in --held"
done
for key in "<Super>minus" "<Super>KP_Subtract" "<Super><Shift>minus"; do
    set_shortcut "$key" "$HOME/.local/bin/xfwm-fullscreen-zoom out --held"
done
xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/override -n -t bool -s true

# toggle-desktop replaces xfwm4's show-desktop; disable the built-in keys
# (which Wine ignores anyway) and make sure the window cycler survives the
# custom override. Missing xfwm4/custom Alt+Tab broke Alt+Tab.
set_wm "<Alt>Tab" "cycle_windows_key"
set_wm "<Alt><Shift>Tab" "cycle_reverse_windows_key"
set_wm "<Super>Tab" "switch_window_key"
set_wm "<Control><Alt>d" "empty"
set_wm "<Primary><Alt>d" "empty"
xfconf-query -c xfce4-keyboard-shortcuts -p /xfwm4/custom/override -n -t bool -s true

# xfwm-fullscreen-zoom drives the compositor zoom; pin it on instead of
# relying on xfwm4 defaults. easy_click is read live, so it is left alone.
xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s true
xfconf-query -c xfwm4 -p /general/zoom_desktop -n -t bool -s true
# Keep the thumbnail Alt+Tab switcher (ugly list appears when these flip).
xfconf-query -c xfwm4 -p /general/cycle_preview -n -t bool -s true
xfconf-query -c xfwm4 -p /general/cycle_tabwin_mode -n -t int -s 0

# Start menu must be Whisker (nice hover-switch categories), not the ugly
# old applicationsmenu. Only repair plugin-1 when it drifted; leave the
# rest of the user's panel layout (plugin-ids order, sizes) alone.
# Whisker 2.8 stores its settings in xfconf (the old whiskermenu-1.rc is
# migrated away), so set hover-switch there instead of the rc file.
PANEL_RESTART=0
if [[ "$(xfconf-query -c xfce4-panel -p /plugins/plugin-1 2>/dev/null || true)" == "applicationsmenu" ]]; then
    xfconf-query -c xfce4-panel -p /plugins/plugin-1 -s whiskermenu
    PANEL_RESTART=1
fi
xfconf-query -c xfce4-panel -p /plugins/plugin-1/hover-switch-category -n -t bool -s true
xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-icon -n -t string -s linuxmint-logo-ring-symbolic
xfconf-query -c xfce4-panel -p /plugins/plugin-1/show-button-title -n -t bool -s false
xfconf-query -c xfce4-panel -p /plugins/plugin-1/small -n -t bool -s false

# A crashed unique plugin can be removed from the panel's plugin-id array
# while its xfconf entry remains. Restore the power manager plugin instead
# of leaving the taskbar without a battery indicator.
power_plugin_id=""
while IFS= read -r prop; do
    [[ "$prop" == /plugins/plugin-* ]] || continue
    [[ "$prop" == */* ]] && continue
    if [[ "$(xfconf-query -c xfce4-panel -p "$prop" 2>/dev/null || true)" == "power-manager-plugin" ]]; then
        power_plugin_id="${prop##*-}"
        break
    fi
done < <(xfconf-query -c xfce4-panel -l 2>/dev/null)
if [[ -z "$power_plugin_id" ]]; then
    power_plugin_id=11
    xfconf-query -c xfce4-panel -p "/plugins/plugin-$power_plugin_id" -n -t string -s power-manager-plugin
fi
mapfile -t panel_ids < <(xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids 2>/dev/null |
    awk '/^[[:space:]]*[0-9]+[[:space:]]*$/ { print $1 }')
if ! printf '%s\n' "${panel_ids[@]}" | grep -qx "$power_plugin_id"; then
    panel_ids+=("$power_plugin_id")
    panel_id_args=(-a)
    for id in "${panel_ids[@]}"; do
        panel_id_args+=(-t int -s "$id")
    done
    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids "${panel_id_args[@]}"
    PANEL_RESTART=1
fi

# Super-tap opens Whisker via Alt+F1; make sure the autostart mapping and
# the daemon agree with the bindings above.
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/xcape.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=xcape-super-tap
Comment=Open Whisker menu on Super tap only, keep Super+D working
Exec=xcape -e 'Super_L=Alt_L|F1'
StartupNotify=false
Terminal=false
X-GNOME-Autostart-Enabled=true
EOF
if ! pgrep -x xcape >/dev/null 2>&1; then
    (setsid xcape -e 'Super_L=Alt_L|F1' >/dev/null 2>&1 < /dev/null &)
else
    pkill -x xcape 2>/dev/null || true
    (setsid xcape -e 'Super_L=Alt_L|F1' >/dev/null 2>&1 < /dev/null &)
fi

# Power manager: brightness keys handled by brightness-step, not internally.
# show-panel-label=1 forces the exact percentage next to the battery icon,
# including while charging (0 would hide the label entirely).
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/handle-brightness-keys -n -t bool -s false
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/show-brightness-popup -n -t bool -s false
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/brightness-step-count -n -t int -s 20
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/show-panel-label -n -t int -s 1

# PulseAudio panel plugin: drop Firefox from known-players so browser
# media never pops MPRIS notifications from the panel. Plugin ids shift
# when the layout changes, so find pulseaudio plugins dynamically.
while IFS= read -r prop; do
    [[ "$prop" == /plugins/plugin-* ]] || continue
    [[ "$prop" == */* ]] && continue
    if [[ "$(xfconf-query -c xfce4-panel -p "$prop" 2>/dev/null || true)" == "pulseaudio" ]]; then
        num="${prop#/plugins/plugin-}"
        xfconf-query -c xfce4-panel -r -p "/plugins/plugin-$num/known-players" 2>/dev/null || true
    fi
done < <(xfconf-query -c xfce4-panel -l 2>/dev/null)
# Also clear stale mpris/known-players keys left on recycled plugin ids
# (e.g. a clock that reused an old pulseaudio id still carries them).
while IFS= read -r prop; do
    case "$prop" in
        /plugins/plugin-*/known-players|/plugins/plugin-*/enable-mpris)
            val="$(xfconf-query -c xfce4-panel -p "$prop" 2>/dev/null || true)"
            if [[ "$val" == *firefox* ]]; then
                xfconf-query -c xfce4-panel -r -p "$prop" 2>/dev/null || true
            fi
            ;;
    esac
done < <(xfconf-query -c xfce4-panel -l 2>/dev/null)

if [[ "$PANEL_RESTART" == "1" ]]; then
    xfce4-panel -r >/dev/null 2>&1 &
fi

echo "xfconf settings applied."
