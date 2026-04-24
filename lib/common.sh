#!/usr/bin/env bash
# Shared functions — do not execute directly; source from harden.sh or audit.sh

# ─────────────────────────────────────────────────────────────────────────────
# Logging — syslog-style levels 0..7 with per-level colour
# ─────────────────────────────────────────────────────────────────────────────

readonly LOG_NAMES=(emerg alert crit err warning notice info debug)
readonly LOG_COLORS=(
    $'\033[1;97;41m'   # 0 emerg   — bright white on red background
    $'\033[1;31m'      # 1 alert   — bold red
    $'\033[0;35m'      # 2 crit    — magenta
    $'\033[0;31m'      # 3 err     — red
    $'\033[1;33m'      # 4 warning — yellow
    $'\033[0;36m'      # 5 notice  — cyan
    $'\033[0;34m'      # 6 info    — blue
    $'\033[0;90m'      # 7 debug   — grey
)
readonly NC=$'\033[0m'

# Backwards-compatible aliases (still referenced elsewhere or by users)
# shellcheck disable=SC2034  # kept for external callers that source this file
readonly RED="${LOG_COLORS[3]}"
# shellcheck disable=SC2034
readonly GREEN=$'\033[0;32m'
# shellcheck disable=SC2034
readonly YELLOW="${LOG_COLORS[4]}"
# shellcheck disable=SC2034
readonly BLUE="${LOG_COLORS[6]}"

readonly LOG_FILE="/var/log/cis-hardening.log"
readonly BACKUP_DIR="/var/backups/cis-hardening"
readonly REQUIRED_UBUNTU_VERSION="24.04"

: "${LOG_LEVEL:=7}"          # default: log everything
: "${SYSLOG_ENABLED:=1}"     # default: forward to syslog via logger

# Resolve a level argument (number 0..7 or name) to a numeric value.
# Prints the number on stdout, returns non-zero on unknown input.
_resolve_level() {
    local in="$1"
    if [[ "$in" =~ ^[0-7]$ ]]; then
        printf '%s' "$in"
        return 0
    fi
    # "success" is not a syslog level; alias it to notice so that
    # `log success "..."` call sites resolve cleanly under `set -e`.
    if [[ "$in" == "success" ]]; then
        printf '%s' 5
        return 0
    fi
    local i
    for i in "${!LOG_NAMES[@]}"; do
        if [[ "${LOG_NAMES[$i]}" == "$in" ]]; then
            printf '%s' "$i"
            return 0
        fi
    done
    return 1
}

# Unified logger: log <level> <message...>
#   level : 0..7 or one of emerg|alert|crit|err|warning|notice|info|debug
#   writes to stderr for warning+ (<=4), stdout otherwise, and
#   appends a non-coloured line to $LOG_FILE. Also forwards to syslog
#   via `logger` when $SYSLOG_ENABLED=1.
log() {
    local lvl_in="$1"; shift || true
    local lvl
    if ! lvl=$(_resolve_level "$lvl_in"); then
        printf 'log: unknown level: %s\n' "$lvl_in" >&2
        return 1
    fi
    (( lvl <= LOG_LEVEL )) || return 0

    local name="${LOG_NAMES[$lvl]}"
    local color="${LOG_COLORS[$lvl]}"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local msg="$*"

    # Terminal output (coloured). warnings and above go to stderr.
    if (( lvl <= 4 )); then
        printf '%s[%s] [%-7s]%s %s\n' "$color" "$ts" "$name" "$NC" "$msg" >&2
    else
        printf '%s[%s] [%-7s]%s %s\n' "$color" "$ts" "$name" "$NC" "$msg"
    fi

    # File output (no ANSI, grep-friendly).
    if [[ -n "${LOG_FILE:-}" ]]; then
        printf '[%s] [%-7s] %s\n' "$ts" "$name" "$msg" >> "$LOG_FILE" 2>/dev/null || true
    fi

    # Syslog forwarding.
    if (( SYSLOG_ENABLED )) && command -v logger >/dev/null 2>&1; then
        logger -t cis-hardening -p "user.$name" -- "$msg" 2>/dev/null || true
    fi
}

# Backwards-compatible wrappers — existing scripts keep working.
log_info()    { log info    "$*"; }
log_warn()    { log warning "$*"; }
log_error()   { log err     "$*"; }
log_success() { log notice  "$*"; }
die()         { log err "$*"; exit 1; }

# Prepares the log file directory and writes a session banner.
# Usage: init_logging "Hardening"
init_logging() {
    local label="${1:-Session}"
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE" 2>/dev/null || true
    {
        printf '\n=== %s started: %s (pid=%s) ===\n' \
            "$label" "$(date '+%Y-%m-%d %H:%M:%S')" "$$"
    } >> "$LOG_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Preflight
# ─────────────────────────────────────────────────────────────────────────────

require_root() {
    [[ $EUID -eq 0 ]] || die "Root privileges required. Use: sudo $0"
}

check_ubuntu_version() {
    local version
    version=$(lsb_release -rs 2>/dev/null) || die "Cannot determine Ubuntu version (lsb_release missing)."
    if [[ "$version" != "$REQUIRED_UBUNTU_VERSION" ]]; then
        log warning "Expected Ubuntu $REQUIRED_UBUNTU_VERSION, found: $version. Proceeding at your own risk."
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Upfront interactive questions — gather all input so the rest runs unattended
# ─────────────────────────────────────────────────────────────────────────────

# Gather every answer the hardening run needs BEFORE starting any work.
# Sets globals: PROFILE, USG_PROFILE, PRO_TOKEN (optional), REBOOT_CHOICE.
# Pass "audit" / "tailoring" to skip reboot and Pro-token prompts.
collect_answers() {
    local mode="${1:-harden}"

    echo
    echo "┌─────────────────────────────────────────────────────┐"
    echo "│   Please answer a few questions up front.           │"
    echo "│   After this, the script runs unattended.           │"
    echo "└─────────────────────────────────────────────────────┘"
    echo

    # ── Profile ─────────────────────────────────────────────────────────────
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
        q|Q) log info "Aborted by user."; exit 0 ;;
        *) die "Invalid choice: '$choice'" ;;
    esac
    export PROFILE USG_PROFILE

    # ── Ubuntu Pro token (only if hardening and not yet attached) ───────────
    PRO_TOKEN=""
    if [[ "$mode" == "harden" ]]; then
        if ! pro_is_attached; then
            echo
            echo "Ubuntu Pro is not yet attached to this system."
            echo "USG requires Ubuntu Pro (free for up to 5 machines)."
            echo "Get your token at: https://ubuntu.com/pro"
            echo
            read -rp "Enter your Ubuntu Pro token: " PRO_TOKEN
            [[ -n "$PRO_TOKEN" ]] || die "No Ubuntu Pro token provided. Aborting."
        fi
        export PRO_TOKEN
    fi

    # ── Reboot preference (hardening only) ──────────────────────────────────
    REBOOT_CHOICE="no"
    if [[ "$mode" == "harden" ]]; then
        echo
        local answer
        read -rp "Restart the system automatically when hardening finishes? [y/N] " answer
        if [[ "${answer,,}" =~ ^y(es)?$ ]]; then
            REBOOT_CHOICE="yes"
        fi
    fi
    export REBOOT_CHOICE

    # ── Summary ─────────────────────────────────────────────────────────────
    echo
    log info "Answers collected — starting unattended run"
    log info "  Profile        : $PROFILE ($USG_PROFILE)"
    if [[ "$mode" == "harden" ]]; then
        if [[ -n "$PRO_TOKEN" ]]; then
            log info "  Ubuntu Pro     : token supplied, will attach"
        else
            log info "  Ubuntu Pro     : already attached"
        fi
        log info "  Auto-reboot    : $REBOOT_CHOICE"
    fi
    echo
}

# ─────────────────────────────────────────────────────────────────────────────
# Ubuntu full update (apt update + upgrade + dist-upgrade + autoremove)
# ─────────────────────────────────────────────────────────────────────────────

system_update() {
    log notice "Running full Ubuntu update before hardening..."
    export DEBIAN_FRONTEND=noninteractive
    local apt_opts=(-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

    log info "[1/4] apt-get update"
    apt-get update || die "apt-get update failed."

    log info "[2/4] apt-get upgrade"
    apt-get "${apt_opts[@]}" upgrade || die "apt-get upgrade failed."

    log info "[3/4] apt-get dist-upgrade"
    apt-get "${apt_opts[@]}" dist-upgrade || die "apt-get dist-upgrade failed."

    log info "[4/4] apt-get autoremove"
    apt-get "${apt_opts[@]}" autoremove || log warning "apt-get autoremove reported a non-zero exit."

    log success "System is fully up to date."
}

# ─────────────────────────────────────────────────────────────────────────────
# Ubuntu Pro + USG setup
# ─────────────────────────────────────────────────────────────────────────────

# Returns 0 when this host is already attached to Ubuntu Pro, 1 otherwise.
# Uses `pro status --format json` because the plain-text output no longer
# contains the "This machine is attached" string on current pro-client
# releases shipped with Ubuntu 24.04.
pro_is_attached() {
    command -v pro >/dev/null 2>&1 || return 1
    local json
    json="$(pro status --format json 2>/dev/null)" || return 1
    grep -Eq '"attached"[[:space:]]*:[[:space:]]*true' <<<"$json"
}

# Ensures Ubuntu Pro is attached and the USG service is enabled.
# Uses the pre-collected $PRO_TOKEN from collect_answers() — does NOT prompt.
setup_ubuntu_pro() {
    echo
    log info "Ubuntu Pro & USG setup"

    # Step 1 — ubuntu-advantage-tools
    if ! command -v pro &>/dev/null; then
        log info "[1/3] Installing ubuntu-advantage-tools..."
        apt-get install -y ubuntu-advantage-tools \
            || die "Failed to install ubuntu-advantage-tools."
        log success "[1/3] ubuntu-advantage-tools installed."
    else
        log info "[1/3] ubuntu-advantage-tools already present."
    fi

    # Step 2 — Attach Ubuntu Pro
    if pro_is_attached; then
        log info "[2/3] Ubuntu Pro is already attached."
    else
        [[ -n "${PRO_TOKEN:-}" ]] \
            || die "Ubuntu Pro not attached and no token collected. Re-run and provide a token."
        log info "[2/3] Attaching Ubuntu Pro with collected token..."
        local attach_out
        if attach_out="$(pro attach "$PRO_TOKEN" 2>&1)"; then
            printf '%s\n' "$attach_out"
            log success "[2/3] Ubuntu Pro attached successfully."
        elif grep -qi "already attached" <<<"$attach_out"; then
            # Safety net: host was attached between our check and this call,
            # or detection still failed on an exotic pro-client version.
            printf '%s\n' "$attach_out"
            log info "[2/3] Ubuntu Pro was already attached — continuing."
        else
            printf '%s\n' "$attach_out" >&2
            die "Ubuntu Pro attach failed. Check your token and try again."
        fi
    fi

    # Step 3 — Enable USG service
    if ! pro status 2>/dev/null | grep -q "usg.*enabled"; then
        log info "[3/3] Enabling USG service via Ubuntu Pro..."
        pro enable usg || die "Failed to enable the USG service."
        log success "[3/3] USG service enabled."
    else
        log info "[3/3] USG service is already enabled."
    fi

    log success "Ubuntu Pro and USG service are active."
}

# Checks whether the usg package is installed; installs it if not.
# Calls setup_ubuntu_pro() when USG is not yet present.
require_usg() {
    if command -v usg &>/dev/null; then
        log info "USG found: $(usg --version 2>/dev/null || echo 'version unknown')"
        return
    fi

    log info "USG not found — starting setup..."
    setup_ubuntu_pro

    log info "Installing USG package..."
    apt-get install -y usg || die "Failed to install the usg package."
    log success "USG package installed."
}

# ─────────────────────────────────────────────────────────────────────────────
# Backup + profile helpers
# ─────────────────────────────────────────────────────────────────────────────

# Backs up system configuration files typically modified by USG.
# Saves the backup to $BACKUP_DIR and exports BACKUP_FILE.
create_backup() {
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="$BACKUP_DIR/pre-hardening-${timestamp}.tar.gz"

    mkdir -p "$BACKUP_DIR"
    log info "Backing up system configuration..."

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
        || log warning "Some files could not be included in the backup."

    export BACKUP_FILE="$backup_file"
    log success "Backup saved: $backup_file"
}

# Displays the profile menu if $PROFILE is not already set by collect_answers().
# Exports PROFILE (short name) and USG_PROFILE (usg profile name).
select_profile() {
    if [[ -n "${PROFILE:-}" && -n "${USG_PROFILE:-}" ]]; then
        return 0
    fi

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
        q|Q) log info "Aborted by user."; exit 0 ;;
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
        log info "Tailoring file found: $tailoring_file"
        USG_ARGS=("--tailoring-file" "$tailoring_file")
    fi

    export USG_ARGS
}
