#!/usr/bin/env bash
# =============================================================================
# 04-autologin.sh — TTY autologin → startx → OpenBox → EmulationStation
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"
RETROPIE_HOME="$(getent passwd "${RETROPIE_USER}" | cut -d: -f6)"

info()  { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

# ── TTY1 Autologin via systemd getty override ─────────────────────────────────
info "Configuring TTY1 autologin for ${RETROPIE_USER}..."

GETTY_OVERRIDE_DIR="/etc/systemd/system/getty@tty1.service.d"
mkdir -p "$GETTY_OVERRIDE_DIR"
cat > "${GETTY_OVERRIDE_DIR}/autologin.conf" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${RETROPIE_USER} --noclear %I \$TERM
Type=simple
Restart=always
RestartSec=1
EOF

systemctl daemon-reload
systemctl enable getty@tty1.service
info "TTY1 autologin configured ✓"

# ── .bash_profile — launch X on TTY1 login ────────────────────────────────────
info "Writing .bash_profile for auto-startx..."
cat > "${RETROPIE_HOME}/.bash_profile" << 'BASHPROFILE'
# RetroPie-X86: auto-start X on TTY1
if [[ -z "$DISPLAY" ]] && [[ "$(tty)" == "/dev/tty1" ]]; then
    exec startx -- -nocursor 2>/tmp/xorg-startup.log
fi
BASHPROFILE
chown "${RETROPIE_USER}:${RETROPIE_USER}" "${RETROPIE_HOME}/.bash_profile"

# ── .xinitrc — startx entry point ─────────────────────────────────────────────
info "Writing .xinitrc..."
cat > "${RETROPIE_HOME}/.xinitrc" << 'XINITRC'
#!/bin/sh
# RetroPie-X86 .xinitrc
# Sets up the X environment and launches OpenBox

# Disable screen blanking & DPMS at X level
xset s off
xset -dpms
xset s noblank

# Set 1080p resolution if xrandr is available
# (DISPLAY_OUTPUT and resolution injected from config)
if command -v xrandr >/dev/null 2>&1; then
    if [ -n "$RETROPIE_OUTPUT" ] && [ -n "$RETROPIE_RES" ]; then
        xrandr --output "$RETROPIE_OUTPUT" --mode "$RETROPIE_RES" --rate "$RETROPIE_RATE" 2>/dev/null || true
    else
        # Auto: set preferred mode on all connected outputs
        xrandr --auto 2>/dev/null || true
    fi
fi

# Hide X cursor immediately (unclutter handles dynamic hiding)
if command -v unclutter >/dev/null 2>&1; then
    unclutter -idle "${UNCLUTTER_TIMEOUT:-3}" -root &
fi

# Start PulseAudio if not running
if command -v pulseaudio >/dev/null 2>&1; then
    pulseaudio --start --log-target=syslog 2>/dev/null || true
fi

# Launch OpenBox (which will exec EmulationStation via autostart)
exec openbox-session
XINITRC
chown "${RETROPIE_USER}:${RETROPIE_USER}" "${RETROPIE_HOME}/.xinitrc"
chmod 755 "${RETROPIE_HOME}/.xinitrc"

# ── Inject resolution env vars into user environment ─────────────────────────
ENVD_FILE="${RETROPIE_HOME}/.retropie-x86.env"
cat > "$ENVD_FILE" << EOF
# RetroPie-X86 environment — sourced by .bash_profile
export RETROPIE_RES="${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
export RETROPIE_RATE="${DISPLAY_REFRESH}"
export RETROPIE_OUTPUT="${DISPLAY_OUTPUT:-}"
export UNCLUTTER_TIMEOUT="${UNCLUTTER_TIMEOUT:-3}"
EOF
chown "${RETROPIE_USER}:${RETROPIE_USER}" "$ENVD_FILE"

# Source it from .bash_profile
if ! grep -q "retropie-x86.env" "${RETROPIE_HOME}/.bash_profile"; then
    sed -i "1s|^|# Source RetroPie env\n[ -f ~/.retropie-x86.env ] \&\& . ~/.retropie-x86.env\n\n|" \
        "${RETROPIE_HOME}/.bash_profile"
fi

# ── Disable graphical target lock-in from display managers ────────────────────
# Prevent any lingering display manager from intercepting TTY1
for dm in gdm3 lightdm sddm lxdm; do
    if systemctl is-enabled "$dm" &>/dev/null 2>&1; then
        info "Disabling display manager: ${dm}"
        systemctl disable --now "$dm" 2>/dev/null || true
    fi
done

# Boot into multi-user (not graphical.target — we control X ourselves)
systemctl set-default multi-user.target
info "Boot target set to multi-user.target ✓"

info "Autologin configuration complete ✓"
