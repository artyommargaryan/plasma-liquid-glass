#!/usr/bin/env bash
# plasma-liquid-glass installer. Run as your normal user in a Plasma 6 Wayland session; asks for sudo
# only to install build dependencies (Fedora), the compiled KWin effect, the menu style plugin and the dock widget.
#   ./install.sh                 everything
#   ./install.sh --skip-effect   theme files, scripts and settings only (effect already installed)
#   ./install.sh --skip-deps     do not try to install build dependencies
#   ./install.sh --no-reload     do not touch the running session (no shell restart, no effect load)
#   ./install.sh --layout        also REPLACE your panels with a top bar and a floating dock on every screen
#                                (previous layout is saved; ./uninstall.sh --restore-layout brings it back)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKIP_EFFECT=0; SKIP_DEPS=0; RELOAD=1; LAYOUT=0
for a in "$@"; do case "$a" in
  --skip-effect) SKIP_EFFECT=1 ;; --skip-deps) SKIP_DEPS=1 ;; --no-reload) RELOAD=0 ;; --layout) LAYOUT=1 ;;
  -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "unknown option: $a" >&2; exit 2 ;;
esac; done

ID=better_blur_dx_local
EFFECT_REPO="${GLASS_EFFECT_REPO:-https://github.com/artyommargaryan/kwin-effects-better-blur-dx.git}"
EFFECT_BRANCH="${GLASS_EFFECT_BRANCH:-glass}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
SRC="$DATA/plasma-liquid-glass/kwin-effect"
BIN="$HOME/.local/bin"
E="qdbus-qt6 org.kde.KWin /Effects org.kde.kwin.Effects"
say()  { printf '\n== %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v kwriteconfig6 >/dev/null || die "kwriteconfig6 not found - this needs KDE Plasma 6"
command -v kwin_wayland  >/dev/null || die "kwin_wayland not found - this needs Plasma 6 on Wayland"
QDBUS=1; command -v qdbus-qt6 >/dev/null || { QDBUS=0; warn "qdbus-qt6 not found (Fedora: qt6-qttools); the session will not be reloaded"; RELOAD=0; }

QT_PLUGINS="$(qtpaths6 --query QT_INSTALL_PLUGINS 2>/dev/null || true)"

# ---- 1. the KWin effect ----------------------------------------------------------------------------------------
if [ "$SKIP_EFFECT" = 0 ]; then
  if [ "$SKIP_DEPS" = 0 ]; then
    if command -v dnf >/dev/null; then
      say "Installing build dependencies with dnf (sudo)"
      sudo dnf -y install git cmake extra-cmake-modules gcc-c++ kwin-devel kf6-kwindowsystem-devel plasma-workspace-devel \
        libplasma-devel qt6-qtbase-private-devel qt6-qtbase-devel kf6-knotifications-devel kf6-kio-devel kf6-kcrash-devel \
        kf6-ki18n-devel kf6-kguiaddons-devel libepoxy-devel kf6-kglobalaccel-devel kf6-kcmutils-devel \
        kf6-kconfigwidgets-devel kf6-kdeclarative-devel kdecoration-devel wayland-devel libdrm-devel \
        libksysguard-devel plasma-activities-devel plasma-activities-stats-devel kf6-kxmlgui-devel kf6-kservice-devel
    else
      warn "not a dnf system: install the build dependencies listed in the effect's README yourself, then re-run with --skip-deps"
      warn "  https://github.com/artyommargaryan/kwin-effects-better-blur-dx#building-from-source"
    fi
  fi
  say "Fetching the effect source into $SRC"
  if [ -d "$SRC/.git" ]; then git -C "$SRC" fetch -q origin "$EFFECT_BRANCH" && git -C "$SRC" checkout -q "$EFFECT_BRANCH" && git -C "$SRC" merge -q --ff-only "origin/$EFFECT_BRANCH"
  else mkdir -p "$(dirname "$SRC")"; git clone -q -b "$EFFECT_BRANCH" "$EFFECT_REPO" "$SRC"; fi
  say "Building"
  cmake -S "$SRC" -B "$SRC/build" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release >/dev/null
  cmake --build "$SRC/build" -j"$(nproc)"
  say "Installing the effect (sudo)"
  sudo cmake --install "$SRC/build"

  # ---- 1b. the menu style ("LiquidGlass" = Kvantum with the menu panel drawn by menu-style/) --------------------
  say "Building the menu style"
  MS="$DATA/plasma-liquid-glass/menu-style-build"
  if [ -n "$QT_PLUGINS" ] \
     && cmake -S "$HERE/menu-style" -B "$MS" -DCMAKE_BUILD_TYPE=Release -DMENU_STYLE_PLUGIN_DIR="$QT_PLUGINS/styles" >/dev/null \
     && cmake --build "$MS" -j"$(nproc)"; then
    say "Installing the menu style (sudo)"
    sudo cmake --install "$MS" || warn "menu style not installed - menus stay plain Kvantum"
  else warn "could not build the menu style (needs Qt 6 and KWindowSystem headers, qtpaths6) - menus stay plain Kvantum"; fi

  # ---- 1c. the dock widget (Plasma's task manager with hover magnification, dock/) --------------------------------
  # Its sources are Plasma 6.8's; another Plasma version gets the stock widget instead.
  case "$(plasmashell --version 2>/dev/null)" in
    *" 6.8."*)
      say "Building the dock widget"
      DK="$DATA/plasma-liquid-glass/dock-build"
      if cmake -S "$HERE/dock" -B "$DK" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev >/dev/null \
         && cmake --build "$DK" -j"$(nproc)"; then
        say "Installing the dock widget (sudo)"
        sudo cmake --install "$DK" || warn "dock widget not installed - the stock task manager is used"
      else warn "could not build the dock widget (see dock/README.md) - the stock task manager is used"; fi ;;
    *) warn "dock widget skipped: it is built for Plasma 6.8 ($(plasmashell --version 2>/dev/null)) - the stock task manager is used" ;;
  esac
fi
MENU_STYLE=0; [ -n "$QT_PLUGINS" ] && [ -f "$QT_PLUGINS/styles/libliquidglassstyle.so" ] && MENU_STYLE=1

# ---- 2. theme files --------------------------------------------------------------------------------------------
say "Installing theme files"
THEMES_DONE=0
for t in WhiteSur WhiteSur-dark; do
  dst="$DATA/plasma/desktoptheme/$t"
  if [ ! -d "$dst" ]; then
    if [ -d "/usr/share/plasma/desktoptheme/$t" ]; then
      mkdir -p "$(dirname "$dst")"; cp -r "/usr/share/plasma/desktoptheme/$t" "$dst"; echo "copied system theme $t to $dst"
    else warn "Plasma theme $t is not installed - skipped (get it from https://github.com/vinceliuice/WhiteSur-kde)"; continue; fi
  fi
  for f in dialogs/background.svgz widgets/panel-background.svgz; do
    mkdir -p "$dst/$(dirname "$f")"
    # keep the very first original only, so re-running the installer never overwrites it
    [ -e "$dst/$f" ] && [ ! -e "$dst/$f.pre-liquid-glass" ] && cp "$dst/$f" "$dst/$f.pre-liquid-glass"
    cp "$HERE/theme/$t/$f" "$dst/$f"
  done
  echo "installed $t"; THEMES_DONE=1
done
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/ksvg-elements"

# ---- 2a. Launchpad and Control Center widgets (pure QML, nothing to compile) -----------------------------------------------------------
mkdir -p "$DATA/plasma/plasmoids"; rm -rf "$DATA/plasma/plasmoids/org.liquidglass.launchpad"
cp -r "$HERE/launchpad" "$DATA/plasma/plasmoids/org.liquidglass.launchpad"; echo "installed the Launchpad widget"
rm -rf "$DATA/plasma/plasmoids/org.liquidglass.controlcenter"
cp -r "$HERE/controlcenter" "$DATA/plasma/plasmoids/org.liquidglass.controlcenter"; echo "installed the Control Center widget"

# ---- 2b. application menus (Kvantum) -----------------------------------------------------------------------------
# Menus are drawn by Kvantum, not by the Plasma theme: give the WhiteSur Kvantum theme a matching glass menu frame.
say "Setting up Kvantum menus"
KV="$CONF/Kvantum/WhiteSur"
if [ ! -d "$KV" ] && [ -d /usr/share/Kvantum/WhiteSur ]; then
  mkdir -p "$CONF/Kvantum"; cp -r /usr/share/Kvantum/WhiteSur "$KV"; echo "copied system Kvantum theme WhiteSur to $KV"
fi
if ! command -v python3 >/dev/null; then warn "python3 not found - Kvantum menus left as they are"
elif [ ! -d "$KV" ]; then warn "Kvantum theme WhiteSur is not installed - menus left as they are (get it from https://github.com/vinceliuice/WhiteSur-kde)"
else
  for v in WhiteSur WhiteSurDark; do
    svg="$KV/$v.svg"; cfg="$KV/$v.kvconfig"
    { [ -f "$svg" ] && [ -f "$cfg" ]; } || { warn "$v.svg / $v.kvconfig missing in $KV - skipped"; continue; }
    for f in "$svg" "$cfg"; do [ -e "$f.pre-liquid-glass" ] || cp "$f" "$f.pre-liquid-glass"; done
    # body tint = the popup frame of the matching Plasma theme; the light theme's popups are dark glass with light text
    if [ "$v" = WhiteSurDark ]; then fill='#1c1c1e'; op=0.18; textopt=""; else fill='#f4f4f4'; op=0.16; textopt="--light-text"; fi
    if KV_FILL="$fill" KV_FILLOP="$op" python3 "$HERE/tools/kv_menu.py" 8 "$svg.pre-liquid-glass" "$svg.new" 0 0 4 >/dev/null \
       && python3 "$HERE/tools/kv_config.py" "$cfg.pre-liquid-glass" "$cfg.new" $textopt; then
      mv -f "$svg.new" "$svg"; mv -f "$cfg.new" "$cfg"; echo "menu frame installed in $v"
    else rm -f "$svg.new" "$cfg.new"; warn "could not adapt $v (unexpected theme version?) - left as it was"; fi
  done
fi

# ---- 2c. Global Themes -------------------------------------------------------------------------------------------
# Two entries for System Settings > Global Theme, registered as the light and dark theme of Plasma's Dark Mode
# switch. Picking one (or flipping the switch) changes colours, icons and the Plasma theme; the watcher installed
# below then brings Kvantum, GTK and the glass values in line.
say "Installing Global Themes"
mkdir -p "$DATA/plasma/look-and-feel" "$DATA/plasma-liquid-glass"
for d in "$HERE"/look-and-feel/*/; do
  n="$(basename "$d")"; rm -rf "$DATA/plasma/look-and-feel/$n"; cp -r "$d" "$DATA/plasma/look-and-feel/$n"; echo "installed $n"
  [ "$MENU_STYLE" = 1 ] && sed -i 's/^widgetStyle=kvantum$/widgetStyle=LiquidGlass/' "$DATA/plasma/look-and-feel/$n/contents/defaults"
done
if [ "$MENU_STYLE" = 1 ]; then
  [ -e "$DATA/plasma-liquid-glass/previous-widget-style" ] || kreadconfig6 --file kdeglobals --group KDE --key widgetStyle > "$DATA/plasma-liquid-glass/previous-widget-style"
  kwriteconfig6 --notify --file kdeglobals --group KDE --key widgetStyle LiquidGlass
fi
if [ ! -e "$DATA/plasma-liquid-glass/previous-global-themes" ]; then
  { echo "DefaultLightLookAndFeel=$(kreadconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel)"
    echo "DefaultDarkLookAndFeel=$(kreadconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel)"; } > "$DATA/plasma-liquid-glass/previous-global-themes"
fi
kwriteconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel org.liquidglass.whitesur
kwriteconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel org.liquidglass.whitesur-dark

# ---- 3. scripts, autostart, light/dark sync ---------------------------------------------------------------------
say "Installing scripts"
mkdir -p "$BIN" "$CONF/autostart" "$CONF/systemd/user" "$DATA/applications"
install -m 755 "$HERE/bin/macos-theme-toggle" "$HERE/bin/glass-blur-guard" "$HERE/bin/glass-blur-rebuild" "$BIN/"
cat > "$CONF/autostart/glass-blur-guard.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Glass blur guard
Comment=Warn and fall back to plain blur if the glass effect did not load (e.g. after a KWin update)
Exec=$BIN/glass-blur-guard
Icon=dialog-warning
NoDisplay=true
X-KDE-autostart-phase=2
EOF
cat > "$DATA/applications/net.local.theme-toggle.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Toggle WhiteSur Light/Dark
Exec=$BIN/macos-theme-toggle
Icon=preferences-desktop-theme
NoDisplay=true
StartupNotify=false
X-KDE-GlobalAccel-CommandShortcut=true
EOF
install -m 644 "$HERE/systemd/macos-theme-sync.path" "$HERE/systemd/macos-theme-sync.service" "$CONF/systemd/user/"
case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN is not on your PATH; add it to run glass-blur-rebuild and macos-theme-toggle by name" ;; esac

# ---- 4. settings -----------------------------------------------------------------------------------------------
say "Writing glass settings to kwinrc"
if [ ! -e "$CONF/kwinrc.pre-liquid-glass" ] && [ -e "$CONF/kwinrc" ]; then cp "$CONF/kwinrc" "$CONF/kwinrc.pre-liquid-glass"; fi
while IFS='=' read -r k v; do
  case "$k" in ''|'#'*) continue ;; esac
  kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key "$k" "$v"
done < "$HERE/glass-settings.conf"
# the menu style draws a 16px corner; plain Kvantum menus keep the 10px from glass-settings.conf
[ "$MENU_STYLE" = 1 ] && kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key MenuCornerRadius 16
kwriteconfig6 --file kwinrc --group Plugins --key "${ID}Enabled" true
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
case "$(kreadconfig6 --file kdeglobals --group General --key ColorScheme)" in *[Dd]ark*) mode=dark ;; *) mode=light ;; esac
[ "$mode" = light ] && kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key GlassLumaCeiling 35
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}"; echo "$mode" > "${XDG_STATE_HOME:-$HOME/.local/state}/macos-theme-mode"

# ---- 5. reload the session -------------------------------------------------------------------------------------
if [ "$RELOAD" = 1 ]; then
  say "Reloading"
  systemctl --user daemon-reload && systemctl --user enable --now macos-theme-sync.path || warn "could not enable macos-theme-sync.path"
  qdbus-qt6 org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  if [ "$($E.isEffectLoaded "$ID" 2>/dev/null)" = "true" ]; then
    $E.reconfigureEffect "$ID" >/dev/null 2>&1 || true
    [ "$SKIP_EFFECT" = 0 ] && echo "An older copy of the effect is loaded: log out and back in to use the new build."
  elif { $E.unloadEffect blur >/dev/null 2>&1 || true; sleep 2; [ "$($E.loadEffect "$ID" 2>/dev/null)" = "true" ]; }; then
    # stock blur is unloaded first on purpose: loading glass next to it leaves glass "loaded" but drawing nothing
    echo "glass effect loaded"
  else
    $E.loadEffect blur >/dev/null 2>&1 || true
    warn "KWin did not load the effect. Is kwin-devel the same version as kwin? Try logging out and back in, then: journalctl -b | grep -i better_blur"
  fi
  if [ "$LAYOUT" = 1 ]; then
    say "Replacing the panel layout"
    LB="$DATA/plasma-liquid-glass/layout-backup"
    if [ ! -d "$LB" ]; then
      mkdir -p "$LB"; cp "$CONF/plasma-org.kde.plasma.desktop-appletsrc" "$CONF/plasmashellrc" "$LB/" 2>/dev/null || true
      echo "previous layout saved in $LB"
    fi
    if ids="$(qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(cat "$HERE/layout/glass-layout.js")" 2>/dev/null)" \
       && printf '%s\n' "$ids" | grep -q '^bar [0-9]'; then
      # "applets only" floating and the translucent setting live in plasmashellrc and can only be written while
      # the shell is stopped (it rewrites the file on exit)
      systemctl --user stop plasma-plasmashell.service 2>/dev/null || kquitapp6 plasmashell 2>/dev/null || true; sleep 2
      printf '%s\n' "$ids" | while read -r kind id; do
        case "$kind" in
          bar)  kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $id" --key floating 0
                kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $id" --key floatingApplets 1
                kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $id" --key panelOpacity 2 ;;
          dock) kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $id" --key floating 1
                kwriteconfig6 --file plasmashellrc --group PlasmaViews --group "Panel $id" --key panelOpacity 2 ;;
        esac
      done
      echo "panels created: $(printf '%s' "$ids" | tr '\n' ' ')"
    else warn "the Plasma shell did not accept the layout script - panels left as they are"; fi
  fi
  # always (re)start the shell: it has to reconnect to the newly loaded effect, and pick up the new theme files
  systemctl --user restart plasma-plasmashell.service 2>/dev/null || { command -v kstart >/dev/null && kstart plasmashell >/dev/null 2>&1; } \
    || warn "restart the Plasma shell (or log out and in) to see the result"
else
  [ "$LAYOUT" = 1 ] && warn "--layout needs the running session; skipped because of --no-reload"
  echo "Session not reloaded (--no-reload). Log out and back in, then run: systemctl --user enable --now macos-theme-sync.path"
fi

echo
if [ "$LAYOUT" = 1 ] && [ "$RELOAD" = 1 ]; then
  echo "Done. Panels were replaced with a top bar and a dock per screen (undo: ./uninstall.sh --restore-layout)."
else
  cat <<EOF
Done. Your panels were not touched. For the intended look either re-run with --layout (replaces your panels,
keeps a backup) or set by hand (README, "Panel setup"):
  - dock: a bottom panel set to Floating, with "Fit content" width
  - top bar: Floating -> "Applets only", so popups get four round corners
EOF
fi
echo "After every KWin update run:  glass-blur-rebuild"
