#!/usr/bin/env bash
# =============================================================================
# 03-video-drivers.sh — Intel / NVIDIA / Vulkan driver installation
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"

info()  { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

# Load GPU auto-detection result from preflight
GPU_RESOLVED="${GPU_DRIVER:-auto}"
if [[ -f /tmp/mediacade-gpu.env ]]; then
    source /tmp/mediacade-gpu.env
    GPU_RESOLVED="${GPU_DRIVER_RESOLVED:-$GPU_DRIVER}"
fi

info "GPU driver target: ${GPU_RESOLVED}"

# ── Common Vulkan runtime (installed regardless of GPU) ───────────────────────
install_vulkan_common() {
    info "Installing common Vulkan runtime..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        vulkan-tools \
        libvulkan1 \
        libvulkan-dev \
        spirv-tools \
        glslang-tools
}

# ── Intel ─────────────────────────────────────────────────────────────────────
install_intel() {
    info "Installing Intel Mesa drivers (iris / xe)..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        xserver-xorg-video-intel \
        intel-media-va-driver \
        i965-va-driver \
        libva-drm2 \
        libva-x11-2 \
        vainfo \
        mesa-vulkan-drivers \       # Intel ANV (Vulkan via Mesa)
        libgl1-mesa-dri \
        libgles2-mesa \
        libegl-mesa0

    # Xorg config for Intel — use modesetting driver (better for modern Intel)
    cat > /etc/X11/xorg.conf.d/20-intel.conf << 'EOF'
# Intel GPU — modesetting driver (preferred over xf86-video-intel for Gen9+)
Section "Device"
    Identifier  "IntelGPU"
    Driver      "modesetting"
    Option      "AccelMethod"  "glamor"
    Option      "DRI"          "3"
    Option      "TearFree"     "true"
EndSection
EOF
    info "Intel drivers installed ✓"
}

# ── NVIDIA ────────────────────────────────────────────────────────────────────
install_nvidia() {
    info "Installing NVIDIA proprietary drivers..."

    # Enable ubuntu-drivers-common to auto-detect the right nvidia version
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        ubuntu-drivers-common \
        nvidia-prime

    # Detect recommended driver
    RECOMMENDED=$(ubuntu-drivers devices 2>/dev/null | grep 'recommended' | awk '{print $3}' | head -1 || true)
    if [[ -z "$RECOMMENDED" ]]; then
        # Fallback: install latest stable
        RECOMMENDED="nvidia-driver-550"
        warn "Could not auto-detect NVIDIA driver version. Defaulting to ${RECOMMENDED}"
    fi
    info "Installing: ${RECOMMENDED}"

    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        "$RECOMMENDED" \
        nvidia-settings \
        nvidia-cuda-toolkit-gcc

    # NVIDIA Vulkan ICD (installed with driver, but ensure it)
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        libvulkan1 \
        nvidia-vulkan-icd 2>/dev/null || \
    info "nvidia-vulkan-icd not found as separate package (may be bundled with driver)"

    # Xorg config for NVIDIA
    cat > /etc/X11/xorg.conf.d/20-nvidia.conf << EOF
# NVIDIA proprietary driver config
Section "Device"
    Identifier  "NvidiaGPU"
    Driver      "nvidia"
    Option      "NoLogo"          "true"
    Option      "RegistryDwords"  "EnableBrightnessControl=1"
    Option      "TripleBuffer"    "true"
    Option      "Coolbits"        "28"
EndSection

Section "Screen"
    Identifier  "NvidiaScreen"
    Device      "NvidiaGPU"
    DefaultDepth ${DISPLAY_DEPTH}
    SubSection "Display"
        Depth   ${DISPLAY_DEPTH}
        Modes   "${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
    EndSubSection
EndSection
EOF

    # Blacklist Nouveau
    info "Blacklisting Nouveau..."
    cat > /etc/modprobe.d/blacklist-nouveau.conf << 'EOF'
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF
    update-initramfs -u -k all
    info "NVIDIA drivers installed ✓"
}

# ── AMD (Mesa) ────────────────────────────────────────────────────────────────
install_amd() {
    info "Installing AMD Mesa (radeonsi / RADV Vulkan) drivers..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        xserver-xorg-video-amdgpu \
        mesa-vulkan-drivers \        # includes RADV
        libgl1-mesa-dri \
        libgles2-mesa \
        libegl-mesa0 \
        radeontop

    cat > /etc/X11/xorg.conf.d/20-amd.conf << 'EOF'
# AMD GPU — amdgpu kernel driver with modesetting Xorg driver
Section "Device"
    Identifier  "AMDGPU"
    Driver      "amdgpu"
    Option      "DRI"          "3"
    Option      "TearFree"     "true"
    Option      "AccelMethod"  "glamor"
EndSection
EOF
    info "AMD drivers installed ✓"
}

# ── Install Vulkan Validation Layers (dev/debug) ───────────────────────────────
install_vulkan_validation() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        vulkan-validationlayers 2>/dev/null || \
    warn "vulkan-validationlayers not available (non-critical)"
}

# ── Main dispatch ─────────────────────────────────────────────────────────────
install_vulkan_common

case "$GPU_RESOLVED" in
    intel)  install_intel  ;;
    nvidia) install_nvidia ;;
    amd)    install_amd    ;;
    none)   warn "Skipping GPU driver install (GPU_DRIVER=none)" ;;
    *)      warn "Unknown GPU type '${GPU_RESOLVED}'. Skipping driver install." ;;
esac

install_vulkan_validation

# ── Verify Vulkan is functional (best-effort) ─────────────────────────────────
info "Checking Vulkan runtime..."
if command -v vulkaninfo &>/dev/null; then
    vulkaninfo --summary 2>/dev/null | grep -E "GPU|apiVersion|driverVersion" || true
else
    warn "vulkaninfo not available — install vulkan-tools to verify Vulkan support"
fi

info "Video driver installation complete ✓"
