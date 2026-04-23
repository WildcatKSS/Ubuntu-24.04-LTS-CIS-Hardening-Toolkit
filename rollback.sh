#!/usr/bin/env bash
# Restore the most recent pre-hardening backup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

init_logging "Rollback"

require_root

# Find most recent backup
latest=$(ls -t "$BACKUP_DIR"/pre-hardening-*.tar.gz 2>/dev/null | head -1)
if [[ -z "$latest" ]]; then
    die "No backup found in $BACKUP_DIR. Nothing to restore."
fi

echo
log warning "This will restore system configuration from the following backup:"
log warning "  $latest"
log warning "Modified configuration files will be overwritten."
echo

read -rp "Are you sure? [y/N]: " confirm
[[ "$confirm" =~ ^[yY]$ ]] || { log info "Aborted. No changes made."; exit 0; }

log info "Restoring from: $latest"

tar -xzf "$latest" -C / 2>/dev/null \
    || log warning "Some files could not be restored."

log success "Rollback complete."
log info "Restart the system to activate the restored configuration: sudo reboot"
