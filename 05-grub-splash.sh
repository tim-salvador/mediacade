#!/usr/bin/env bash
# =============================================================================
# 05-grub-splash.sh — Silent GRUB + 1080p framebuffer + quiet kernel
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"

info()  { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

GRUB_CFG="/etc/default/grub"
GRUB_CFG_BAK="/etc/default/grub.bak.$(date +%Y%m%d%H%M%S)"

# Backup existing GRUB config
cp "$GRUB_CFG" "$GRUB_CFG_BAK"
info "GRUB config backed up to ${GRUB_CFG_BAK}"

# ── Map resolution to GRUB GFXMODE ────────────────────────────────────────────
# GRUB uses VBE modes. Common safe value: 1920x1080x32
GRUB_RES="${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}"
info "GRUB resolution: ${GRUB_RES}"

# ── Kernel cmdline parameters for silent boot ─────────────────────────────────
# quiet          — suppress kernel messages
# splash         — enable Plymouth splash
# loglevel=3     — only show critical kernel messages
# rd.systemd.show_status=false — hide systemd status
# udev.log_level=3 — suppress udev noise
# vt.global_cursor_default=0  — disable TTY cursor (cleaner with Plymouth)
# mitigations=auto — keep security mitigations (remove for perf if desired)
KERNEL_PARAMS="quiet splash loglevel=3 rd.systemd.show_status=false udev.log_level=3 vt.global_cursor_default=0"

# ── Write new GRUB config ─────────────────────────────────────────────────────
info "Writing silent GRUB configuration..."
cat > "$GRUB_CFG" << EOF
# RetroPie-X86 — GRUB configuration
# Managed by retropie-x86 — do not edit manually (re-run 05-grub-splash.sh)

# ── Timeout & visibility ──────────────────────────────────────────────────────
GRUB_DEFAULT=0
GRUB_TIMEOUT=0                          # No boot menu (set to 2 to allow Shift-key access)
GRUB_TIMEOUT_STYLE=hidden              # Hidden countdown
GRUB_HIDDEN_TIMEOUT=0
GRUB_HIDDEN_TIMEOUT_QUIET=true

# ── Kernel parameters ─────────────────────────────────────────────────────────
GRUB_CMDLINE_LINUX_DEFAULT="${KERNEL_PARAMS}"
GRUB_CMDLINE_LINUX=""

# ── Graphics ──────────────────────────────────────────────────────────────────
GRUB_GFXMODE=${GRUB_RES}              # GRUB framebuffer resolution
GRUB_GFXPAYLOAD_LINUX=keep            # Kernel inherits GRUB framebuffer (smoother handoff to Plymouth)
GRUB_TERMINAL=gfxterm                  # Graphical terminal (required for Plymouth seamless boot)

# ── Visuals ───────────────────────────────────────────────────────────────────
GRUB_BACKGROUND=""                     # No GRUB background image (black)
# GRUB_THEME="/boot/grub/themes/retropie/theme.txt"  # Optional: custom theme

# ── Distributor / OS name ─────────────────────────────────────────────────────
GRUB_DISTRIBUTOR="RetroPie"

# ── Disable memory test entry ─────────────────────────────────────────────────
GRUB_DISABLE_SUBMENU=y
EOF

# ── Plymouth framebuffer — ensure initramfs has correct modules ───────────────
info "Configuring initramfs for Plymouth framebuffer..."

# Add drm + framebuffer drivers to initramfs
INITRAMFS_MODULES_FILE="/etc/initramfs-tools/modules"
MODULES_TO_ADD=(
    "drm"
    "drm_kms_helper"
    "i915"       # Intel
    "xe"         # Intel Arc / Meteor Lake
    "nouveau"    # NVIDIA open (only if not using proprietary)
    "radeon"     # AMD legacy
    "amdgpu"     # AMD modern
    "nvidia_drm" # NVIDIA proprietary DRM (only loaded if nvidia installed)
    "bochs-drm"  # VM/QEMU
    "virtio-gpu" # QEMU virtio
)
for mod in "${MODULES_TO_ADD[@]}"; do
    if ! grep -q "^${mod}" "$INITRAMFS_MODULES_FILE" 2>/dev/null; then
        echo "$mod" >> "$INITRAMFS_MODULES_FILE"
    fi
done

# ── Splash screen Plymouth hook ───────────────────────────────────────────────
# Ensure Plymouth is in the initramfs
if ! dpkg -l plymouth &>/dev/null; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq plymouth
fi

# ── systemd: suppress boot text ───────────────────────────────────────────────
info "Suppressing systemd boot output..."
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/99-silent.conf << 'EOF'
[Manager]
ShowStatus=no
EOF

# Hide TTY cursor during boot (avoid blinking cursor over splash)
mkdir -p /etc/udev/rules.d
cat > /etc/udev/rules.d/99-hide-tty-cursor.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="vtconsole", ATTR{bind}=="0", RUN+="/bin/sh -c 'echo 0 > /sys/class/vtconsole/vtcon0/bind'"
EOF

# ── Shutdown: silence systemd stop jobs ───────────────────────────────────────
info "Reducing shutdown verbosity..."
sed -i 's/^#*DefaultTimeoutStopSec=.*/DefaultTimeoutStopSec=10s/' \
    /etc/systemd/system.conf 2>/dev/null || true
mkdir -p /etc/systemd/system.conf.d
cat >> /etc/systemd/system.conf.d/99-silent.conf << 'EOF'
DefaultTimeoutStopSec=10s
EOF

# ── Update GRUB ───────────────────────────────────────────────────────────────
info "Updating GRUB..."
update-grub 2>&1 | grep -v "^$" || true

# ── Rebuild initramfs ─────────────────────────────────────────────────────────
info "Rebuilding initramfs (this may take a moment)..."
update-initramfs -u -k all 2>&1 | tail -5

info "GRUB / silent boot configuration complete ✓"
info "Note: If GRUB_TIMEOUT=0 prevents you from entering GRUB, hold Shift during boot."
