#!/usr/bin/env bash
# Undo install.sh: restore the original theme files, switch back to the stock blur, remove scripts and units.
# The compiled effect and the menu style plugin stay in /usr; the last lines print how to remove it.
#   ./uninstall.sh --no-reload        change files and settings only, do not touch the running session
#   ./uninstall.sh --restore-layout   also put back the panel layout saved by install.sh --layout
set -uo pipefail
RELOAD=1; RESTORE_LAYOUT=0
for a in "$@"; do case "$a" in --no-reload) RELOAD=0 ;; --restore-layout) RESTORE_LAYOUT=1 ;; *) echo "unknown option: $a" >&2; exit 2 ;; esac; done
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
# before the Kvantum files go back, so its backup of the one changed line is not applied to a restored file
[ -e "$DATA/plasma-liquid-glass/dolphin-backup/done" ] && "$(cd "$(dirname "$0")" && pwd)/tools/dolphin_finder.sh" restore
for v in WhiteSur WhiteSurDark; do
  for x in svg kvconfig; do
    p="$CONF/Kvantum/WhiteSur/$v.$x"
    [ -e "$p.pre-liquid-glass" ] && mv -f "$p.pre-liquid-glass" "$p" && echo "restored $p"
  done
done
PW="$DATA/plasma-liquid-glass/previous-widget-style"
if [ "$(kreadconfig6 --file kdeglobals --group KDE --key widgetStyle)" = LiquidGlass ]; then
  prev="$(cat "$PW" 2>/dev/null)"; [ -n "$prev" ] && [ "$prev" != LiquidGlass ] || prev=kvantum
  kwriteconfig6 --notify --file kdeglobals --group KDE --key widgetStyle "$prev"; echo "widget style back to $prev"
fi
rm -f "$PW"
# the Launchpad widget is removed only when no panel uses it, or that panel would lose its launcher
if grep -q 'plugin=org.liquidglass.launchpad' "$CONF/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null; then
  echo "Launchpad widget kept: a panel still uses it (swap it for another launcher, then remove $DATA/plasma/plasmoids/org.liquidglass.launchpad)"
else rm -rf "$DATA/plasma/plasmoids/org.liquidglass.launchpad"; fi
if grep -q 'plugin=org.liquidglass.systemmenu' "$CONF/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null; then
  echo "System Menu widget kept: a panel still uses it (remove it from the panel, then remove $DATA/plasma/plasmoids/org.liquidglass.systemmenu)"
else rm -rf "$DATA/plasma/plasmoids/org.liquidglass.systemmenu"; fi
if grep -q 'plugin=org.liquidglass.controlcenter' "$CONF/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null; then
  echo "Control Center widget kept: a panel still uses it (remove it from the panel, then remove $DATA/plasma/plasmoids/org.liquidglass.controlcenter)"
else rm -rf "$DATA/plasma/plasmoids/org.liquidglass.controlcenter"; fi
rm -rf "$DATA/plasma/look-and-feel/org.liquidglass.whitesur" "$DATA/plasma/look-and-feel/org.liquidglass.whitesur-dark"
PG="$DATA/plasma-liquid-glass/previous-global-themes"
if [ -f "$PG" ]; then
  while IFS='=' read -r k v; do
    case "$k" in DefaultLightLookAndFeel|DefaultDarkLookAndFeel)
      if [ -n "$v" ]; then kwriteconfig6 --file kdeglobals --group KDE --key "$k" "$v"; else kwriteconfig6 --file kdeglobals --group KDE --key "$k" --delete; fi ;;
    esac
  done < "$PG"
  rm -f "$PG"; echo "Global Themes removed, previous light/dark defaults restored"
fi
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
  LB="$DATA/plasma-liquid-glass/layout-backup"
  if [ "$RESTORE_LAYOUT" = 1 ] && [ -f "$LB/plasma-org.kde.plasma.desktop-appletsrc" ]; then
    # the shell rewrites both files when it exits, so they are put back while it is stopped
    systemctl --user stop plasma-plasmashell.service 2>/dev/null; sleep 2
    cp "$LB/plasma-org.kde.plasma.desktop-appletsrc" "$LB/plasmashellrc" "$CONF/" 2>/dev/null && echo "panel layout restored from $LB"
    systemctl --user start plasma-plasmashell.service 2>/dev/null
  else
    [ "$RESTORE_LAYOUT" = 1 ] && echo "no saved panel layout in $LB - panels left as they are"
    systemctl --user restart plasma-plasmashell.service 2>/dev/null
  fi
elif [ "$RESTORE_LAYOUT" = 1 ]; then echo "--restore-layout needs the running session; skipped because of --no-reload"
fi
SRC="$DATA/plasma-liquid-glass/kwin-effect"
echo
echo "Stock blur is back on. Glass settings remain in kwinrc ([Effect-better-blur-dx]) but are unused;"
echo "your kwinrc from before the install is at $CONF/kwinrc.pre-liquid-glass."
[ -f "$SRC/build/install_manifest.txt" ] && echo "To remove the compiled effect:  sudo xargs rm -f < $SRC/build/install_manifest.txt"
MSM="$DATA/plasma-liquid-glass/menu-style-build/install_manifest.txt"
[ -f "$MSM" ] && echo "To remove the menu style:       sudo xargs rm -f < $MSM"
DKM="$DATA/plasma-liquid-glass/dock-build/install_manifest.txt"
[ -f "$DKM" ] && echo "To remove the dock widget:      sudo xargs rm -f < $DKM   (first swap it for the stock Icons-Only Task Manager in your dock)"
GSM="$DATA/plasma-liquid-glass/glass-shape-build/install_manifest.txt"
[ -f "$GSM" ] && echo "To remove the glass-shape module: sudo xargs rm -f < $GSM"
echo "To remove the source:           rm -rf $DATA/plasma-liquid-glass"
