#!/usr/bin/env bash
# =============================================================================
# 06-plymouth.sh — Plymouth splash screen + HerbFargus theme installation
# Usage: ./06-plymouth.sh [--list] [--set <theme>]
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"

info()    { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

THEMES_REPO="https://github.com/HerbFargus/plymouth-themes.git"
THEMES_DIR="/usr/share/plymouth/themes"
LOCAL_CLONE="/tmp/herbfargus-plymouth-themes"
ACTIVE_THEME="${PLYMOUTH_THEME:-retrowave}"

# ── Argument handling ─────────────────────────────────────────────────────────
LIST_ONLY=false
SET_THEME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list)  LIST_ONLY=true; shift ;;
        --set)   SET_THEME="$2"; shift 2 ;;
        *)       shift ;;
    esac
done

# ── Ensure Plymouth is installed ──────────────────────────────────────────────
info "Installing Plymouth..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    plymouth \
    plymouth-themes \
    libplymouth5

# ── Clone HerbFargus themes ───────────────────────────────────────────────────
info "Fetching HerbFargus Plymouth themes..."
if [[ -d "$LOCAL_CLONE" ]]; then
    info "Updating existing clone..."
    git -C "$LOCAL_CLONE" pull --quiet
else
    git clone --depth=1 --quiet "$THEMES_REPO" "$LOCAL_CLONE"
fi

# ── List themes if requested ──────────────────────────────────────────────────
if $LIST_ONLY; then
    echo ""
    echo "Available HerbFargus Plymouth themes:"
    echo "--------------------------------------"
    find "$LOCAL_CLONE" -maxdepth 1 -mindepth 1 -type d ! -name '.*' | sort | \
        while IFS= read -r d; do
            TNAME=$(basename "$d")
            echo "  • ${TNAME}"
        done
    echo ""
    echo "Currently active theme:"
    plymouth-set-default-theme 2>/dev/null || echo "  (none set)"
    exit 0
fi

# ── Install all themes from HerbFargus repo ───────────────────────────────────
info "Installing themes to ${THEMES_DIR}..."
INSTALLED=0
while IFS= read -r -d '' theme_dir; do
    theme_name=$(basename "$theme_dir")
    # Skip hidden dirs and non-theme directories
    [[ "$theme_name" == .* ]] && continue
    [[ ! -f "${theme_dir}"/*.plymouth ]] && continue 2>/dev/null || true

    dest="${THEMES_DIR}/${theme_name}"
    if [[ -d "$dest" ]]; then
        rm -rf "$dest"
    fi
    cp -r "$theme_dir" "$dest"
    ((INSTALLED++)) || true
    info "  Installed: ${theme_name}"
done < <(find "$LOCAL_CLONE" -maxdepth 1 -mindepth 1 -type d -print0)

info "Total themes installed: ${INSTALLED}"

# ── Apply selected theme ──────────────────────────────────────────────────────
TARGET_THEME="${SET_THEME:-$ACTIVE_THEME}"
info "Setting active Plymouth theme: ${TARGET_THEME}"

if plymouth-set-default-theme --list 2>/dev/null | grep -qx "$TARGET_THEME"; then
    plymouth-set-default-theme "$TARGET_THEME"
    success "Theme set to: ${TARGET_THEME}"
else
    warn "Theme '${TARGET_THEME}' not found. Available themes:"
    plymouth-set-default-theme --list 2>/dev/null | head -20 || true

    # Fallback to 'text' or 'bgrt' (always available)
    FALLBACK="text"
    if plymouth-set-default-theme --list 2>/dev/null | grep -qx "bgrt"; then
        FALLBACK="bgrt"
    fi
    warn "Falling back to theme: ${FALLBACK}"
    plymouth-set-default-theme "$FALLBACK"
fi

# ── Rebuild initramfs to apply Plymouth theme ─────────────────────────────────
info "Rebuilding initramfs to embed Plymouth theme..."
update-initramfs -u -k all 2>&1 | tail -3

# ── Enable Plymouth startup services ─────────────────────────────────────────
info "Enabling Plymouth services..."
systemctl enable plymouth-start.service 2>/dev/null || true
systemctl enable plymouth-read-write.service 2>/dev/null || true
systemctl enable plymouth-quit.service 2>/dev/null || true
systemctl enable plymouth-quit-wait.service 2>/dev/null || true

# ── Write theme selection helper script ───────────────────────────────────────
cat > /usr/local/bin/retropie-set-splash << 'HELPER'
#!/usr/bin/env bash
# Helper: select and apply a Plymouth splash theme
# Usage: sudo retropie-set-splash [theme-name]

if [[ -z "${1:-}" ]]; then
    echo "Available Plymouth themes:"
    plymouth-set-default-theme --list | while read -r t; do
        CURRENT=$(plymouth-set-default-theme 2>/dev/null || echo "")
        if [[ "$t" == "$CURRENT" ]]; then
            echo "  → ${t}  (active)"
        else
            echo "    ${t}"
        fi
    done
    echo ""
    echo "Usage: sudo retropie-set-splash <theme-name>"
    exit 0
fi

THEME="$1"
if ! plymouth-set-default-theme --list | grep -qx "$THEME"; then
    echo "Error: Theme '${THEME}' not found."
    exit 1
fi

plymouth-set-default-theme "$THEME"
update-initramfs -u -k all
echo "Splash theme set to: ${THEME}"
echo "Reboot to apply."
HELPER
chmod +x /usr/local/bin/retropie-set-splash

success "Plymouth configured ✓"
info "To change theme later: sudo retropie-set-splash <theme-name>"
info "To list themes:        sudo retropie-set-splash"
