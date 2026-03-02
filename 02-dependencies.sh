#!/usr/bin/env bash
# =============================================================================
# 02-dependencies.sh — Xorg, OpenBox, minimal GUI stack
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"
RETROPIE_HOME="$(getent passwd "${RETROPIE_USER}" | cut -d: -f6)"

info()  { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

# ── Xorg + OpenBox + Minimal GUI Stack ────────────────────────────────────────
info "Installing Xorg + OpenBox + GUI dependencies..."

GUI_PACKAGES=(
    # Xorg display server
    # Note: xrandr is provided by x11-xserver-utils — not a separate package
    xorg
    xserver-xorg
    x11-xserver-utils        # provides xrandr, xset, xdpyinfo, etc.
    xserver-xorg-input-all
    xinit
    xauth

    # OpenBox window manager
    openbox

    # Terminal emulator — lightweight, chromeless-configurable via .Xresources
    xterm

    # Unclutter — hides idle mouse cursor
    unclutter

    # X11 utilities
    x11-utils                # xwininfo, xprop, xdpyinfo
    x11-xkb-utils            # setxkbmap
    xdotool                  # window/input automation

    # Fonts needed by EmulationStation
    fonts-dejavu
    fonts-freefont-ttf
    fonts-liberation

    # RetroPie / EmulationStation runtime deps
    libsdl2-2.0-0
    libsdl2-image-2.0-0
    libsdl2-mixer-2.0-0
    libsdl2-ttf-2.0-0
    libsdl2-net-2.0-0
    libboost-all-dev
    libfreeimage-dev
    libcurl4-openssl-dev
    libvlc-dev
    vlc-plugin-base
    libpugixml-dev

    # OpenGL / GLES (Mesa)
    mesa-utils
    mesa-utils-extra
    libgl1-mesa-dri
    libgles2
    libglu1-mesa

    # Audio — Ubuntu 24.04 uses PipeWire; pipewire-pulse provides the
    # PulseAudio-compatible interface that RetroArch/emulators expect.
    # pulseaudio-module-x11 does not exist on Ubuntu 24.04.
    pipewire
    pipewire-pulse           # replaces pulseaudio-module-x11 on 24.04
    pipewire-alsa
    wireplumber              # PipeWire session manager

    # Input
    xinput
    evtest

    # Image support (used by splash/feh wallpaper)
    feh
    imagemagick

    # Needed for RetroPie build scripts
    libgbm-dev
    libegl-dev
)

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${GUI_PACKAGES[@]}"
info "GUI packages installed ✓"

# ── Enable PipeWire user service for the retropie user ───────────────────────
# PipeWire runs as a user service, not system-wide. We enable it so it
# starts automatically when the user session launches under startx.
info "Enabling PipeWire for ${RETROPIE_USER}..."
systemctl --user -M "${RETROPIE_USER}@.host" enable pipewire.socket \
    pipewire-pulse.socket wireplumber 2>/dev/null || \
    warn "PipeWire user service enable skipped (will auto-start at login)"

# ── Create Xorg config directory ──────────────────────────────────────────────
mkdir -p /etc/X11/xorg.conf.d

# ── Basic Xorg config for target resolution ───────────────────────────────────
info "Writing Xorg display config (${DISPLAY_WIDTH}x${DISPLAY_HEIGHT})..."
cat > /etc/X11/xorg.conf.d/10-monitor.conf << EOF
# mediacade — Monitor configuration
# Managed by mediacade setup scripts — do not edit manually

Section "Monitor"
    Identifier  "Monitor0"
$([ -n "${DISPLAY_OUTPUT:-}" ] && echo "    Option      \"PreferredMode\"  \"${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}\"")
    HorizSync   30-83
    VertRefresh 56-76
    Option      "DPMS" "true"
EndSection

Section "Screen"
    Identifier  "Screen0"
    Monitor     "Monitor0"
    DefaultDepth ${DISPLAY_DEPTH}
    SubSection "Display"
        Depth       ${DISPLAY_DEPTH}
        Modes       "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}" "1280x720" "1024x768"
    EndSubSection
EndSection

Section "ServerFlags"
    Option "BlankTime"   "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime"     "0"
    Option "DontZap"     "true"
EndSection
EOF

# ── Disable screen blanking / DPMS system-wide ────────────────────────────────
info "Disabling screen blanking..."
cat > /etc/X11/xorg.conf.d/11-nodpms.conf << 'EOF'
Section "Extensions"
    Option "DPMS" "Disable"
EndSection
EOF

# ── Verify startx is available ────────────────────────────────────────────────
info "Verifying startx..."
if ! command -v startx &>/dev/null; then
    error "startx not found after installing xinit. Something went wrong."
fi
info "startx available ✓"

info "GUI dependencies installed ✓"
