#!/usr/bin/env bash
# Customise a CIS profile via the USG tailoring wizard.
# The generated tailoring file is automatically loaded by harden.sh and audit.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

init_logging "Tailoring"

require_root
check_ubuntu_version
require_usg

# Profile selection up front.
collect_answers tailoring

TAILORING_FILE="$SCRIPT_DIR/tailoring/${PROFILE}.xml"

if [[ -f "$TAILORING_FILE" ]]; then
    echo
    log warning "A tailoring file already exists for this profile:"
    log warning "  $TAILORING_FILE"
    echo
    read -rp "Overwrite with a new tailoring file? [y/N]: " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || { log info "Aborted. Existing file unchanged."; exit 0; }
fi

log info "Starting USG tailoring wizard for profile: $USG_PROFILE"
log info "A browser will open where you can enable or disable individual CIS controls."
log info "Save your selection in the browser to generate the tailoring file."

usg generate-tailoring "$USG_PROFILE" "$TAILORING_FILE"

log success "Tailoring file saved: $TAILORING_FILE"
log info "Run ./harden.sh or ./audit.sh — the file will be loaded automatically."
