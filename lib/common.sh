#!/usr/bin/env bash
# Gemeenschappelijke functies — niet direct uitvoeren, maar sourcen vanuit harden.sh of audit.sh

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

readonly LOG_FILE="/var/log/cis-hardening.log"
readonly REQUIRED_UBUNTU_VERSION="24.04"

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*" | tee -a "$LOG_FILE"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[FOUT]${NC}  $*" | tee -a "$LOG_FILE" >&2; }
die()         { log_error "$*"; exit 1; }

require_root() {
    [[ $EUID -eq 0 ]] || die "Root-rechten vereist. Gebruik: sudo $0"
}

check_ubuntu_version() {
    local version
    version=$(lsb_release -rs 2>/dev/null) || die "Kan Ubuntu-versie niet bepalen (lsb_release ontbreekt)."
    if [[ "$version" != "$REQUIRED_UBUNTU_VERSION" ]]; then
        log_warn "Verwacht Ubuntu $REQUIRED_UBUNTU_VERSION, gevonden: $version. Ga op eigen risico verder."
    fi
}

# Controleert of USG beschikbaar is en installeert het indien nodig via Ubuntu Pro.
require_usg() {
    if command -v usg &>/dev/null; then
        log_info "USG gevonden: $(usg --version 2>/dev/null || echo 'versie onbekend')"
        return
    fi

    log_info "USG niet gevonden. Installatie via Ubuntu Pro wordt gestart..."

    if ! command -v pro &>/dev/null; then
        die "ubuntu-advantage-tools ontbreekt. Installeer met: sudo apt install ubuntu-advantage-tools"
    fi

    if ! pro status 2>/dev/null | grep -q "usg.*enabled"; then
        log_warn "Ubuntu Pro USG-service is niet actief."
        log_warn "Activeer gratis (tot 5 apparaten) op: https://ubuntu.com/pro"
        log_warn "Daarna: sudo pro enable usg"
        die "Activeer Ubuntu Pro USG en voer dit script opnieuw uit."
    fi

    apt-get install -y usg || die "Installatie van het usg-pakket mislukt."
    log_success "USG succesvol geïnstalleerd."
}

# Toont een menu en exporteert PROFILE (korte naam) en USG_PROFILE (usg-profielnaam).
select_profile() {
    echo
    echo "Selecteer CIS-profiel:"
    echo "  1) Level 1 Server  — aanbevolen baseline"
    echo "  2) Level 2 Server  — strenger, mogelijk impact op functionaliteit"
    echo "  q) Afsluiten"
    echo

    local choice
    read -rp "Keuze [1/2/q]: " choice

    case "$choice" in
        1) PROFILE="level1-server"; USG_PROFILE="cis_level1_server" ;;
        2) PROFILE="level2-server"; USG_PROFILE="cis_level2_server" ;;
        q|Q) log_info "Afgebroken door gebruiker."; exit 0 ;;
        *) die "Ongeldige keuze: '$choice'" ;;
    esac

    export PROFILE USG_PROFILE
}

# Bouwt de USG-argumentenlijst op, inclusief tailoring-bestand indien aanwezig.
# Gebruik: build_usg_args "$SCRIPT_DIR/tailoring"
# Resultaat wordt opgeslagen in de globale array USG_ARGS.
build_usg_args() {
    local tailoring_dir="$1"
    local tailoring_file="$tailoring_dir/${PROFILE}.xml"

    USG_ARGS=("$USG_PROFILE")

    if [[ -f "$tailoring_file" ]]; then
        log_info "Tailoring-bestand gevonden: $tailoring_file"
        USG_ARGS=("--tailoring-file" "$tailoring_file" "$USG_PROFILE")
    fi

    export USG_ARGS
}
