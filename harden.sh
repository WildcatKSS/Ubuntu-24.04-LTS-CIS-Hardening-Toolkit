#!/usr/bin/env bash
# Pas CIS-hardening toe via USG op een Ubuntu 24.04 LTS Server.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

mkdir -p "$(dirname "$LOG_FILE")"
echo "=== Hardening gestart: $(date) ===" >> "$LOG_FILE"

require_root
check_ubuntu_version
setup_ubuntu_pro
require_usg
select_profile
create_backup
build_usg_args "$SCRIPT_DIR/tailoring"

log_info "Profiel: $USG_PROFILE"
log_info "USG fix wordt uitgevoerd..."

usg fix "${USG_ARGS[@]}"

log_success "Hardening voltooid. Back-up bewaard in: $BACKUP_FILE"
echo
echo "Herstart het systeem om alle wijzigingen door te voeren:"
echo "  sudo reboot"
echo
echo "Terugdraaien indien nodig:"
echo "  sudo ./rollback.sh"
