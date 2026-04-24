#!/usr/bin/env bash
# Run a CIS compliance audit via USG without modifying the system.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

readonly REPORT_DIR="/var/log/cis-audit"
readonly REPORT_FILE="$REPORT_DIR/report-$(date +%Y%m%d-%H%M%S).html"

init_logging "Audit"
mkdir -p "$REPORT_DIR"

require_root
check_ubuntu_version
require_usg

# Single question up front — the rest runs unattended.
collect_answers audit
build_usg_args "$SCRIPT_DIR/tailoring"

log info "Auditing profile: $USG_PROFILE"

# usg audit exits with code 1 on non-compliance; that is expected behaviour.
# A missing report, however, means the audit itself failed — surface that.
readonly USG_REPORT="/var/lib/usg/usg-report.html"
usg audit "${USG_ARGS[@]}" || true

[[ -s "$USG_REPORT" ]] \
    || die "Audit did not produce a report at $USG_REPORT — usg audit likely failed."

log info "HTML report saved at: $USG_REPORT"
log info "Copy saved at: $REPORT_FILE"
cp "$USG_REPORT" "$REPORT_FILE" \
    || die "Failed to copy report to $REPORT_FILE."
