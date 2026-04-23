#!/usr/bin/env bash
# Pas een CIS-profiel aan via de USG tailoring wizard.
# Het gegenereerde tailoring-bestand wordt automatisch geladen door harden.sh en audit.sh.
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
    log_warn "Er bestaat al een tailoring-bestand voor dit profiel:"
    log_warn "  $TAILORING_FILE"
    echo
    read -rp "Overschrijven met een nieuw tailoring-bestand? [j/N]: " confirm
    [[ "$confirm" =~ ^[jJ]$ ]] || { log_info "Afgebroken. Bestaand bestand blijft ongewijzigd."; exit 0; }
fi

echo
log_info "USG tailoring wizard wordt gestart voor profiel: $USG_PROFILE"
log_info "Er opent een browser waarin je per CIS-control kunt kiezen of deze actief is."
log_info "Sla de selectie op in de browser om het tailoring-bestand aan te maken."
echo

usg generate-tailoring "$USG_PROFILE" "$TAILORING_FILE"

echo
log_success "Tailoring-bestand opgeslagen: $TAILORING_FILE"
echo "Voer nu ./harden.sh of ./audit.sh uit — het bestand wordt automatisch gebruikt."
