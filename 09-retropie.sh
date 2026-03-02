#!/usr/bin/env bash
# =============================================================================
# 09-retropie.sh — RetroPie installation (from official RetroPie-Setup)
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"
RETROPIE_HOME="$(getent passwd "${RETROPIE_USER}" | cut -d: -f6)"

info()    { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

RETROPIE_SETUP_DIR="${RETROPIE_HOME}/RetroPie-Setup"
MAKE_JOBS="${MAKE_JOBS:-$(nproc)}"

# ── Clone RetroPie-Setup ───────────────────────────────────────────────────────
info "Setting up RetroPie-Setup repository..."
if [[ -d "$RETROPIE_SETUP_DIR" ]]; then
    info "Updating existing RetroPie-Setup clone..."
    sudo -u "${RETROPIE_USER}" git -C "$RETROPIE_SETUP_DIR" pull --quiet
else
    info "Cloning RetroPie-Setup..."
    sudo -u "${RETROPIE_USER}" git clone \
        --depth=1 \
        https://github.com/RetroPie/RetroPie-Setup.git \
        "$RETROPIE_SETUP_DIR"
fi
chown -R "${RETROPIE_USER}:${RETROPIE_USER}" "$RETROPIE_SETUP_DIR"

SETUP_SCRIPT="${RETROPIE_SETUP_DIR}/retropie_packages.sh"
[[ -f "$SETUP_SCRIPT" ]] || error "RetroPie setup script not found at ${SETUP_SCRIPT}"

# ── Pre-install dependencies RetroPie needs ───────────────────────────────────
info "Installing RetroPie build dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    libsdl1.2-dev libsdl2-dev libsdl2-ttf-dev libsdl2-image-dev \
    libsdl2-mixer-dev libsdl2-net-dev \
    libboost-all-dev \
    libfreeimage-dev libfreetype6-dev \
    libvlc-dev libvlccore-dev \
    libpugixml-dev \
    libcurl4-openssl-dev \
    libasound2-dev \
    libgl1-mesa-dev libgles2-mesa-dev \
    rapidjson-dev \
    ffmpeg \
    clang lld \
    python3-dev

# ── Core RetroPie installation ────────────────────────────────────────────────
info "Installing RetroPie core packages (this will take 15–45 minutes)..."

# Run as root but targeting the retropie user home
run_retropie() {
    bash "$SETUP_SCRIPT" "$@" 2>&1
}

# Install core: setup, emulationstation, retroarch, matching configs
CORE_PACKAGES=(
    setup
    emulationstation
    retroarch
    retroarch-assets
    emulationstation-de   # optional modern ES frontend
    runcommand
    autostart
)

for pkg in "${CORE_PACKAGES[@]}"; do
    info "  Installing package: ${pkg}"
    run_retropie "$pkg" install_bin || {
        warn "Binary install failed for ${pkg} — attempting source build..."
        run_retropie "$pkg" install || warn "  Failed: ${pkg} (non-fatal, continuing)"
    }
done

# ── Common emulator cores (pre-built binaries) ────────────────────────────────
info "Installing common emulator packages..."
EMULATOR_PACKAGES=(
    # Nintendo
    lr-snes9x            # SNES
    lr-mgba              # GBA/GBC/GB
    lr-fceumm            # NES
    lr-nestopia          # NES (alt)
    lr-mupen64plus-next  # N64
    lr-desmume           # DS
    lr-gambatte          # GB/GBC
    # Sega
    lr-picodrive         # Genesis/32X/Mega-CD
    lr-genesis-plus-gx   # Genesis/CD/SMS/GG
    lr-bluemsx           # MSX
    lr-yabause           # Saturn
    # Sony
    lr-pcsx-rearmed      # PS1
    lr-ppsspp            # PSP
    # Arcade
    lr-fbneo             # FinalBurn Neo (Arcade)
    lr-mame              # MAME
    # Misc
    lr-dosbox-pure       # DOS
    lr-scummvm           # Point & click
    lr-vice              # C64
    lr-hatari            # Atari ST
)

for pkg in "${EMULATOR_PACKAGES[@]}"; do
    info "  Installing: ${pkg}"
    run_retropie "$pkg" install_bin 2>&1 | tail -2 || \
        warn "  Skipped (not available as binary): ${pkg}"
done

# ── Extra packages from config ────────────────────────────────────────────────
if [[ -n "${RETROPIE_EXTRA_PACKAGES:-}" ]]; then
    info "Installing extra packages: ${RETROPIE_EXTRA_PACKAGES}"
    for pkg in $RETROPIE_EXTRA_PACKAGES; do
        run_retropie "$pkg" install_bin 2>&1 | tail -2 || \
            warn "  Failed: ${pkg}"
    done
fi

# ── Create RetroPie directory structure ───────────────────────────────────────
info "Creating RetroPie directory structure..."
RETROPIE_DATA="${RETROPIE_HOME}/RetroPie"
DIRS=(
    "${RETROPIE_DATA}/roms"
    "${RETROPIE_DATA}/BIOS"
    "${RETROPIE_DATA}/splashscreens"
    "${RETROPIE_DATA}/configs"
    "${RETROPIE_HOME}/.emulationstation/themes"
    "${RETROPIE_HOME}/.emulationstation/gamelists"
)
for d in "${DIRS[@]}"; do
    mkdir -p "$d"
done
chown -R "${RETROPIE_USER}:${RETROPIE_USER}" "${RETROPIE_DATA}" "${RETROPIE_HOME}/.emulationstation"

# ── Apply runcommand configuration ────────────────────────────────────────────
info "Configuring runcommand..."
RUNCOMMAND_CFG="/opt/retropie/configs/all/runcommand.cfg"
if [[ -f "$RUNCOMMAND_CFG" ]]; then
    # Disable launch menu (loads games directly)
    sed -i 's/^disable_menu=.*/disable_menu=1/' "$RUNCOMMAND_CFG" 2>/dev/null || \
        echo "disable_menu=1" >> "$RUNCOMMAND_CFG"
    # Show performance/resolution info on launch
    sed -i 's/^governor=.*/governor=performance/' "$RUNCOMMAND_CFG" 2>/dev/null || \
        echo "governor=performance" >> "$RUNCOMMAND_CFG"
fi

success "RetroPie installation complete ✓"
info "BIOS files go in: ${RETROPIE_DATA}/BIOS"
info "ROMs go in:       ${RETROPIE_DATA}/roms/<system>/"
