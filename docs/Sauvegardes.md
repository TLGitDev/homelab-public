# Sauvegardes

> RAID, snapshots et sauvegardes : trois protections différentes.
>
> Principes d'architecture : [Architecture.md](Architecture.md). Stockage ZFS : [Stockage.md](Stockage.md). Vaultwarden sur `tank` : [ADR-008](ADR/ADR-008-Vaultwarden-tank.md). Phase 0 : [FeuilleDeRoute.md](FeuilleDeRoute.md). Coffre : [Vaultwarden.md](Vaultwarden.md#sauvegarde).

---

# Définition

Une sauvegarde est une copie **indépendante** permettant de restaurer le système après une perte ou une corruption.

Elle ne doit pas être confondue avec le RAID ou les snapshots.

---

# Objectifs

Adaptés à un usage personnel, pour garder l'infrastructure simple :

| Indicateur | Objectif |
|------------|----------|
| RTO (Recovery Time Objective) | 1 journée maximum |
| RPO (Recovery Point Objective) | 24 heures maximum |

RTO : durée maximale pour remettre le service en état.

RPO : quantité maximale de données que l'on accepte de perdre.

---

# Trois protections distinctes

## RAID / miroir ZFS

Protège contre la panne d'un disque.

Ne protège pas contre :

- une suppression accidentelle ;
- un ransomware ;
- une corruption logique ;
- une erreur humaine.

Toute modification est immédiatement répliquée sur les deux disques.

Le RAID améliore la **disponibilité**, pas la sauvegarde.

Aujourd'hui : `rpool` n'a pas de miroir (un seul NVMe). `tank` est un miroir de deux HDD. Le miroir de `tank` n'est pas une sauvegarde.

## Snapshots

Permettent de revenir rapidement à un état précédent.

Adaptés pour : tester une mise à jour, modifier une configuration importante, revenir en arrière après une erreur.

Ils sont stockés sur le **même** pool ZFS. Ils ne protègent pas contre une perte totale du stockage.

Cible v1 (pas encore activée) : [ci-dessous](#snapshots-zfs--cible).

## Sauvegardes

Stockées sur un support indépendant.

Elles permettent de reconstruire complètement une machine après une panne matérielle.

C'est le dernier niveau de protection.

---

# Stratégie retenue

```
Couche 1    ZFS (checksums ; miroir IronWolf sur `tank`)
                ↓
            Protège contre la corruption silencieuse
            et contre la panne d'un HDD de données.

Couche 2    Snapshots ZFS
                ↓
            Protègent contre les erreurs récentes.

Couche 3    Sauvegardes Proxmox
                ↓
            Disque USB externe dédié
                ↓
            Restauration complète du serveur.

Couche 4    Sauvegarde hors site (future)
                ↓
            Copie chiffrée sur un support dans un autre lieu.
```

---

# Chaîne actuelle

```
03:00  k3s-01   tar Vaultwarden (service arrêté)     → rpool
03:15  pve      pull SSH + SHA-256 + tar -tf         → /tank/backups/…
manuel pve      backup-usb (Restic de /tank/backups) → USB
```

| Niveau | Où | Surviture à… | Ne survit pas à… |
|--------|-----|----------------|------------------|
| 1 | Archives sur `k3s-01` (`rpool`) | — | perte de la VM / du NVMe |
| 2 | `/tank/backups` sur `pve` | reconstruction de `k3s-01` | perte de `tank` ou du serveur |
| 3 | USB (Restic) | perte du serveur / de `tank` | oubli de brancher le disque |

Le niveau 2 est sur **le même pool** que le zvol Vaultwarden. Ce n'est pas une copie hors `tank`.

Git (`infrastructure/`) = sources versionnées. Actif = `/usr/local/sbin/` et `/etc/systemd/system/`. Un commit ne déploie pas tout seul.

Timers : tars auto **20 et 21 oct.** sur k3s-01 et `pve`. Restore isolée OK (technique + login 21 oct.). Reprise réelle : [écrite](Vaultwarden.md#reprise-réelle--non-testée), non exécutée. USB : manuel, pas de timer.

Détail coffre : [Vaultwarden.md](Vaultwarden.md#sauvegarde). Scripts `pve` : [Proxmox.md](Proxmox.md#exploitation).

Copies ponctuelles encore là : migration `…/migration-2026-10-14/` ; clé Sealed Secrets `~/backups/sealed-secrets/` (mode `600`, **pas** dans Git). Cette clé n'est **pas** encore sur l'USB.

---

# Snapshots ZFS — cible

**Statut : scripts versionnés le 21 octobre 2026. Pas encore installés / activés sur `pve`.** Ce n'est pas de l'as-built tant que les timers ne tournent pas.

Un snapshot ZFS n'est **pas** une sauvegarde. Perte de `tank` = perte des snapshots **et** du zvol live.

## Périmètre v1

| Dataset / volume | Snapshot auto v1 | Pourquoi |
|---|---|---|
| `tank/vmdata/vm-101-vaultwarden-data` | **oui** | seul volume live dont un rollback en minutes évite de rejouer le tar |
| `tank/backups` | non | déjà 7 tars ; même pool |
| `rpool` (disques VM / LXC) | non | infra reconstructible ; meurt avec le NVMe |

Pas de Sanoid pour v1. Script + timers systemd sur `pve` :

| Rôle | Installé | Git |
|------|----------|-----|
| Script | `/usr/local/sbin/snapshot-vaultwarden-zvol.sh` | [`infrastructure/pve/scripts/snapshot-vaultwarden-zvol.sh`](../infrastructure/pve/scripts/snapshot-vaultwarden-zvol.sh) |
| Horaire | `OnCalendar=hourly` | [`systemd/snapshot-vaultwarden-zvol-hourly.*`](../infrastructure/pve/systemd/) |
| Quotidien | `04:00` | [`systemd/snapshot-vaultwarden-zvol-daily.*`](../infrastructure/pve/systemd/) |

Git ≠ `pve`. Copier, `700`, `bash -n`, run manuel, **puis** activer les timers.

## Rétention

| Fréquence | Garder | Nom visé |
|---|---|---|
| horaire | 24 | `…@auto-hourly-AAAA-MM-JJ_HHMM` |
| quotidienne | 7 | `…@auto-daily-AAAA-MM-JJ` |

Court volontairement : ça sert le *oops* récent, pas l'archive.

## Cohérence

Les snapshots se font **VM allumée**, Vaultwarden qui tourne : cohérents crash (SQLite + WAL, en général récupérable). La copie **applicative** reste le tar 03:00 (service arrêté). On n'arrête **pas** Vaultwarden toutes les heures.

Un `zfs rollback` sur un zvol attaché exige en pratique Vaultwarden **et** souvent la VM arrêtés, ou le disque détaché. Il **détruit** les snapshots plus récents que la cible. Ce n'est pas un exercice à faire sur le zvol de prod « pour voir ».

Contrôle sans rollback : `zfs list -t snapshot tank/vmdata/vm-101-vaultwarden-data`. Ne détruire que les snaps `auto-hourly-` / `auto-daily-` (le script ne touche pas aux snaps manuels).

### Mise en place (sur `pve`, root)

Dépôt Git sur k3s-01 : `/homelab/`. Copie vers `pve` en SSH (clé de backup). Faire un `git pull` dans `/homelab` sur k3s-01 si les fichiers n'y sont pas encore.

```bash
install -d -m 700 /tmp/snapshot-vaultwarden-zvol
scp -i /root/.ssh/id_ed25519_backup_k3s \
  utilisateur@<ip-k3s-01>:/homelab/infrastructure/pve/scripts/snapshot-vaultwarden-zvol.sh \
  utilisateur@<ip-k3s-01>:/homelab/infrastructure/pve/systemd/snapshot-vaultwarden-zvol-hourly.service \
  utilisateur@<ip-k3s-01>:/homelab/infrastructure/pve/systemd/snapshot-vaultwarden-zvol-hourly.timer \
  utilisateur@<ip-k3s-01>:/homelab/infrastructure/pve/systemd/snapshot-vaultwarden-zvol-daily.service \
  utilisateur@<ip-k3s-01>:/homelab/infrastructure/pve/systemd/snapshot-vaultwarden-zvol-daily.timer \
  /tmp/snapshot-vaultwarden-zvol/

install -m 700 /tmp/snapshot-vaultwarden-zvol/snapshot-vaultwarden-zvol.sh \
  /usr/local/sbin/snapshot-vaultwarden-zvol.sh
cp /tmp/snapshot-vaultwarden-zvol/snapshot-vaultwarden-zvol-hourly.service \
   /tmp/snapshot-vaultwarden-zvol/snapshot-vaultwarden-zvol-hourly.timer \
   /tmp/snapshot-vaultwarden-zvol/snapshot-vaultwarden-zvol-daily.service \
   /tmp/snapshot-vaultwarden-zvol/snapshot-vaultwarden-zvol-daily.timer \
   /etc/systemd/system/
bash -n /usr/local/sbin/snapshot-vaultwarden-zvol.sh
systemd-analyze verify \
  /etc/systemd/system/snapshot-vaultwarden-zvol-hourly.service \
  /etc/systemd/system/snapshot-vaultwarden-zvol-hourly.timer \
  /etc/systemd/system/snapshot-vaultwarden-zvol-daily.service \
  /etc/systemd/system/snapshot-vaultwarden-zvol-daily.timer
systemctl daemon-reload
/usr/local/sbin/snapshot-vaultwarden-zvol.sh hourly
/usr/local/sbin/snapshot-vaultwarden-zvol.sh daily
zfs list -t snapshot tank/vmdata/vm-101-vaultwarden-data
```

Si les deux snaps `auto-*` sont là, **alors** :

```bash
systemctl enable --now snapshot-vaultwarden-zvol-hourly.timer
systemctl enable --now snapshot-vaultwarden-zvol-daily.timer
systemctl list-timers 'snapshot-vaultwarden-zvol-*'
```

Ne pas `zfs rollback` le zvol de prod pour tester.

## Hors v1

- `tank/backups`, `rpool`
- réplication `zfs send` vers un autre pool
- snapshots Kubernetes / CSI

Détail zvol : [Stockage.md](Stockage.md). Coffre : [Vaultwarden.md](Vaultwarden.md#sauvegarde).

---

# USB / Restic

Script installé : `/usr/local/sbin/backup-usb`. Git : [`infrastructure/pve/scripts/backup-usb`](../infrastructure/pve/scripts/backup-usb).

- Source : `/tank/backups` (pas les zvol de production).
- Dépôt : `/mnt/usb-inspect/restic-homelab`.
- Disque : UUID `340F-3DAF` (`findfs`). Montage `/mnt/usb-inspect`. Vérifier `findmnt` si le chemin change.
- **Manuel**, terminal interactif. Mot de passe saisi au clavier. Jamais dans Git, cette doc ou les logs. Pas de timer systemd.

## Comportement

1. Root, `flock`, source présente.
2. Manifeste des fichiers (`find -print0`) pour les noms ambigus.
3. Si déjà monté : vérifier que c'est bien cet UUID. Sinon monter. Si le disque est monté ailleurs : erreur.
4. `restic check`, puis snapshot de `/tank/backups`.
5. Comparer le snapshot au manifeste : fichiers manquants ou inattendus = échec.
6. `restic check` à nouveau, `sync`.
7. Démonter **seulement** si le script a monté. Déjà monté au départ → reste monté.
8. Temp (`/tmp/backup-usb.*`) toujours nettoyé. En cas d'échec, le disque reste monté pour diagnostiquer.

## Tests (mise au point)

- USB déjà monté ; montage + démontage auto.
- `check` avant / après.
- Manifeste vs snapshot.
- Restauration d'**une archive** depuis un snapshot ; SHA-256 identique à l'original. Ce n'est **pas** une restauration du service. Restore technique du coffre (autre procédure, 2026-10-20) : [Vaultwarden.md](Vaultwarden.md#test-du-20-octobre-2026-technique).
- Détection d'un fichier source manquant dans le snapshot.
- Nettoyage des temporaires après erreur simulée.

## Limites

- Ne copie pas le zvol vivant, seulement `/tank/backups`.
- Mot de passe requis à chaque run.
- Disque doit être branché.
- Rétention des snapshots Restic : **pas encore** définie.
- Après une erreur : regarder le montage avant de relancer.

Avant de débrancher : plus d'opération Restic, démonter, vérifier que ce n'est plus monté.

---

# Principes

## Indépendance

Une sauvegarde doit être stockée sur un support distinct de celui qui contient les données d'origine.

## Versionnement

Plusieurs générations doivent être conservées, pour revenir en arrière si une corruption ou une erreur est découverte tardivement.

## Automatisation

Une sauvegarde automatique imparfaite est préférable à une sauvegarde manuelle parfaite qui n'est jamais exécutée.

## Validation

Une sauvegarde n'existe réellement que lorsqu'une restauration a été réalisée avec succès. Créer une copie n'est pas suffisant. Il faut vérifier régulièrement qu'elle restaure vraiment les données.
