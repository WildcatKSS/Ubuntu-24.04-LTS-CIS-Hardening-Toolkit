#!/usr/bin/env bash
# Gemeenschappelijke functies — niet direct uitvoeren, maar sourcen vanuit harden.sh of audit.sh

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

readonly LOG_FILE="/var/log/cis-hardening.log"
readonly BACKUP_DIR="/var/backups/cis-hardening"
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

# Zorgt dat Ubuntu Pro is geactiveerd en de USG-service is ingeschakeld.
# Leidt de gebruiker interactief door: ubuntu-advantage-tools → pro attach → pro enable usg.
setup_ubuntu_pro() {
    echo
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│           Ubuntu Pro & USG Setup                    │"
    echo "│                                                     │"
    echo "│  USG vereist Ubuntu Pro (gratis tot 5 apparaten).  │"
    echo "│  Token ophalen: https://ubuntu.com/pro             │"
    echo "└─────────────────────────────────────────────────────┘"
    echo

    # Stap 1 — ubuntu-advantage-tools
    if ! command -v pro &>/dev/null; then
        log_info "[1/3] ubuntu-advantage-tools installeren..."
        apt-get install -y ubuntu-advantage-tools \
            || die "Installatie van ubuntu-advantage-tools mislukt."
        log_success "[1/3] ubuntu-advantage-tools geïnstalleerd."
    else
        log_info "[1/3] ubuntu-advantage-tools aanwezig."
    fi

    # Stap 2 — Ubuntu Pro activeren (attach)
    if ! pro status 2>/dev/null | grep -q "This machine is attached"; then
        log_info "[2/3] Ubuntu Pro is nog niet geactiveerd op dit systeem."
        echo "      Haal je gratis token op via: https://ubuntu.com/pro"
        echo
        local pro_token
        read -rp "      Voer je Ubuntu Pro token in: " pro_token
        [[ -n "$pro_token" ]] || die "Geen token opgegeven. Afgebroken."
        pro attach "$pro_token" \
            || die "Ubuntu Pro activering mislukt. Controleer je token en probeer opnieuw."
        log_success "[2/3] Ubuntu Pro succesvol geactiveerd."
    else
        log_info "[2/3] Ubuntu Pro is al geactiveerd."
    fi

    # Stap 3 — USG service inschakelen
    if ! pro status 2>/dev/null | grep -q "usg.*enabled"; then
        log_info "[3/3] USG service activeren via Ubuntu Pro..."
        pro enable usg || die "Activeren van USG service mislukt."
        log_success "[3/3] USG service ingeschakeld."
    else
        log_info "[3/3] USG service is al ingeschakeld."
    fi

    echo
    log_success "Ubuntu Pro en USG service zijn actief."
    echo
}

# Controleert of het usg-pakket geïnstalleerd is; installeert het indien nodig.
# Roept setup_ubuntu_pro() aan als USG nog niet aanwezig is.
require_usg() {
    if command -v usg &>/dev/null; then
        log_info "USG gevonden: $(usg --version 2>/dev/null || echo 'versie onbekend')"
        return
    fi

    log_info "USG niet gevonden — setup starten..."
    setup_ubuntu_pro

    log_info "USG pakket installeren..."
    apt-get install -y usg || die "Installatie van het usg-pakket mislukt."
    log_success "USG pakket geïnstalleerd."
}

# Maakt een back-up van systeemconfiguraties die USG typisch wijzigt.
# Slaat de back-up op in $BACKUP_DIR en exporteert BACKUP_FILE.
create_backup() {
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/pre-hardening-${timestamp}.tar.gz"

    mkdir -p "$BACKUP_DIR"
    log_info "Back-up maken van systeemconfiguratie..."

    local paths_to_backup=(
        /etc/ssh
        /etc/pam.d
        /etc/security
        /etc/sysctl.conf
        /etc/sysctl.d
        /etc/audit
        /etc/rsyslog.conf
        /etc/rsyslog.d
        /etc/modprobe.d
        /etc/login.defs
        /etc/sudoers
        /etc/sudoers.d
        /etc/cron.d
        /etc/cron.daily
        /etc/cron.weekly
        /etc/fstab
        /boot/grub/grub.cfg
    )

    local existing=()
    for path in "${paths_to_backup[@]}"; do
        [[ -e "$path" ]] && existing+=("$path")
    done

    tar -czf "$backup_file" "${existing[@]}" 2>/dev/null \
        || log_warn "Sommige bestanden konden niet worden meegenomen in de back-up."

    export BACKUP_FILE="$backup_file"
    log_success "Back-up opgeslagen: $backup_file"
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
