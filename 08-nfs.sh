#!/usr/bin/env bash
# =============================================================================
# 08-nfs.sh — NFS Server and/or Client configuration for ROMs sharing
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/../retropie.cfg"
RETROPIE_HOME="$(getent passwd "${RETROPIE_USER}" | cut -d: -f6)"
ROMS_DIR="${NFS_ROMS_PATH:-${RETROPIE_HOME}/RetroPie/roms}"

info()    { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
success() { echo -e "\033[0;32m[OK]\033[0m    $*"; }
warn()    { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error()   { echo -e "\033[0;31m[ERROR]\033[0m $*"; exit 1; }

NFS_ROLE="${NFS_ROLE:-none}"
info "NFS role: ${NFS_ROLE}"

[[ "$NFS_ROLE" == "none" ]] && { info "NFS disabled — skipping."; exit 0; }

# ── Install NFS packages ───────────────────────────────────────────────────────
info "Installing NFS packages..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    nfs-kernel-server \
    nfs-common \
    rpcbind

# ── NFS SERVER setup ──────────────────────────────────────────────────────────
setup_server() {
    info "Configuring NFS server..."

    # Ensure ROMs directory exists and is owned by retropie user
    mkdir -p "$ROMS_DIR"
    chown -R "${RETROPIE_USER}:${RETROPIE_USER}" "$(dirname "$ROMS_DIR")"
    chmod 755 "$ROMS_DIR"

    SUBNET="${NFS_EXPORT_SUBNET:-192.168.1.0/24}"
    EXPORTS_FILE="/etc/exports"

    # Backup existing exports
    cp "$EXPORTS_FILE" "${EXPORTS_FILE}.bak" 2>/dev/null || true

    # Remove any existing retropie export entry
    sed -i '/# RetroPie-X86/,/# END RetroPie-X86/d' "$EXPORTS_FILE" 2>/dev/null || true
    grep -v "^${ROMS_DIR}" "$EXPORTS_FILE" > /tmp/exports.tmp && mv /tmp/exports.tmp "$EXPORTS_FILE" 2>/dev/null || true

    # Add new export
    cat >> "$EXPORTS_FILE" << EOF

# RetroPie-X86 ROMs share
${ROMS_DIR} ${SUBNET}(rw,sync,no_subtree_check,no_root_squash,anonuid=$(id -u "${RETROPIE_USER}"),anongid=$(id -g "${RETROPIE_USER}"))
# END RetroPie-X86
EOF

    info "NFS export: ${ROMS_DIR} → ${SUBNET}"

    # Enable and start NFS services
    systemctl enable rpcbind nfs-kernel-server
    systemctl restart rpcbind
    systemctl restart nfs-kernel-server

    # Apply exports
    exportfs -arv

    success "NFS server configured ✓"
    info "ROMs path: ${ROMS_DIR}"
    info "Exported to: ${SUBNET}"

    # Show server IP for clients
    SERVER_IP=$(hostname -I | awk '{print $1}')
    info "Server IP: ${SERVER_IP} — use this in NFS_SERVER_IP on client machines"
}

# ── NFS CLIENT setup ──────────────────────────────────────────────────────────
setup_client() {
    info "Configuring NFS client..."

    SERVER_IP="${NFS_SERVER_IP:?NFS_SERVER_IP must be set in retropie.cfg for client mode}"
    MOUNT_OPTS="${NFS_MOUNT_OPTIONS:-rw,sync,hard,intr,timeo=14}"
    LOCAL_MOUNT="${ROMS_DIR}"

    # Create local mount point
    mkdir -p "$LOCAL_MOUNT"
    chown "${RETROPIE_USER}:${RETROPIE_USER}" "$LOCAL_MOUNT"

    # Backup fstab
    cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d%H%M%S)

    # Remove any existing retropie NFS fstab entry
    sed -i '/# RetroPie-X86 NFS/d' /etc/fstab

    # Add fstab entry for NFS ROMs mount
    cat >> /etc/fstab << EOF

# RetroPie-X86 NFS ROMs share
${SERVER_IP}:${ROMS_DIR}    ${LOCAL_MOUNT}    nfs    ${MOUNT_OPTS},x-systemd.automount,x-systemd.requires=network-online.target    0    0
EOF

    info "fstab entry added: ${SERVER_IP}:${ROMS_DIR} → ${LOCAL_MOUNT}"

    # Reload systemd to pick up fstab changes
    systemctl daemon-reload

    # Create systemd network-online dependency for NFS
    SYSTEMD_NFS_WAIT="/etc/systemd/system/network-online.target.wants"
    mkdir -p "$SYSTEMD_NFS_WAIT"
    systemctl enable systemd-networkd-wait-online.service 2>/dev/null || true

    # Test mount (non-fatal — server may not be online)
    info "Testing NFS mount (server must be reachable)..."
    if mount "${LOCAL_MOUNT}" 2>/dev/null; then
        success "NFS mount successful ✓"
        df -h "$LOCAL_MOUNT"
    else
        warn "NFS mount test failed — this is OK if server is offline."
        warn "Mount will happen automatically at boot when server is available."
    fi

    success "NFS client configured ✓"
}

# ── Dispatch ──────────────────────────────────────────────────────────────────
case "$NFS_ROLE" in
    server) setup_server ;;
    client) setup_client ;;
    both)   setup_server; setup_client ;;
    none)   info "NFS disabled." ;;
    *)      error "Unknown NFS_ROLE: ${NFS_ROLE}. Use: server | client | both | none" ;;
esac

info "NFS configuration complete ✓"
