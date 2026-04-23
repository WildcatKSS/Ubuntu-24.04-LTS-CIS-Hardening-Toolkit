#!/usr/bin/env bash
# Restore the most recent pre-hardening backup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

mkdir -p "$(dirname "$LOG_FILE")"

require_root

# Find most recent backup
latest=$(ls -t "$BACKUP_DIR"/pre-hardening-*.tar.gz 2>/dev/null | head -1)
if [[ -z "$latest" ]]; then
    die "No backup found in $BACKUP_DIR. Nothing to restore."
fi

echo
log_warn "This will restore system configuration from the following backup:"
log_warn "  $latest"
log_warn "Modified configuration files will be overwritten."
echo

read -rp "Are you sure? [y/N]: " confirm
[[ "$confirm" =~ ^[yY]$ ]] || { log_info "Aborted. No changes made."; exit 0; }

echo "=== Rollback started: $(date) ===" >> "$LOG_FILE"
log_info "Restoring from: $latest"

tar -xzf "$latest" -C / 2>/dev/null \
    || log_warn "Some files could not be restored."

log_success "Rollback complete."
echo
echo "Restart the system to activate the restored configuration:"
echo "  sudo reboot"
