#!/usr/bin/env bash
set -Eeuo pipefail

# Configuration
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
NAMESPACE="vaultwarden"
DEPLOYMENT="vaultwarden"
DATA_DIR="/var/lib/k3s-storage/vaultwarden"
BACKUP_DIR="/home/utilisateur/backups/vaultwarden/daily"
LOCK_FILE="/run/lock/backup-vaultwarden.lock"

STOPPED=0
TMP_ARCHIVE=""
ORIGINAL_REPLICAS=""

log() {
    echo "[$(date '+%F %T')] $*"
}

restart_vaultwarden() {
    log "Redémarrage de Vaultwarden..."

    if ! kubectl -n "$NAMESPACE" scale \
        "deployment/$DEPLOYMENT" \
        --replicas="$ORIGINAL_REPLICAS"; then
        log "ERREUR : impossible de rétablir le nombre de répliques."
        return 1
    fi

    if ! kubectl -n "$NAMESPACE" rollout status \
        "deployment/$DEPLOYMENT" --timeout=180s; then
        log "ERREUR : Vaultwarden n'est pas redevenu disponible."
        return 1
    fi

    STOPPED=0
    log "Vaultwarden est de nouveau disponible."
}

cleanup() {
    local rc=$?

    # Supprimer une éventuelle archive temporaire incomplète.
    if [[ -n "$TMP_ARCHIVE" && -f "$TMP_ARCHIVE" ]]; then
        rm -f -- "$TMP_ARCHIVE"
    fi

    # Toujours tenter de redémarrer Vaultwarden après son arrêt.
    if [[ "$STOPPED" -eq 1 ]]; then
        if ! restart_vaultwarden; then
            log "ERREUR : impossible de confirmer le redémarrage de Vaultwarden."
            rc=1
        fi
    fi

    exit "$rc"
}
trap cleanup EXIT

# Empêcher deux sauvegardes simultanées.
exec 9>"$LOCK_FILE"
flock -n 9 || {
    log "Une autre sauvegarde est déjà en cours."
    exit 1
}

# Vérifier les prérequis.
[[ -d "$DATA_DIR" ]] || {
    log "ERREUR : répertoire de données introuvable."
    exit 1
}

[[ -d "$BACKUP_DIR" ]] || {
    log "ERREUR : répertoire de sauvegarde introuvable."
    exit 1
}

kubectl -n "$NAMESPACE" get "deployment/$DEPLOYMENT" >/dev/null

ORIGINAL_REPLICAS="$(
    kubectl -n "$NAMESPACE" get "deployment/$DEPLOYMENT" \
        -o jsonpath='{.spec.replicas}'
)"

if [[ ! "$ORIGINAL_REPLICAS" =~ ^[1-9][0-9]*$ ]]; then
    log "ERREUR : nombre de répliques initial invalide ou nul."
    exit 1
fi

# Arrêter Vaultwarden et attendre la disparition des Pods.
log "Arrêt de Vaultwarden..."
STOPPED=1
kubectl -n "$NAMESPACE" scale \
    "deployment/$DEPLOYMENT" --replicas=0

for ((i=0; i<120; i++)); do
    PODS="$(kubectl -n "$NAMESPACE" get pods -o name)"
    if [[ -z "$PODS" ]]; then
        break
    fi
    sleep 1
done

if [[ -n "${PODS:-}" ]]; then
    log "ERREUR : des Pods sont encore présents après 120 secondes."
    exit 1
fi

# Créer une archive temporaire, puis la valider.
STAMP="$(date '+%F_%H%M%S')"
TMP_ARCHIVE="$BACKUP_DIR/.vaultwarden-${STAMP}.tar.tmp"
FINAL_ARCHIVE="$BACKUP_DIR/vaultwarden-${STAMP}.tar"

log "Création de l'archive..."
tar --exclude='./lost+found' \
    -cpf "$TMP_ARCHIVE" \
    -C "$DATA_DIR" .

tar -tf "$TMP_ARCHIVE" >/dev/null

for required in './db.sqlite3' './rsa_key.pem'; do
    if ! tar -tf "$TMP_ARCHIVE" | grep -Fx "$required" >/dev/null; then
        log "ERREUR : fichier essentiel absent de l'archive : $required"
        exit 1
    fi
done

chmod 600 "$TMP_ARCHIVE"
chown utilisateur:utilisateur "$TMP_ARCHIVE"
mv -- "$TMP_ARCHIVE" "$FINAL_ARCHIVE"
TMP_ARCHIVE=""

log "Archive validée : $FINAL_ARCHIVE"

# Redémarrer et vérifier Vaultwarden avant toute rétention.
restart_vaultwarden

# Conserver les 7 archives les plus récentes.
mapfile -t ARCHIVES < <(
    find "$BACKUP_DIR" -maxdepth 1 -type f \
        -name 'vaultwarden-*.tar' \
        -printf '%T@ %p\n' |
    sort -nr |
    cut -d' ' -f2-
)

if (( ${#ARCHIVES[@]} > 7 )); then
    for ((i=7; i<${#ARCHIVES[@]}; i++)); do
        log "Suppression de l'ancienne archive : ${ARCHIVES[$i]}"
        rm -- "${ARCHIVES[$i]}"
    done
fi

log "Sauvegarde terminée avec succès."
