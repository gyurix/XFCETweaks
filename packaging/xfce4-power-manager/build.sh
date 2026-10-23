#!/usr/bin/env bash
# Build xfce4-power-manager with "Battery preservation (80%)" and "Fast
# charge" switches in the panel plugin's battery menu (each shown only where
# the battery lists the EC "Long_Life" / "Fast" charge type; they call
# `smart-charge on|off` / `smart-charge fast on|off`).
#
#   ./build.sh              build the .debs into $OUT, change nothing
#   INSTALL=1 ./build.sh    also back up the stock .debs, install, restart panel
#
# Roll back with: sudo dpkg -i $OUT/orig/*.deb && xfce4-panel -r
# An apt upgrade of xfce4-power-manager* replaces the patched build; pin it
# with: sudo apt-mark hold xfce4-power-manager{,-data,-plugins}
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# make uses $INSTALL as the install program: keep our flag out of its env.
DO_INSTALL="${INSTALL:-0}"
unset INSTALL

# Run from a shell without DISPLAY (ssh, IDE agent), `xfce4-panel -r` and the
# xfconf/xcape calls silently miss the desktop: borrow the running panel's
# display so the panel really restarts with the new plugin/icons.
if [[ -z "${DISPLAY:-}" ]] && pid="$(pgrep -u "$(id -u)" -x xfce4-panel | head -n1)" && [[ -n "$pid" ]]; then
    while IFS= read -r -d '' kv; do
        case "$kv" in DISPLAY=*|XAUTHORITY=*) export "$kv" ;; esac
    done < "/proc/$pid/environ"
fi
BASE_VER="${BASE_VER:-4.18.3+mint1}"
NEW_VER="${BASE_VER}+fastcharge2"
MIRROR="${MIRROR:-http://packages.linuxmint.com/pool/upstream/x/xfce4-power-manager}"
OUT="${OUT:-${TMPDIR:-/tmp}/xfce4-power-manager-fastcharge}"
SRC="xfce4-power-manager_${BASE_VER}"

echo "==> Build dependencies"
sudo apt-get install -y dpkg-dev debhelper intltool xfce4-dev-tools pkg-config \
    libglib2.0-dev libgtk-3-dev libnotify-dev libpolkit-gobject-1-dev \
    libsystemd-dev libupower-glib-dev libx11-dev libxext-dev \
    libxfce4panel-2.0-dev libxfce4ui-2-dev libxfconf-0-dev

echo "==> Fetching Mint source ${BASE_VER}"
rm -rf "$OUT/build"
mkdir -p "$OUT/dl" "$OUT/build"
for ext in dsc tar.xz; do
    [[ -f "$OUT/dl/$SRC.$ext" ]] || curl -fsSL -o "$OUT/dl/$SRC.$ext" "$MIRROR/$SRC.$ext"
done
dpkg-source -x "$OUT/dl/$SRC.dsc" "$OUT/build/src" >/dev/null

echo "==> Applying charge-type-switches.patch"
patch -d "$OUT/build/src" -p1 < "$HERE/charge-type-switches.patch"
{
    printf 'xfce4-power-manager (%s) zena; urgency=medium\n\n' "$NEW_VER"
    printf '  * Panel plugin: add "Battery preservation (80%%)" and "Fast charge" switches\n'
    printf '    to the battery menu where the battery exposes the EC Long_Life / Fast\n'
    printf '    charge_types entries (toggles via smart-charge).\n\n'
    printf ' -- %s <%s>  %s\n\n' "$(git config user.name || echo XFCETweaks)" \
        "$(git config user.email || echo none@localhost)" "$(date -R)"
    cat "$OUT/build/src/debian/changelog"
} > "$OUT/build/src/debian/changelog.new"
mv "$OUT/build/src/debian/changelog.new" "$OUT/build/src/debian/changelog"

echo "==> Building"
( cd "$OUT/build/src" && dpkg-buildpackage -b -us -uc -nc >"$OUT/build.log" 2>&1 ) \
    || { tail -30 "$OUT/build.log"; echo "build failed, see $OUT/build.log" >&2; exit 1; }
rm -rf "$OUT/debs"; mkdir -p "$OUT/debs"
cp "$OUT"/build/xfce4-power-manager{,-data,-plugins}_"${NEW_VER}"_*.deb "$OUT/debs/"
echo "Built: $(ls "$OUT/debs" | tr '\n' ' ')"

[[ "$DO_INSTALL" == "1" ]] || { echo "Not installing (INSTALL=1 to install). Debs in $OUT/debs"; exit 0; }

echo "==> Backing up stock packages to $OUT/orig"
mkdir -p "$OUT/orig"
( cd "$OUT/orig" && apt-get download \
    "xfce4-power-manager=$BASE_VER" "xfce4-power-manager-data=$BASE_VER" \
    "xfce4-power-manager-plugins=$BASE_VER" ) \
    || { echo "could not back up the stock packages, aborting" >&2; exit 1; }

echo "==> Installing and restarting the panel"
sudo dpkg -i "$OUT"/debs/*.deb
xfce4-panel -r >/dev/null 2>&1 || true
