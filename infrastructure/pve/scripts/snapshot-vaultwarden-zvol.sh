#!/usr/bin/env bash
set -Eeuo pipefail

# Snapshots ZFS du zvol Vaultwarden. Ce n'est pas une sauvegarde.
# Usage : snapshot-vaultwarden-zvol.sh hourly|daily

DATASET="tank/vmdata/vm-101-vaultwarden-data"
LOCK_FILE="/run/lock/snapshot-vaultwarden-zvol.lock"
KIND="${1:-}"

log() {
    echo "[$(date '+%F %T')] $*"
}

exec 9>"$LOCK_FILE"
flock -n 9 || {
    log "Un snapshot est déjà en cours."
    exit 1
}

case "$KIND" in
    hourly)
        PREFIX="auto-hourly"
        KEEP=24
        STAMP="$(date '+%F_%H%M')"
        ;;
    daily)
        PREFIX="auto-daily"
        KEEP=7
        STAMP="$(date '+%F')"
        ;;
    *)
        log "ERREUR : argument hourly ou daily requis."
        exit 1
        ;;
esac

zfs list -H -o name "$DATASET" >/dev/null

SNAP_NAME="${DATASET}@${PREFIX}-${STAMP}"

if zfs list -H -o name -t snapshot "$SNAP_NAME" >/dev/null 2>&1; then
    log "Déjà présent : $SNAP_NAME"
else
    zfs snapshot "$SNAP_NAME"
    log "Créé : $SNAP_NAME"
fi

mapfile -t SNAPS < <(
    zfs list -H -o name -S creation -t snapshot "$DATASET" |
        grep -E "^${DATASET}@${PREFIX}-" || true
)

if (( ${#SNAPS[@]} > KEEP )); then
    for ((i = KEEP; i < ${#SNAPS[@]}; i++)); do
        log "Suppression : ${SNAPS[$i]}"
        zfs destroy "${SNAPS[$i]}"
    done
fi

REMAINING="$(
    zfs list -H -o name -t snapshot "$DATASET" |
        grep -cE "^${DATASET}@${PREFIX}-" || true
)"
log "Rétention ${PREFIX} : ${REMAINING} conservé(s), plafond ${KEEP}."
