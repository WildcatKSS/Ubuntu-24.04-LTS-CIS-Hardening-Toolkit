#!/usr/bin/env bash
# Voer een CIS-compliance audit uit via USG zonder het systeem te wijzigen.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly REPORT_DIR="/var/log/cis-audit"
readonly REPORT_FILE="$REPORT_DIR/rapport-$(date +%Y%m%d-%H%M%S).html"

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$REPORT_DIR"
echo "=== Audit gestart: $(date) ===" >> "$LOG_FILE"

require_root
check_ubuntu_version
require_usg
select_profile
build_usg_args "$SCRIPT_DIR/tailoring"

log_info "Audit voor profiel: $USG_PROFILE"

# usg audit geeft exitcode 1 bij non-compliance; dat is verwacht gedrag
usg audit "${USG_ARGS[@]}" || true

log_info "HTML-rapport opgeslagen in: /var/lib/usg/usg-report.html"
log_info "Kopie bewaard in: $REPORT_FILE"
cp /var/lib/usg/usg-report.html "$REPORT_FILE" 2>/dev/null || true
