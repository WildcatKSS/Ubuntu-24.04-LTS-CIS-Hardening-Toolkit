#!/usr/bin/env bash
# Apply CIS hardening via USG on an Ubuntu 24.04 LTS Server.
# Asks all questions up front, then runs unattended.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

init_logging "Hardening"

require_root
check_ubuntu_version

# All interactive prompts live here — nothing after this line asks questions.
collect_answers harden

system_update
require_usg
create_backup
build_usg_args "$SCRIPT_DIR/tailoring"

log info "Profile: $USG_PROFILE"
log info "Running USG fix..."

usg fix "${USG_ARGS[@]}"

log success "Hardening complete. Backup saved at: $BACKUP_FILE"

if [[ "${REBOOT_CHOICE:-no}" == "yes" ]]; then
    log notice "Auto-reboot requested — rebooting now..."
    reboot
else
    log info "Restart the system manually when ready: sudo reboot"
fi

log info "To roll back if needed: sudo ./rollback.sh"
