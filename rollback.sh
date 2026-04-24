#!/usr/bin/env bash
# Restore the most recent pre-hardening backup and remove files USG added.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

init_logging "Rollback"

require_root

# Find most recent backup
latest=$(ls -t "$BACKUP_DIR"/pre-hardening-*.tar.gz 2>/dev/null | head -1)
if [[ -z "$latest" ]]; then
    die "No backup found in $BACKUP_DIR. Nothing to restore."
fi
filelist="${latest%.tar.gz}.files.txt"

echo
log warning "This will restore system configuration from the following backup:"
log warning "  $latest"
log warning "Modified configuration files will be overwritten."
if [[ -f "$filelist" ]]; then
    log warning "Files created after the backup will be deleted from the backed-up trees."
else
    log warning "No file-list snapshot found ($filelist missing) —"
    log warning "only files present in the tarball will be restored; new files USG added will remain."
fi
echo

read -rp "Are you sure? [y/N]: " confirm
[[ "$confirm" =~ ^[yY]$ ]] || { log info "Aborted. No changes made."; exit 0; }

REBOOT_CHOICE="no"
read -rp "Restart the system automatically when rollback finishes? [y/N] " answer
if [[ "${answer,,}" =~ ^y(es)?$ ]]; then
    REBOOT_CHOICE="yes"
fi
echo

log info "Restoring from: $latest"

# Don't silence tar — if something fails the user needs to know which file.
tar -xzf "$latest" -C / \
    || log warning "tar reported errors while restoring — see output above."

# Delete files USG added under the backed-up roots. tar -xzf only overwrites
# files that were in the tarball; it cannot remove drop-ins that USG wrote
# afterwards (e.g. /etc/modprobe.d/*-cis.conf, /etc/sysctl.d/*-cis.conf,
# /etc/audit/rules.d/*-cis.rules). That's what the filelist snapshot is for.
if [[ -f "$filelist" ]]; then
    log info "Removing files added after backup..."
    removed=0
    failed=0

    # Limit the scan to the top-level directories recorded in the snapshot,
    # so we don't walk the whole filesystem.
    mapfile -t roots < <(awk -F/ 'NF>1 {print "/"$2}' "$filelist" | sort -u)

    if (( ${#roots[@]} > 0 )); then
        while IFS= read -r -d '' current; do
            if ! grep -Fxq -- "$current" "$filelist"; then
                if rm -f -- "$current"; then
                    removed=$((removed + 1))
                else
                    log warning "Could not remove: $current"
                    failed=$((failed + 1))
                fi
            fi
        done < <(find "${roots[@]}" -xdev -type f -print0 2>/dev/null)
    fi

    log info "Removed $removed new file(s); $failed failure(s)."
fi

log success "Rollback complete."
log warning "Note: package installs/removals and systemd enable/mask state are NOT reverted."
log warning "Run 'sudo ./audit.sh' afterwards to check for remaining drift."

if [[ "$REBOOT_CHOICE" == "yes" ]]; then
    log notice "Auto-reboot requested — rebooting now..."
    reboot
else
    log info "Restart the system when ready: sudo reboot"
fi
