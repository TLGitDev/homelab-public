#!/usr/bin/env bash
# Contrôle quotidien. ADR-009 : copie USB de plus de 14 jours, tank, scrub, 10 % libres.
# Envoie lui-même le texte. Pas de OnFailure : un échec ne doit pas doubler le message.
set -euo pipefail

usb_max_age=$((14 * 24 * 3600))
min_free=10
stamp=/var/lib/homelab/backup-usb-last-success

problems=()

if [[ ! -s "$stamp" ]]; then
    problems+=("copie USB : aucune date de succès")
else
    if last=$(date -d "$(head -n 1 "$stamp")" +%s); then
        now=$(date +%s)
        age=$((now - last))
        if ((age > usb_max_age)); then
            days=$((age / 86400))
            problems+=("copie USB : ${days} j, seuil 14")
        fi
    else
        problems+=("copie USB : date illisible")
    fi
fi

health=$(zpool get -H -o value health tank) || health="inconnu"
if [[ "$health" != "ONLINE" ]]; then
    problems+=("tank : ${health}")
fi

if status=$(zpool status tank); then
    scan=$(printf '%s\n' "$status" | sed -n 's/^[[:space:]]*scan: //p' | head -n 1)
    known=$(printf '%s\n' "$status" | sed -n 's/^errors: //p' | head -n 1)
    case "$scan" in
        "none requested" | *"in progress"* | *"with 0 errors"*) ;;
        "") problems+=("tank : ligne scan absente") ;;
        *) problems+=("tank : ${scan}") ;;
    esac
    if [[ "$known" != "No known data errors" ]]; then
        problems+=("tank : ${known:-erreurs non lues}")
    fi
else
    problems+=("tank : zpool status a échoué")
fi

for pool in tank rpool; do
    if ! used=$(zpool list -H -o capacity "$pool"); then
        problems+=("${pool} : capacité illisible")
        continue
    fi
    used=${used%\%}
    case "$used" in
        '' | *[!0-9]*)
            problems+=("${pool} : capacité illisible")
            continue
            ;;
    esac
    free=$((100 - used))
    if ((free < min_free)); then
        problems+=("${pool} : ${free} % libres, seuil ${min_free}")
    fi
done

if ((${#problems[@]} == 0)); then
    exit 0
fi

text=$(printf '%s\n' "${problems[@]}")
/usr/local/sbin/notify-ntfy "$text"
exit 1
