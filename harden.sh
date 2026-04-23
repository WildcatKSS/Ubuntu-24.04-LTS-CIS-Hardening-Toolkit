#!/usr/bin/env bash
# Apply CIS hardening via USG on an Ubuntu 24.04 LTS Server.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

mkdir -p "$(dirname "$LOG_FILE")"
echo "=== Hardening started: $(date) ===" >> "$LOG_FILE"

require_root
check_ubuntu_version
setup_ubuntu_pro
require_usg
select_profile
create_backup
build_usg_args "$SCRIPT_DIR/tailoring"

log_info "Profile: $USG_PROFILE"
log_info "Running USG fix..."

usg fix "${USG_ARGS[@]}"

log_success "Hardening complete. Backup saved at: $BACKUP_FILE"
echo
read -rp "Restart the system now to apply all changes? [y/N] " answer
if [[ "${answer,,}" =~ ^y(es)?$ ]]; then
    log_info "Rebooting system..."
    reboot
else
    echo "Restart the system manually when ready:"
    echo "  sudo reboot"
fi
echo
echo "To roll back if needed:"
echo "  sudo ./rollback.sh"
