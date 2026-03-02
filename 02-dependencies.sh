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
    xorg xserver-xorg x11-xserver-utils
    xserver-xorg-input-all
    xinit xauth

    # OpenBox window manager
    openbox

    # Terminal emulator (chromeless config applied in 07-openbox.sh)
    # We use xterm — lightweight, configurable, no deps chain
    xterm

    # Unclutter — hides idle mouse cursor
    unclutter

    # Screen / display tools
    x11-utils x11-xkb-utils
    xdotool xrandr

    # Fonts needed by EmulationStation
    fonts-dejavu fonts-freefont-ttf
    fonts-liberation

    # RetroPie/ES runtime deps
    libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-mixer-2.0-0
    libsdl2-ttf-2.0-0 libsdl2-net-2.0-0
    libboost-all-dev
    libfreeimage-dev
    libcurl4-openssl-dev
    libvlc-dev vlc-plugin-base
    libpugixml-dev

    # OpenGL / GLES (Mesa)
    mesa-utils mesa-utils-extra
    libgl1-mesa-dri libgles2
    libglu1-mesa

    # Audio (PulseAudio / ALSA bridge for emulators)
    pulseaudio-module-x11

    # Input
    xinput evtest

    # Image support
    feh imagemagick

    # Needed for RetroPie build scripts
    libgbm-dev libegl-dev
)

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${GUI_PACKAGES[@]}"
info "GUI packages installed ✓"

# ── Create Xorg config directory ──────────────────────────────────────────────
mkdir -p /etc/X11/xorg.conf.d

# ── Basic Xorg config for 1080p output ────────────────────────────────────────
info "Writing Xorg display config (${DISPLAY_WIDTH}x${DISPLAY_HEIGHT})..."
cat > /etc/X11/xorg.conf.d/10-monitor.conf << EOF
# mediacade — Monitor configuration
# Managed by mediacade setup scripts — do not edit manually

Section "Monitor"
    Identifier  "Monitor0"
    $([ -n "${DISPLAY_OUTPUT:-}" ] && echo "Option  \"PreferredMode\"  \"${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}\"")
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
    Option "BlankTime"  "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime"    "0"
    Option "DontZap"    "true"
EndSection
EOF

# ── Disable screen blanking / DPMS system-wide ────────────────────────────────
info "Disabling screen blanking..."
cat > /etc/X11/xorg.conf.d/11-nodpms.conf << 'EOF'
Section "Extensions"
    Option "DPMS" "Disable"
EndSection
EOF

# ── xinit / startx wrapper ────────────────────────────────────────────────────
# .xinitrc is written by 07-openbox.sh — this just ensures startx works
info "Ensuring startx is available..."
if ! command -v startx &>/dev/null; then
    error "startx not found after installing xinit. Something went wrong."
fi

info "GUI dependencies installed ✓"
