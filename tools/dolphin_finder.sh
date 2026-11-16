#!/usr/bin/env bash
# Gives Dolphin a Finder-like layout, or puts back what was there before.
#   tools/dolphin_finder.sh apply     glass sidebar with a solid file area, Finder-style toolbar, no status bar
#   tools/dolphin_finder.sh restore   undo it
# What "apply" changes (originals are kept in ~/.local/share/plasma-liquid-glass/dolphin-backup):
#   - WhiteSur Kvantum theme, light and dark: transparent_dolphin_view=false, so only the Places panel stays
#     translucent and the file area gets the solid view colour
#   - ~/.local/share/kxmlgui5/dolphin/dolphinui.rc: toolbar = back, forward, location, the three view modes,
#     sort, search, menu (Dolphin's own file with a higher version number, dolphin/dolphinui.rc here)
#   - dolphinrc: status bar off, toolbar buttons as icons only
# Restart Dolphin afterwards.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"; CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
B="$DATA/plasma-liquid-glass/dolphin-backup"; KV="$CONF/Kvantum/WhiteSur"; UI="$DATA/kxmlgui5/dolphin/dolphinui.rc"
case "${1:-}" in
apply)
  mkdir -p "$B"
  if [ ! -e "$B/done" ]; then   # first run only, so a second "apply" never saves our own files as the originals
    [ -e "$CONF/dolphinrc" ] && cp "$CONF/dolphinrc" "$B/dolphinrc"
    [ -e "$UI" ] && cp "$UI" "$B/dolphinui.rc"
    for v in WhiteSur WhiteSurDark; do
      grep -m1 '^transparent_dolphin_view=' "$KV/$v.kvconfig" > "$B/$v.hack" 2>/dev/null || true
    done
    : > "$B/done"
  fi
  for v in WhiteSur WhiteSurDark; do
    f="$KV/$v.kvconfig"; [ -f "$f" ] || { echo "warning: $f missing - sidebar glass skipped for $v" >&2; continue; }
    if grep -q '^transparent_dolphin_view=' "$f"; then sed -i 's/^transparent_dolphin_view=.*/transparent_dolphin_view=false/' "$f"
    elif grep -q '^\[Hacks\]' "$f"; then sed -i '/^\[Hacks\]/a transparent_dolphin_view=false' "$f"
    else printf '\n[Hacks]\ntransparent_dolphin_view=false\n' >> "$f"; fi
  done
  mkdir -p "$(dirname "$UI")"; cp "$HERE/dolphin/dolphinui.rc" "$UI"
  kwriteconfig6 --file dolphinrc --group General --key ShowStatusBar Disabled
  kwriteconfig6 --file dolphinrc --group MainWindow --group "Toolbar mainToolBar" --key ToolButtonStyle IconOnly
  echo "Dolphin: Finder-style layout applied - restart Dolphin to see it" ;;
restore)
  [ -e "$B/done" ] || { echo "nothing to restore"; exit 0; }
  if [ -e "$B/dolphinrc" ]; then cp "$B/dolphinrc" "$CONF/dolphinrc"; else rm -f "$CONF/dolphinrc"; fi
  if [ -e "$B/dolphinui.rc" ]; then cp "$B/dolphinui.rc" "$UI"; else rm -f "$UI"; fi
  for v in WhiteSur WhiteSurDark; do
    f="$KV/$v.kvconfig"; [ -f "$f" ] || continue
    if [ -s "$B/$v.hack" ]; then sed -i "s/^transparent_dolphin_view=.*/$(cat "$B/$v.hack")/" "$f"
    else sed -i '/^transparent_dolphin_view=/d' "$f"; fi
  done
  rm -rf "$B"; echo "Dolphin: previous layout restored - restart Dolphin" ;;
*) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
