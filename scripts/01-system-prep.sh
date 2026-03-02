#!/usr/bin/env bash
# =============================================================================
# 01-system-prep.sh — User creation, sudoers, APT config, locale, base packages
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"

info()  { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

# ── Create user if it doesn't exist ───────────────────────────────────────────
if ! id "${RETROPIE_USER}" &>/dev/null; then
    info "User '${RETROPIE_USER}' not found — creating..."
    useradd \
        --create-home \
        --shell /bin/bash \
        --comment "mediacade user" \
        "${RETROPIE_USER}"

    # Set default password — user should change this after first login
    echo "${RETROPIE_USER}:raspberry" | chpasswd
    info "User '${RETROPIE_USER}' created ✓"
    warn "Default password is 'raspberry' — change it after install: passwd ${RETROPIE_USER}"
else
    info "User '${RETROPIE_USER}' already exists ✓"
fi

# Resolve home directory now that the user definitely exists
RETROPIE_HOME="$(getent passwd "${RETROPIE_USER}" | cut -d: -f6)"
info "Home directory: ${RETROPIE_HOME}"

# ── Passwordless sudo ─────────────────────────────────────────────────────────
info "Configuring passwordless sudo for ${RETROPIE_USER}..."
SUDOERS_FILE="/etc/sudoers.d/mediacade-${RETROPIE_USER}"
cat > "$SUDOERS_FILE" << EOF
# mediacade: passwordless sudo for ${RETROPIE_USER}
${RETROPIE_USER} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" || error "Sudoers file syntax error — aborting."
info "Sudoers configured ✓"

# ── APT: update, no recommends, parallel downloads ────────────────────────────
info "Configuring APT..."
cat > /etc/apt/apt.conf.d/99mediacade << 'EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
Acquire::Queue-Mode "access";
Acquire::http::Pipeline-Depth "5";
EOF

# Enable universe/multiverse repositories
add-apt-repository -y universe
add-apt-repository -y multiverse

info "Updating package lists..."
DEBIAN_FRONTEND=noninteractive apt-get update -qq

info "Upgrading existing packages..."
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -qq \
    -o Dpkg::Options::="--force-confnew"

# ── Locale ────────────────────────────────────────────────────────────────────
info "Setting locale to en_US.UTF-8..."
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ── Base packages ─────────────────────────────────────────────────────────────
info "Installing base packages..."
BASE_PACKAGES=(
    # Core utils
    curl wget git ca-certificates gnupg lsb-release
    # Build tools (needed by RetroPie and lr-flycast)
    build-essential cmake ninja-build pkg-config
    autoconf automake libtool
    # System
    pciutils usbutils lsof htop
    # Python (needed by RetroPie setup scripts)
    python3 python3-pip python3-venv
    # Dialog / whiptail (RetroPie installer UI)
    dialog whiptail
    # Font rendering
    fontconfig fonts-dejavu-core
    # Audio — Ubuntu 24.04 uses PipeWire by default; include both for compat
    pipewire pipewire-pulse pipewire-alsa
    wireplumber
    alsa-utils
    # Joystick / gamepad support
    joystick libsdl2-dev
    # Network
    net-tools avahi-daemon
    # Useful helpers
    unzip p7zip-full rsync screen tmux
    # Needed for plymouth & grub
    plymouth plymouth-themes
)

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${BASE_PACKAGES[@]}"
info "Base packages installed ✓"

# ── Disable unnecessary services ──────────────────────────────────────────────
info "Disabling unnecessary services..."
DISABLE_SERVICES=(
    apport      # crash reporter
    whoopsie    # error reporting
    cups        # printing
)
for svc in "${DISABLE_SERVICES[@]}"; do
    if systemctl is-enabled "$svc" &>/dev/null 2>&1; then
        systemctl disable --now "$svc" 2>/dev/null || true
        info "  Disabled: ${svc}"
    fi
done

# Keep avahi for mDNS / hostname resolution on the LAN
systemctl enable --now avahi-daemon 2>/dev/null || true

# ── Set timezone ──────────────────────────────────────────────────────────────
TZ="${TIMEZONE:-UTC}"
info "Setting timezone: ${TZ}"
timedatectl set-timezone "$TZ" 2>/dev/null || \
    ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime

# ── Add user to required groups ───────────────────────────────────────────────
info "Adding ${RETROPIE_USER} to system groups..."
for grp in audio video input dialout plugdev games render kvm; do
    if getent group "$grp" &>/dev/null; then
        usermod -aG "$grp" "${RETROPIE_USER}"
    fi
done
info "Groups assigned ✓"

info "System preparation complete ✓"
