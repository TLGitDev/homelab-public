#!/usr/bin/env bash
set -Eeuo pipefail

# Configuration
SSH_KEY="/root/.ssh/id_ed25519_backup_k3s"
SSH_USER="utilisateur"
SSH_HOST="<ip-k3s-01>"
SOURCE_DIR="/home/utilisateur/backups/vaultwarden/daily"
DEST_DIR="/tank/backups/k3s-01/vaultwarden"
LOCK_FILE="/run/lock/pull-vaultwarden-backup.lock"

log() {
    echo "[$(date '+%F %T')] $*"
}

# Empêcher deux transferts simultanés.
exec 9>"$LOCK_FILE"
flock -n 9 || {
    log "Un transfert est déjà en cours."
    exit 1
}

# Vérifier les prérequis.
[[ -r "$SSH_KEY" ]] || {
    log "ERREUR : clé SSH introuvable ou illisible."
    exit 1
}
[[ -d "$DEST_DIR" ]] || {
    log "ERREUR : répertoire de destination introuvable."
    exit 1
}

SSH_OPTS=(
    -i "$SSH_KEY"
    -o IdentitiesOnly=yes
    -o PasswordAuthentication=no
    -o BatchMode=yes
    -o ConnectTimeout=15
)

# Lister les archives source, de la plus récente à la plus ancienne.
SOURCE_LIST="$(
    ssh "${SSH_OPTS[@]}" "$SSH_USER@$SSH_HOST" \
        "find '$SOURCE_DIR' -maxdepth 1 -type f \
         -name 'vaultwarden-*.tar' -printf '%T@ %f\n' |
         sort -nr | cut -d' ' -f2-"
)"

[[ -n "$SOURCE_LIST" ]] || {
    log "ERREUR : aucune archive source trouvée."
    exit 1
}

# Traiter chaque archive source.
while IFS= read -r BASENAME; do
    [[ -n "$BASENAME" ]] || continue

    # Sécurité : n'accepter que des noms d'archives attendus.
    [[ "$BASENAME" =~ ^vaultwarden-[A-Za-z0-9_-]+\.tar$ ]] || {
        log "ERREUR : nom d'archive inattendu : $BASENAME"
        exit 1
    }

    SOURCE_FILE="$SOURCE_DIR/$BASENAME"
    FINAL_FILE="$DEST_DIR/$BASENAME"
    TMP_FILE="$DEST_DIR/.$BASENAME.part"

    # Calculer l'empreinte de la source.
    SOURCE_HASH="$(
        ssh -n "${SSH_OPTS[@]}" "$SSH_USER@$SSH_HOST" \
            "sha256sum '$SOURCE_FILE' | cut -d' ' -f1"
    )"

    # Si la destination existe, vérifier qu'elle est identique.
    if [[ -f "$FINAL_FILE" ]]; then
        DEST_HASH="$(sha256sum "$FINAL_FILE" | cut -d' ' -f1)"

        if [[ "$SOURCE_HASH" == "$DEST_HASH" ]]; then
            log "Déjà présente et identique : $BASENAME"
            continue
        fi

        log "ERREUR : archive existante avec une empreinte différente : $BASENAME"
        exit 1
    fi

    # Nettoyer une copie temporaire précédente.
    rm -f -- "$TMP_FILE"

    log "Transfert de $BASENAME..."
    scp "${SSH_OPTS[@]}" \
        "$SSH_USER@$SSH_HOST:$SOURCE_FILE" \
        "$TMP_FILE"

    # Vérifier l'intégrité du transfert.
    DEST_HASH="$(sha256sum "$TMP_FILE" | cut -d' ' -f1)"

    if [[ "$SOURCE_HASH" != "$DEST_HASH" ]]; then
        log "ERREUR : empreintes SHA-256 différentes pour $BASENAME"
        rm -f -- "$TMP_FILE"
        exit 1
    fi

    # Vérifier que l'archive peut être lue avant publication.
    if ! tar -tf "$TMP_FILE" >/dev/null; then
        log "ERREUR : archive tar invalide : $BASENAME"
        rm -f -- "$TMP_FILE"
        exit 1
    fi

    chmod 600 "$TMP_FILE"
    mv -- "$TMP_FILE" "$FINAL_FILE"

    log "Archive transférée et validée : $FINAL_FILE"
done <<< "$SOURCE_LIST"

# Conserver les 7 archives les plus récentes côté destination.
mapfile -t ARCHIVES < <(
    find "$DEST_DIR" -maxdepth 1 -type f \
        -name 'vaultwarden-*.tar' \
        -printf '%T@ %p\n' |
    sort -nr |
    cut -d' ' -f2-
)

if (( ${#ARCHIVES[@]} > 7 )); then
    for ((i=7; i<${#ARCHIVES[@]}; i++)); do
        log "Suppression d'une ancienne archive : ${ARCHIVES[$i]}"
        rm -- "${ARCHIVES[$i]}"
    done
fi

log "Transfert terminé avec succès."
