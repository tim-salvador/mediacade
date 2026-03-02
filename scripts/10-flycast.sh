#!/usr/bin/env bash
# =============================================================================
# 10-flycast.sh — lr-flycast (Dreamcast/NAOMI/NAOMI2/AtomisWave) installation
# Builds from source if binary not available through RetroPie-Setup
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"
RETROPIE_HOME="$(getent passwd "${RETROPIE_USER}" | cut -d: -f6)"

info()    { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

INSTALL_FLYCAST="${INSTALL_FLYCAST:-true}"
[[ "$INSTALL_FLYCAST" == "false" ]] && { info "Flycast installation skipped (INSTALL_FLYCAST=false)"; exit 0; }

MAKE_JOBS="${MAKE_JOBS:-$(nproc)}"
RETROPIE_SETUP_DIR="${RETROPIE_HOME}/RetroPie-Setup"
FLYCAST_CORE_DEST="/opt/retropie/libretrocores/lr-flycast"
FLYCAST_CORE_FILE="${FLYCAST_CORE_DEST}/flycast_libretro.so"

# ── Try binary install via RetroPie-Setup first ───────────────────────────────
info "Attempting lr-flycast binary install via RetroPie-Setup..."
if [[ -f "${RETROPIE_SETUP_DIR}/retropie_packages.sh" ]]; then
    if bash "${RETROPIE_SETUP_DIR}/retropie_packages.sh" lr-flycast install_bin 2>&1 | \
       grep -qv "Unable to install"; then
        if [[ -f "$FLYCAST_CORE_FILE" ]]; then
            success "lr-flycast installed via binary ✓"
            INSTALL_FROM_SOURCE=false
        else
            info "Binary not available — will build from source."
            INSTALL_FROM_SOURCE=true
        fi
    else
        INSTALL_FROM_SOURCE=true
    fi
else
    warn "RetroPie-Setup not found — building flycast from source directly."
    INSTALL_FROM_SOURCE=true
fi

# ── Build from source ─────────────────────────────────────────────────────────
if [[ "${INSTALL_FROM_SOURCE:-true}" == "true" ]]; then
    info "Building lr-flycast from source (this takes 5–15 minutes)..."

    # Build deps
    info "Installing flycast build dependencies..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        cmake ninja-build \
        libgl-dev libgles-dev libegl-dev \
        libasound2-dev \
        libpulse-dev \
        libzip-dev \
        libglib2.0-dev \
        libzstd-dev \
        libssl-dev \
        xxd \
        glslang-tools \
        spirv-tools

    BUILD_DIR="/tmp/flycast-build"
    FLYCAST_REPO="https://github.com/libretro/flycast.git"

    if [[ -d "$BUILD_DIR" ]]; then
        info "Updating existing flycast source..."
        git -C "$BUILD_DIR" pull --quiet 2>/dev/null || true
    else
        info "Cloning flycast..."
        git clone --depth=1 --recursive "$FLYCAST_REPO" "$BUILD_DIR"
    fi

    cd "$BUILD_DIR"

    # Update submodules
    git submodule update --init --recursive --depth=1 2>&1 | tail -3

    # Build as libretro core
    info "Compiling flycast_libretro.so (using ${MAKE_JOBS} jobs)..."
    make -f Makefile HAVE_VULKAN=1 HAVE_OPENGL=1 HAVE_GENERIC_VULKAN=1 \
        LIBRETRO=1 \
        -j"$MAKE_JOBS" 2>&1 | tail -10

    # Locate built core
    BUILT_CORE=$(find "$BUILD_DIR" -name "flycast_libretro.so" 2>/dev/null | head -1)
    if [[ -z "$BUILT_CORE" ]]; then
        error "flycast_libretro.so not found after build. Check build output."
    fi

    # Install core
    mkdir -p "$FLYCAST_CORE_DEST"
    cp "$BUILT_CORE" "$FLYCAST_CORE_FILE"
    info "Core installed to: ${FLYCAST_CORE_FILE}"

    # Clean up if configured
    if [[ "${KEEP_BUILD_ARTIFACTS:-false}" == "false" ]]; then
        rm -rf "$BUILD_DIR"
        info "Build artifacts cleaned up."
    fi

    success "lr-flycast built and installed from source ✓"
fi

# ── Create ROM directories ────────────────────────────────────────────────────
info "Creating Flycast/Dreamcast ROM directories..."
ROMS_BASE="${NFS_ROMS_PATH:-${RETROPIE_HOME}/RetroPie/roms}"
BIOS_DIR="${RETROPIE_HOME}/RetroPie/BIOS"

for dir in \
    "${ROMS_BASE}/dreamcast" \
    "${ROMS_BASE}/naomi" \
    "${ROMS_BASE}/naomi2" \
    "${ROMS_BASE}/atomiswave" \
    "${BIOS_DIR}/dc"; do
    mkdir -p "$dir"
done
chown -R "${RETROPIE_USER}:${RETROPIE_USER}" "${RETROPIE_HOME}/RetroPie"

# ── Retroarch core config for flycast ─────────────────────────────────────────
info "Writing RetroArch core options for flycast..."
RA_CORE_OPTIONS="/opt/retropie/configs/all/retroarch-core-options.cfg"
mkdir -p "$(dirname "$RA_CORE_OPTIONS")"

# Merge flycast core options (don't overwrite other core options)
FLYCAST_OPTIONS=(
    'flycast_internal_resolution = "1920x1080"'
    'flycast_enable_dsp = "enabled"'
    'flycast_synchronize_timer = "disabled"'  # More accurate timing
    'flycast_widescreen_hack = "disabled"'
    'flycast_anisotropic_filtering = "8"'
    'flycast_framerate = "fullspeed"'
    'flycast_boot_to_bios = "disabled"'
    'flycast_cable_type = "TV (RGB)"'
    'flycast_region = "USA"'
    'flycast_broadcast = "NTSC"'
    'flycast_allow_service_buttons = "disabled"'
)

for opt in "${FLYCAST_OPTIONS[@]}"; do
    KEY="${opt%% =*}"
    # Remove existing entry and add new one
    grep -v "^${KEY}" "$RA_CORE_OPTIONS" > /tmp/ra-opts.tmp 2>/dev/null || true
    mv /tmp/ra-opts.tmp "$RA_CORE_OPTIONS" 2>/dev/null || true
    echo "$opt" >> "$RA_CORE_OPTIONS"
done

# ── EmulationStation system config for dreamcast ─────────────────────────────
info "Configuring EmulationStation for Dreamcast/flycast..."
ES_SYSTEMS_CUSTOM="/etc/emulationstation/es_systems.cfg"
RETROPIE_ES_SYSTEMS="/opt/retropie/configs/all/emulationstation/es_systems.cfg"

for es_cfg in "$ES_SYSTEMS_CUSTOM" "$RETROPIE_ES_SYSTEMS"; do
    if [[ -f "$es_cfg" ]]; then
        # Ensure flycast is set as default emulator for dreamcast
        if grep -q "<name>dreamcast</name>" "$es_cfg"; then
            info "  Dreamcast system already in ${es_cfg}"
        fi
        break
    fi
done

# Write custom emulators.cfg for dreamcast to prefer flycast
EMULATORS_CFG="/opt/retropie/configs/dreamcast/emulators.cfg"
mkdir -p "$(dirname "$EMULATORS_CFG")"
cat > "$EMULATORS_CFG" << EOF
# mediacade: Dreamcast emulator preference
lr-flycast = "retroarch -L ${FLYCAST_CORE_FILE} %ROM%"
default = "lr-flycast"
EOF

# NAOMI / AtomisWave configs
for system in naomi naomi2 atomiswave; do
    mkdir -p "/opt/retropie/configs/${system}"
    cat > "/opt/retropie/configs/${system}/emulators.cfg" << EOF
# mediacade: ${system} emulator preference
lr-flycast = "retroarch -L ${FLYCAST_CORE_FILE} %ROM%"
default = "lr-flycast"
EOF
done

# ── BIOS notice ───────────────────────────────────────────────────────────────
echo ""
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Flycast BIOS files — place in: ${BIOS_DIR}/dc/"
info ""
info "  Required for Dreamcast:"
info "    dc_boot.bin   (SHA1: e10c53c2f8b90bab96ead2d368858623894c0000)"
info "    dc_flash.bin  (SHA1: 0a93f7940c455905bea6e392dfde92a4af73eda9)"
info ""
info "  Required for NAOMI/AtomisWave:"
info "    naomi.zip     (MAME BIOS ROM)"
info "    airlbios.zip  (AtomisWave BIOS)"
info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

success "lr-flycast configuration complete ✓"
