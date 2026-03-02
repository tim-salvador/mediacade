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
    libplymouth5 \
    plymouth-label            # provides text rendering; required by many themes

# ── Locate plymouth-set-default-theme ────────────────────────────────────────
# On Ubuntu 24.04 it lives in /usr/sbin — may not be on PATH when run via sudo
PSDT=""
for candidate in \
    "$(command -v plymouth-set-default-theme 2>/dev/null || true)" \
    /usr/sbin/plymouth-set-default-theme \
    /sbin/plymouth-set-default-theme; do
    if [[ -x "$candidate" ]]; then
        PSDT="$candidate"
        break
    fi
done

if [[ -z "$PSDT" ]]; then
    warn "plymouth-set-default-theme not found — will write /etc/plymouth/plymouthd.conf directly."
fi

# ── Helper: set a theme (works with or without plymouth-set-default-theme) ────
set_plymouth_theme() {
    local theme="$1"
    local theme_file="${THEMES_DIR}/${theme}/${theme}.plymouth"

    if [[ ! -f "$theme_file" ]]; then
        warn "Theme file not found: ${theme_file}"
        return 1
    fi

    if [[ -n "$PSDT" ]]; then
        "$PSDT" "$theme"
    else
        # Direct config edit fallback
        mkdir -p /etc/plymouth
        if [[ -f /etc/plymouth/plymouthd.conf ]]; then
            sed -i "s|^Theme=.*|Theme=${theme}|" /etc/plymouth/plymouthd.conf
            if ! grep -q "^Theme=" /etc/plymouth/plymouthd.conf; then
                echo "Theme=${theme}" >> /etc/plymouth/plymouthd.conf
            fi
        else
            cat > /etc/plymouth/plymouthd.conf << EOF
[Daemon]
Theme=${theme}
ShowDelay=0
DeviceTimeout=8
EOF
        fi
        # Also update the default.plymouth symlink used by initramfs
        ln -sfn "${theme_file}" "${THEMES_DIR}/default.plymouth" 2>/dev/null || true
        update-alternatives --install "${THEMES_DIR}/default.plymouth" \
            default.plymouth "${theme_file}" 100 2>/dev/null || true
    fi
}

# ── Helper: list installed themes ────────────────────────────────────────────
list_plymouth_themes() {
    find "$THEMES_DIR" -maxdepth 2 -name "*.plymouth" ! -name "default.plymouth" \
        -printf "%f\n" 2>/dev/null | sed 's/\.plymouth$//' | sort
}

# ── Clone HerbFargus themes ───────────────────────────────────────────────────
info "Fetching HerbFargus Plymouth themes..."
if [[ -d "$LOCAL_CLONE" ]]; then
    info "Updating existing clone..."
    git -C "$LOCAL_CLONE" pull --quiet 2>/dev/null || true
else
    git clone --depth=1 --quiet "$THEMES_REPO" "$LOCAL_CLONE"
fi

# ── List themes if requested ──────────────────────────────────────────────────
if $LIST_ONLY; then
    echo ""
    echo "Available HerbFargus Plymouth themes (in clone):"
    echo "-------------------------------------------------"
    find "$LOCAL_CLONE" -maxdepth 1 -mindepth 1 -type d ! -name '.*' | sort | \
        while IFS= read -r d; do echo "  • $(basename "$d")"; done
    echo ""
    echo "Installed Plymouth themes:"
    list_plymouth_themes | while read -r t; do echo "  • $t"; done
    exit 0
fi

# ── Install all themes from HerbFargus repo ───────────────────────────────────
info "Installing themes to ${THEMES_DIR}..."
mkdir -p "$THEMES_DIR"
INSTALLED=0

while IFS= read -r theme_dir; do
    theme_name=$(basename "$theme_dir")

    # Skip hidden directories (e.g. .git)
    [[ "$theme_name" == .* ]] && continue

    # Check for a .plymouth manifest using a proper glob expansion
    # Note: [[ -f glob ]] does NOT expand globs in bash — use a temp array instead
    MANIFESTS=( "${theme_dir}"/*.plymouth )
    if [[ ! -e "${MANIFESTS[0]}" ]]; then
        warn "  Skipping '${theme_name}' — no .plymouth manifest found"
        continue
    fi

    dest="${THEMES_DIR}/${theme_name}"
    rm -rf "$dest"
    cp -r "$theme_dir" "$dest"
    chmod -R 755 "$dest"
    INSTALLED=$((INSTALLED + 1))
    info "  Installed: ${theme_name}"

done < <(find "$LOCAL_CLONE" -maxdepth 1 -mindepth 1 -type d | sort)

info "Total themes installed: ${INSTALLED}"

if [[ $INSTALLED -eq 0 ]]; then
    warn "No themes were installed — check that the HerbFargus repo cloned correctly."
    warn "Clone path: ${LOCAL_CLONE}"
    ls -la "$LOCAL_CLONE" || true
fi

# ── Apply selected theme ──────────────────────────────────────────────────────
TARGET_THEME="${SET_THEME:-$ACTIVE_THEME}"
info "Setting active Plymouth theme: ${TARGET_THEME}"

# Build the list of available themes from the actual installed files
AVAILABLE_THEMES=$(list_plymouth_themes)

if echo "$AVAILABLE_THEMES" | grep -qx "$TARGET_THEME"; then
    set_plymouth_theme "$TARGET_THEME"
    success "Theme set to: ${TARGET_THEME}"
else
    warn "Theme '${TARGET_THEME}' not found in installed themes."
    info "Available themes:"
    echo "$AVAILABLE_THEMES" | while read -r t; do info "  • $t"; done

    # Pick best available fallback
    FALLBACK=""
    for candidate in "bgrt" "spinner" "text"; do
        if echo "$AVAILABLE_THEMES" | grep -qx "$candidate" 2>/dev/null; then
            FALLBACK="$candidate"
            break
        fi
    done

    if [[ -n "$FALLBACK" ]]; then
        warn "Falling back to theme: ${FALLBACK}"
        set_plymouth_theme "$FALLBACK"
        success "Fallback theme '${FALLBACK}' applied."
    else
        warn "No suitable fallback theme found — Plymouth will use system default."
    fi
fi

# ── Rebuild initramfs to embed the Plymouth theme ─────────────────────────────
info "Rebuilding initramfs (this embeds the Plymouth theme into the boot image)..."
update-initramfs -u -k all 2>&1 | tail -5

# ── Enable Plymouth startup services ─────────────────────────────────────────
info "Enabling Plymouth services..."
for svc in \
    plymouth-start.service \
    plymouth-read-write.service \
    plymouth-quit.service \
    plymouth-quit-wait.service; do
    systemctl enable "$svc" 2>/dev/null || true
done

# ── Write theme selection helper ──────────────────────────────────────────────
cat > /usr/local/bin/mediacade-set-splash << 'HELPER'
#!/usr/bin/env bash
# mediacade-set-splash — select and apply a Plymouth splash theme
# Usage: sudo mediacade-set-splash [theme-name]

THEMES_DIR="/usr/share/plymouth/themes"

list_themes() {
    find "$THEMES_DIR" -maxdepth 2 -name "*.plymouth" ! -name "default.plymouth" \
        -printf "%f\n" 2>/dev/null | sed 's/\.plymouth$//' | sort
}

get_current() {
    grep "^Theme=" /etc/plymouth/plymouthd.conf 2>/dev/null | cut -d= -f2 || \
    readlink "${THEMES_DIR}/default.plymouth" 2>/dev/null | \
        sed "s|${THEMES_DIR}/||;s|/.*||" || \
    echo "(unknown)"
}

if [[ -z "${1:-}" ]]; then
    CURRENT=$(get_current)
    echo "Available Plymouth themes:"
    list_themes | while read -r t; do
        if [[ "$t" == "$CURRENT" ]]; then
            echo "  → ${t}  (active)"
        else
            echo "    ${t}"
        fi
    done
    echo ""
    echo "Usage: sudo mediacade-set-splash <theme-name>"
    exit 0
fi

THEME="$1"
THEME_FILE="${THEMES_DIR}/${THEME}/${THEME}.plymouth"

if [[ ! -f "$THEME_FILE" ]]; then
    echo "Error: Theme '${THEME}' not found."
    echo "Run 'sudo mediacade-set-splash' to list available themes."
    exit 1
fi

PSDT=$(command -v plymouth-set-default-theme 2>/dev/null || \
       ls /usr/sbin/plymouth-set-default-theme 2>/dev/null || true)

if [[ -n "$PSDT" ]]; then
    "$PSDT" "$THEME"
else
    sed -i "s|^Theme=.*|Theme=${THEME}|" /etc/plymouth/plymouthd.conf 2>/dev/null || \
        echo "Theme=${THEME}" >> /etc/plymouth/plymouthd.conf
    ln -sfn "$THEME_FILE" "${THEMES_DIR}/default.plymouth" 2>/dev/null || true
fi

update-initramfs -u -k all
echo "✓ Splash theme set to: ${THEME}"
echo "  Reboot to apply."
HELPER
chmod +x /usr/local/bin/mediacade-set-splash

success "Plymouth configured ✓"
info "To change theme later:  sudo mediacade-set-splash <theme-name>"
info "To list themes:         sudo mediacade-set-splash"
