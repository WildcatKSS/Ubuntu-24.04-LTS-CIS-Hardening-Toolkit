#!/usr/bin/env bash
# Zet de meest recente pre-hardening back-up terug.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

mkdir -p "$(dirname "$LOG_FILE")"

require_root

# Zoek meest recente back-up
latest=$(ls -t "$BACKUP_DIR"/pre-hardening-*.tar.gz 2>/dev/null | head -1)
if [[ -z "$latest" ]]; then
    die "Geen back-up gevonden in $BACKUP_DIR. Niets om terug te zetten."
fi

echo
log_warn "Dit zet systeemconfiguratie terug uit de volgende back-up:"
log_warn "  $latest"
log_warn "Gewijzigde configuraties worden overschreven."
echo

read -rp "Weet je het zeker? [j/N]: " confirm
[[ "$confirm" =~ ^[jJ]$ ]] || { log_info "Afgebroken. Geen wijzigingen aangebracht."; exit 0; }

echo "=== Rollback gestart: $(date) ===" >> "$LOG_FILE"
log_info "Terugzetten van: $latest"

tar -xzf "$latest" -C / 2>/dev/null \
    || log_warn "Sommige bestanden konden niet worden teruggezet."

log_success "Rollback voltooid."
echo
echo "Herstart het systeem om de herstelde configuratie te activeren:"
echo "  sudo reboot"
