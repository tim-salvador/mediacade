#!/usr/bin/env bash
# =============================================================================
# install.sh — RetroPie-X86 Main Installer
# Ubuntu 24.04 LTS | x86-64
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/retropie.cfg"
LOG_FILE="/var/log/retropie-x86-install.log"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" | tee -a "$LOG_FILE"; exit 1; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}" | tee -a "$LOG_FILE"; }

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "This script must be run as root. Use: sudo ./install.sh"

# ── Config load ───────────────────────────────────────────────────────────────
if [[ ! -f "$CONFIG_FILE" ]]; then
    warn "retropie.cfg not found — copying from example."
    cp "${SCRIPT_DIR}/retropie.cfg.example" "$CONFIG_FILE"
    error "Please edit retropie.cfg before running install.sh"
fi
# shellcheck source=retropie.cfg.example
source "$CONFIG_FILE"
export RETROPIE_USER GPU_DRIVER DISPLAY_WIDTH DISPLAY_HEIGHT DISPLAY_DEPTH \
       DISPLAY_REFRESH DISPLAY_OUTPUT PLYMOUTH_THEME NFS_ROLE NFS_SERVER_IP \
       NFS_ROMS_PATH NFS_EXPORT_SUBNET NFS_MOUNT_OPTIONS RETROPIE_EXTRA_PACKAGES \
       INSTALL_FLYCAST SKIP_MODULES UNCLUTTER_TIMEOUT KEEP_BUILD_ARTIFACTS \
       MAKE_JOBS SCRIPT_DIR SCRIPTS_DIR

# ── Validate user ─────────────────────────────────────────────────────────────
if ! id "$RETROPIE_USER" &>/dev/null; then
    error "User '$RETROPIE_USER' does not exist. Create the user first."
fi
export RETROPIE_HOME
RETROPIE_HOME="$(getent passwd "$RETROPIE_USER" | cut -d: -f6)"

# ── Log setup ─────────────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOG_FILE")"
echo "════════════════════════════════════════" >> "$LOG_FILE"
echo "RetroPie-X86 Install — $(date)" >> "$LOG_FILE"
echo "════════════════════════════════════════" >> "$LOG_FILE"

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
cat << 'EOF'
  ____      _             ____  _      __  ___   __
 |  _ \ ___| |_ _ __ ___|  _ \(_) ___|  \/  |  / /_
 | |_) / _ \ __| '__/ _ \ |_) | |/ _ \ |\/| | | '_ \
 |  _ <  __/ |_| | | (_) |  __/| |  __/ |  | | | (_) |
 |_| \_\___|\__|_|  \___/|_|  |_|\___|_|  |_|  \___/
                   Ubuntu 24.04 LTS | x86-64
EOF
echo -e "${RESET}"

info "User:        ${RETROPIE_USER} (${RETROPIE_HOME})"
info "GPU Driver:  ${GPU_DRIVER}"
info "Resolution:  ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}@${DISPLAY_REFRESH}Hz"
info "Plymouth:    ${PLYMOUTH_THEME}"
info "NFS Role:    ${NFS_ROLE}"
info "Log:         ${LOG_FILE}"
echo ""

# ── Module runner ─────────────────────────────────────────────────────────────
MODULES=(
    "00-preflight.sh"
    "01-system-prep.sh"
    "02-dependencies.sh"
    "03-video-drivers.sh"
    "04-autologin.sh"
    "05-grub-splash.sh"
    "06-plymouth.sh"
    "07-openbox.sh"
    "08-nfs.sh"
    "09-retropie.sh"
    "10-flycast.sh"
    "11-emulator-config.sh"
)

run_module() {
    local script="$1"
    local num="${script%%\-*}"
    local name="${script%.sh}"

    # Check skip list
    for skip in ${SKIP_MODULES}; do
        if [[ "$num" == "$skip" ]]; then
            warn "Skipping module: ${name}"
            return 0
        fi
    done

    local path="${SCRIPTS_DIR}/${script}"
    if [[ ! -f "$path" ]]; then
        warn "Module not found, skipping: ${path}"
        return 0
    fi

    section "${name}"
    bash "$path" 2>&1 | tee -a "$LOG_FILE"
    local exit_code=${PIPESTATUS[0]}

    if [[ $exit_code -ne 0 ]]; then
        error "Module '${name}' failed with exit code ${exit_code}. Check ${LOG_FILE}"
    fi
    success "${name} complete."
}

for module in "${MODULES[@]}"; do
    run_module "$module"
done

# ── Done ──────────────────────────────────────────────────────────────────────
section "Installation Complete"
echo -e "${GREEN}${BOLD}"
echo "  RetroPie-X86 setup finished successfully!"
echo "  Reboot to start EmulationStation automatically."
echo -e "${RESET}"
echo ""
echo "  → sudo reboot"
echo ""
warn "Remember to transfer your ROMs to: ${NFS_ROMS_PATH}"
warn "BIOS files go in: ${RETROPIE_HOME}/RetroPie/BIOS"
