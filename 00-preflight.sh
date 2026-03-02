#!/usr/bin/env bash
# =============================================================================
# 00-preflight.sh — Pre-flight checks & prerequisites
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg" 2>/dev/null || true
RETROPIE_HOME="${RETROPIE_HOME:-$(getent passwd "${RETROPIE_USER:-pi}" | cut -d: -f6)}"

info()  { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

# ── OS Check ──────────────────────────────────────────────────────────────────
info "Checking OS..."
if [[ ! -f /etc/os-release ]]; then
    error "Cannot detect OS. /etc/os-release missing."
fi
source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    error "This script requires Ubuntu. Detected: ${ID}"
fi
if [[ "$VERSION_ID" != "24.04" ]]; then
    warn "This script targets Ubuntu 24.04 LTS. Detected: ${VERSION_ID}. Proceeding anyway..."
fi
info "OS: ${PRETTY_NAME} ✓"

# ── Architecture Check ────────────────────────────────────────────────────────
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
    error "This script requires x86-64 architecture. Detected: ${ARCH}"
fi
info "Architecture: ${ARCH} ✓"

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Must run as root."
info "Running as root ✓"

# ── Internet Check ────────────────────────────────────────────────────────────
info "Checking internet connectivity..."
if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
    error "No internet connection detected. Please connect before running."
fi
info "Internet: OK ✓"

# ── Disk Space ────────────────────────────────────────────────────────────────
AVAIL_KB=$(df / --output=avail | tail -1)
AVAIL_GB=$((AVAIL_KB / 1024 / 1024))
info "Available disk space: ${AVAIL_GB} GB"
if [[ $AVAIL_GB -lt 20 ]]; then
    error "Insufficient disk space. Need at least 20 GB, have ${AVAIL_GB} GB."
elif [[ $AVAIL_GB -lt 50 ]]; then
    warn "Less than 50 GB available. ROMs storage will be limited."
fi

# ── RAM Check ─────────────────────────────────────────────────────────────────
RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')
info "RAM: ${RAM_MB} MB"
if [[ $RAM_MB -lt 1024 ]]; then
    error "Insufficient RAM. Need at least 1 GB, have ${RAM_MB} MB."
elif [[ $RAM_MB -lt 2048 ]]; then
    warn "Less than 2 GB RAM. Some emulators may perform poorly."
fi

# ── GPU Detection (informational) ─────────────────────────────────────────────
info "Detecting GPU..."
if command -v lspci &>/dev/null; then
    GPU_INFO=$(lspci | grep -i 'vga\|3d\|display' || echo "Unknown")
    info "GPU(s) found:"
    echo "$GPU_INFO" | while IFS= read -r line; do info "  → $line"; done

    if [[ "${GPU_DRIVER:-auto}" == "auto" ]]; then
        if echo "$GPU_INFO" | grep -qi "nvidia"; then
            info "Auto-detected: NVIDIA GPU → will install proprietary driver"
            echo "GPU_DRIVER_RESOLVED=nvidia" >> /tmp/mediacade-gpu.env
        elif echo "$GPU_INFO" | grep -qi "intel"; then
            info "Auto-detected: Intel GPU → will install Mesa (iris/xe)"
            echo "GPU_DRIVER_RESOLVED=intel" >> /tmp/mediacade-gpu.env
        elif echo "$GPU_INFO" | grep -qi "amd\|radeon\|advanced micro"; then
            info "Auto-detected: AMD GPU → will install Mesa (radeonsi)"
            echo "GPU_DRIVER_RESOLVED=amd" >> /tmp/mediacade-gpu.env
        else
            warn "Could not auto-detect GPU type. Video drivers will be skipped."
            echo "GPU_DRIVER_RESOLVED=none" >> /tmp/mediacade-gpu.env
        fi
    else
        echo "GPU_DRIVER_RESOLVED=${GPU_DRIVER}" >> /tmp/mediacade-gpu.env
    fi
else
    warn "lspci not available — installing pciutils for GPU detection."
    apt-get install -y -qq pciutils
fi

# ── User Home ─────────────────────────────────────────────────────────────────
info "RetroPie user: ${RETROPIE_USER:-pi} → ${RETROPIE_HOME}"
if [[ ! -d "$RETROPIE_HOME" ]]; then
    error "Home directory ${RETROPIE_HOME} does not exist."
fi

# ── Config file validation ────────────────────────────────────────────────────
CFG="${SCRIPT_DIR:-$(dirname "$0")/..}/retropie.cfg"
if [[ ! -f "$CFG" ]]; then
    error "retropie.cfg not found at ${CFG}"
fi

# ── Mark system for first-run resume ─────────────────────────────────────────
echo "PREFLIGHT_OK=true" > /tmp/mediacade-preflight.env
info "Pre-flight checks passed ✓"
