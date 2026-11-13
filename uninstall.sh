#!/usr/bin/env bash
# Undo install.sh: restore the original theme files, switch back to the stock blur, remove scripts and units.
# The compiled effect stays in /usr; the last lines print how to remove it.
#   ./uninstall.sh --no-reload   change files and settings only, do not touch the running session
set -uo pipefail
RELOAD=1; [ "${1:-}" = "--no-reload" ] && RELOAD=0
ID=better_blur_dx_local
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"; CONF="${XDG_CONFIG_HOME:-$HOME/.config}"; BIN="$HOME/.local/bin"
E="qdbus-qt6 org.kde.KWin /Effects org.kde.kwin.Effects"
for t in WhiteSur WhiteSur-dark; do
  for f in dialogs/background.svgz widgets/panel-background.svgz; do
    p="$DATA/plasma/desktoptheme/$t/$f"
    [ -e "$p.pre-liquid-glass" ] && mv -f "$p.pre-liquid-glass" "$p" && echo "restored $p"
  done
done
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/ksvg-elements"
[ "$RELOAD" = 1 ] && systemctl --user disable --now macos-theme-sync.path 2>/dev/null
rm -f "$CONF/systemd/user/macos-theme-sync.path" "$CONF/systemd/user/macos-theme-sync.service" \
      "$CONF/autostart/glass-blur-guard.desktop" "$DATA/applications/net.local.theme-toggle.desktop" \
      "$BIN/macos-theme-toggle" "$BIN/glass-blur-guard" "$BIN/glass-blur-rebuild"
[ "$RELOAD" = 1 ] && systemctl --user daemon-reload 2>/dev/null
kwriteconfig6 --file kwinrc --group Plugins --key "${ID}Enabled" false
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true
if [ "$RELOAD" = 1 ] && command -v qdbus-qt6 >/dev/null; then
  $E.unloadEffect "$ID" >/dev/null 2>&1; sleep 2; $E.loadEffect blur >/dev/null 2>&1
  qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1
  systemctl --user restart plasma-plasmashell.service 2>/dev/null
fi
SRC="$DATA/plasma-liquid-glass/kwin-effect"
echo
echo "Stock blur is back on. Glass settings remain in kwinrc ([Effect-better-blur-dx]) but are unused;"
echo "your kwinrc from before the install is at $CONF/kwinrc.pre-liquid-glass."
[ -f "$SRC/build/install_manifest.txt" ] && echo "To remove the compiled effect:  sudo xargs rm -f < $SRC/build/install_manifest.txt"
echo "To remove the source:           rm -rf $DATA/plasma-liquid-glass"
