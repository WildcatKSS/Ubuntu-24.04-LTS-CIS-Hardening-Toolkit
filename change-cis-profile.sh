#!/usr/bin/env bash
# Customise a CIS profile via the USG tailoring wizard.
# The generated tailoring file is automatically loaded by harden.sh and audit.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

mkdir -p "$(dirname "$LOG_FILE")"

require_root
check_ubuntu_version
require_usg
select_profile

TAILORING_FILE="$SCRIPT_DIR/tailoring/${PROFILE}.xml"

if [[ -f "$TAILORING_FILE" ]]; then
    echo
    log_warn "A tailoring file already exists for this profile:"
    log_warn "  $TAILORING_FILE"
    echo
    read -rp "Overwrite with a new tailoring file? [y/N]: " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || { log_info "Aborted. Existing file unchanged."; exit 0; }
fi

echo
log_info "Starting USG tailoring wizard for profile: $USG_PROFILE"
log_info "A browser will open where you can enable or disable individual CIS controls."
log_info "Save your selection in the browser to generate the tailoring file."
echo

usg generate-tailoring "$USG_PROFILE" "$TAILORING_FILE"

echo
log_success "Tailoring file saved: $TAILORING_FILE"
echo "Run ./harden.sh or ./audit.sh — the file will be loaded automatically."
