#!/usr/bin/env bash
# Shared functions — do not execute directly; source from harden.sh or audit.sh

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
log_error()   { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2; }
die()         { log_error "$*"; exit 1; }

require_root() {
    [[ $EUID -eq 0 ]] || die "Root privileges required. Use: sudo $0"
}

check_ubuntu_version() {
    local version
    version=$(lsb_release -rs 2>/dev/null) || die "Cannot determine Ubuntu version (lsb_release missing)."
    if [[ "$version" != "$REQUIRED_UBUNTU_VERSION" ]]; then
        log_warn "Expected Ubuntu $REQUIRED_UBUNTU_VERSION, found: $version. Proceeding at your own risk."
    fi
}

# Ensures Ubuntu Pro is attached and the USG service is enabled.
# Guides the user interactively: ubuntu-advantage-tools → pro attach → pro enable usg.
setup_ubuntu_pro() {
    echo
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│           Ubuntu Pro & USG Setup                    │"
    echo "│                                                     │"
    echo "│  USG requires Ubuntu Pro (free for up to 5 PCs).  │"
    echo "│  Get your token at: https://ubuntu.com/pro         │"
    echo "└─────────────────────────────────────────────────────┘"
    echo

    # Step 1 — ubuntu-advantage-tools
    if ! command -v pro &>/dev/null; then
        log_info "[1/3] Installing ubuntu-advantage-tools..."
        apt-get install -y ubuntu-advantage-tools \
            || die "Failed to install ubuntu-advantage-tools."
        log_success "[1/3] ubuntu-advantage-tools installed."
    else
        log_info "[1/3] ubuntu-advantage-tools already present."
    fi

    # Step 2 — Attach Ubuntu Pro
    if ! pro status 2>/dev/null | grep -q "This machine is attached"; then
        log_info "[2/3] Ubuntu Pro is not yet attached to this system."
        echo "      Get your free token at: https://ubuntu.com/pro"
        echo
        local pro_token
        read -rp "      Enter your Ubuntu Pro token: " pro_token
        [[ -n "$pro_token" ]] || die "No token provided. Aborting."
        pro attach "$pro_token" \
            || die "Ubuntu Pro attach failed. Check your token and try again."
        log_success "[2/3] Ubuntu Pro attached successfully."
    else
        log_info "[2/3] Ubuntu Pro is already attached."
    fi

    # Step 3 — Enable USG service
    if ! pro status 2>/dev/null | grep -q "usg.*enabled"; then
        log_info "[3/3] Enabling USG service via Ubuntu Pro..."
        pro enable usg || die "Failed to enable the USG service."
        log_success "[3/3] USG service enabled."
    else
        log_info "[3/3] USG service is already enabled."
    fi

    echo
    log_success "Ubuntu Pro and USG service are active."
    echo
}

# Checks whether the usg package is installed; installs it if not.
# Calls setup_ubuntu_pro() when USG is not yet present.
require_usg() {
    if command -v usg &>/dev/null; then
        log_info "USG found: $(usg --version 2>/dev/null || echo 'version unknown')"
        return
    fi

    log_info "USG not found — starting setup..."
    setup_ubuntu_pro

    log_info "Installing USG package..."
    apt-get install -y usg || die "Failed to install the usg package."
    log_success "USG package installed."
}

# Backs up system configuration files typically modified by USG.
# Saves the backup to $BACKUP_DIR and exports BACKUP_FILE.
create_backup() {
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/pre-hardening-${timestamp}.tar.gz"

    mkdir -p "$BACKUP_DIR"
    log_info "Backing up system configuration..."

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
        || log_warn "Some files could not be included in the backup."

    export BACKUP_FILE="$backup_file"
    log_success "Backup saved: $backup_file"
}

# Displays a profile selection menu and exports PROFILE (short name) and USG_PROFILE (usg profile name).
select_profile() {
    echo
    echo "Select CIS profile:"
    echo "  1) Level 1 Server  — recommended baseline"
    echo "  2) Level 2 Server  — stricter, may impact functionality"
    echo "  q) Quit"
    echo

    local choice
    read -rp "Choice [1/2/q]: " choice

    case "$choice" in
        1) PROFILE="level1-server"; USG_PROFILE="cis_level1_server" ;;
        2) PROFILE="level2-server"; USG_PROFILE="cis_level2_server" ;;
        q|Q) log_info "Aborted by user."; exit 0 ;;
        *) die "Invalid choice: '$choice'" ;;
    esac

    export PROFILE USG_PROFILE
}

# Builds the USG argument list, including a tailoring file when present.
# Usage: build_usg_args "$SCRIPT_DIR/tailoring"
# Result is stored in the global array USG_ARGS.
build_usg_args() {
    local tailoring_dir="$1"
    local tailoring_file="$tailoring_dir/${PROFILE}.xml"

    USG_ARGS=("$USG_PROFILE")

    if [[ -f "$tailoring_file" ]]; then
        log_info "Tailoring file found: $tailoring_file"
        USG_ARGS=("--tailoring-file" "$tailoring_file" "$USG_PROFILE")
    fi

    export USG_ARGS
}
