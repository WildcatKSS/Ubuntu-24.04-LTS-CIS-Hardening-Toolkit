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

# All interactive prompts live here — nothing after this line asks questions.
collect_answers audit
require_usg
ensure_packages w3m
build_usg_args "$SCRIPT_DIR/tailoring"

log info "Auditing profile: $USG_PROFILE"

# usg audit writes its default report to /var/lib/usg/usg-report-<DATE>.html;
# steer it to our path with --html-file so we don't have to guess.
# Exit code 1 means non-compliance (still produces a report) — don't abort on it.
usg audit --html-file "$REPORT_FILE" "${USG_ARGS[@]}" || true

if [[ -f "$REPORT_FILE" ]]; then
    log info "HTML report saved at: $REPORT_FILE"
else
    log err "USG produced no report at $REPORT_FILE — check the output above for errors."
    exit 1
fi

