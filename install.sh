#!/usr/bin/env bash
# plasma-liquid-glass installer. Run as your normal user in a Plasma 6 Wayland session; asks for sudo
# only to install build dependencies (Fedora) and the compiled KWin effect.
#   ./install.sh                 everything
#   ./install.sh --skip-effect   theme files, scripts and settings only (effect already installed)
#   ./install.sh --skip-deps     do not try to install build dependencies
#   ./install.sh --no-reload     do not touch the running session (no shell restart, no effect load)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SKIP_EFFECT=0; SKIP_DEPS=0; RELOAD=1
for a in "$@"; do case "$a" in
  --skip-effect) SKIP_EFFECT=1 ;; --skip-deps) SKIP_DEPS=1 ;; --no-reload) RELOAD=0 ;;
  -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

# ---- 1. the KWin effect ----------------------------------------------------------------------------------------
if [ "$SKIP_EFFECT" = 0 ]; then
  if [ "$SKIP_DEPS" = 0 ]; then
    if command -v dnf >/dev/null; then
      say "Installing build dependencies with dnf (sudo)"
      sudo dnf -y install git cmake extra-cmake-modules gcc-c++ kwin-devel kf6-kwindowsystem-devel plasma-workspace-devel \
        libplasma-devel qt6-qtbase-private-devel qt6-qtbase-devel kf6-knotifications-devel kf6-kio-devel kf6-kcrash-devel \
        kf6-ki18n-devel kf6-kguiaddons-devel libepoxy-devel kf6-kglobalaccel-devel kf6-kcmutils-devel \
        kf6-kconfigwidgets-devel kf6-kdeclarative-devel kdecoration-devel wayland-devel libdrm-devel
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
fi

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
  elif [ "$($E.loadEffect "$ID" 2>/dev/null)" = "true" ]; then
    $E.unloadEffect blur >/dev/null 2>&1 || true; echo "glass effect loaded"
  else
    warn "KWin did not load the effect. Is kwin-devel the same version as kwin? Try logging out and back in, then: journalctl -b | grep -i better_blur"
  fi
  [ "$THEMES_DONE" = 1 ] && { systemctl --user restart plasma-plasmashell.service 2>/dev/null || warn "restart the Plasma shell (or log out and in) to see the new theme files"; }
else
  echo "Session not reloaded (--no-reload). Log out and back in, then run: systemctl --user enable --now macos-theme-sync.path"
fi

cat <<EOF

Done. Two things to set by hand (see README, "Panel setup"):
  - dock: a bottom panel set to Floating, with "Fit content" width
  - top bar: Floating -> "Applets only", so popups get four round corners
After every KWin update run:  glass-blur-rebuild
EOF
