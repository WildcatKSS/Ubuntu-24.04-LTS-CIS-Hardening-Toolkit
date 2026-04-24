#!/usr/bin/env bash
# Run a CIS compliance audit via USG without modifying the system.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly REPORT_DIR="/var/log/cis-audit"
readonly REPORT_FILE="$REPORT_DIR/report-$(date +%Y%m%d-%H%M%S).html"
readonly USG_REPORT="/var/lib/usg/usg-report.html"

init_logging "Audit"
mkdir -p "$REPORT_DIR"

require_root
check_ubuntu_version

# All interactive prompts live here — nothing after this line asks questions.
collect_answers audit
require_usg
build_usg_args "$SCRIPT_DIR/tailoring"

log info "Auditing profile: $USG_PROFILE"

# usg audit exits with code 1 on non-compliance; that is expected behaviour.
usg audit "${USG_ARGS[@]}" || true

if [[ -f "$USG_REPORT" ]]; then
    if cp -- "$USG_REPORT" "$REPORT_FILE"; then
        log info "HTML report saved at: $USG_REPORT"
        log info "Copy saved at:        $REPORT_FILE"
    else
        log warning "USG report exists at $USG_REPORT but could not be copied to $REPORT_FILE."
    fi
else
    log err "USG produced no report at $USG_REPORT — check the output above for errors."
    exit 1
fi

