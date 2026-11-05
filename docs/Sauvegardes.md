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

v1 activée le 21 oct. (timers) : [ci-dessous](#snapshots-zfs).

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
manuel pve      backup-usb (Restic : backups + dossiers perso live) → USB
```

| Niveau | Où | Surviture à… | Ne survit pas à… |
|--------|-----|----------------|------------------|
| 1 | Archives sur `k3s-01` (`rpool`) | — | perte de la VM / du NVMe |
| 2 | `/tank/backups` sur `pve` | reconstruction de `k3s-01` | perte de `tank` ou du serveur |
| 3 | USB (Restic) | perte du serveur / de `tank` | oubli de brancher le disque |

Le niveau 2 est sur **le même pool** que le zvol Vaultwarden. Ce n'est pas une copie hors `tank`.

Git (`infrastructure/`) = sources versionnées. Actif = `/usr/local/sbin/` et `/etc/systemd/system/`. Un commit ne déploie pas tout seul.

Timers : tars auto **20 et 21 oct.** sur k3s-01 et `pve`. Restore isolée OK (technique + login 21 oct.). Reprise réelle : [écrite](Vaultwarden.md#reprise-réelle--non-testée), non exécutée. USB : manuel. Run **20 oct.** : `/tank/backups` seulement. Script élargi installé sur `pve` ; premier run des dossiers live **24 oct.** snapshot `<snapshot>` (362983 fichiers, ~105,5 Gio lus, ~80,7 Gio stockés). `no parent snapshot` = premier ingest de ces chemins, attendu. Un run USB ne contient que les chemins du script **ce jour-là**.

Détail coffre : [Vaultwarden.md](Vaultwarden.md#sauvegarde). Scripts `pve` : [Proxmox.md](Proxmox.md#exploitation).

**Deux objets distincts :**

| Objet | Où | Dans Restic via `backup-usb` ? |
|---|---|---|
| Tars Vaultwarden | `/tank/backups/k3s-01/vaultwarden/` | oui, s'ils y étaient au moment du run |
| SealedSecret (`sealed-secret.yaml`) | Git | le ciphertext, pas la clé du controller |
| Clé TLS du controller Sealed Secrets | k3s-01 `~/backups/sealed-secrets/` **et** copie manuelle `/tank/backups/k3s-01/sealed-secrets/` | oui (dans le périmètre `/tank/backups`) |
| Dossiers perso (live) | `/tank/documents`, `images`, `musique`, `projets`, `videos` | oui (run 24 oct., snapshot `<snapshot>`) |
| Configs médiathèques | `/tank/backups/mediatheques/` | oui, snapshot `<snapshot>` (2 nov. 13:58). Pas dans le run du 25 oct. |

Sans cette clé, un cluster neuf ne déchiffre pas les SealedSecrets existants (`ADMIN_TOKEN` hash). Le coffre utilisateur est dans le tar, pas dans cette clé.

Copie vers `pve` : **manuelle** (pas le script de pull des tars). Hors k3s-01 : oui. Encore sur `tank` jusqu'à l'USB. `backup-usb` du 20 oct. inclut ce répertoire s'il y était déjà.

## Configs médiathèques (2 nov.)

Les médias restent hors sauvegarde. Les configs des CT 103, 104, 105 et 106 sont copiées, service arrêté le temps de l'archive, puis relancé. Recyclarr n'a pas de service. Le tunnel WireGuard du CT 104 n'a pas été coupé : ses fichiers ont seulement été lus.

Répertoire `/tank/backups/mediatheques`, mode `700`. Chaque archive mode `600`. Rien dans Git.

| Archive | Taille | Contenu |
|---------|--------|---------|
| `jellyfin-2026-11-02.tar` | 3,3 Gio | `/var/lib/jellyfin` |
| `lidarr-2026-11-02.tar` | 254 Mio | `/var/lib/lidarr` |
| `sonarr-2026-11-02.tar` | 193 Mio | `/var/lib/sonarr` |
| `bazarr-2026-11-02.tar` | 156 Mio | `/opt/bazarr/data` et `/var/lib/bazarr` |
| `radarr-2026-11-02.tar` | 153 Mio | `/var/lib/radarr` |
| `navidrome-2026-11-02.tar` | 125 Mio | `/var/lib/navidrome`, `/etc/navidrome/navidrome.toml` |
| `recyclarr-2026-11-02.tar` | 73 Mio | `/var/lib/recyclarr`, y compris `secrets.yml` |
| `prowlarr-2026-11-02.tar` | 10 Mio | `/var/lib/prowlarr` |
| `qbittorrent-2026-11-02.tar` | 8,1 Mio | `/var/lib/qbittorrent`, `/etc/wireguard` (`wg0.conf` et `wg0.conf.mullvad`) |

La première archive Bazarr n'avait que `/var/lib/bazarr`. La base et `config.yaml` sont dans `/opt/bazarr/data`. L'archive a été refaite avec les deux chemins.

Restauration vers `/tmp`, services en place non remplacés, dossier de test effacé. `PRAGMA integrity_check` : `ok` pour Jellyfin, Prowlarr, Sonarr, Radarr, Lidarr, Bazarr, et Navidrome (50 tables). Les fichiers qBittorrent, WireGuard et Recyclarr se relisent, taille non nulle. Leur contenu n'est pas dans ce fichier.

Ces archives sont sur `tank` et dans le snapshot USB `<snapshot>` (2 nov. 13:58). Parent `<snapshot>`. 10 fichiers nouveaux, 4,229 Gio ajoutés (3,790 Gio stockés). Manifeste OK (363422 fichiers). `check` OK (12 snapshots). Clé démontée.

---

# Snapshots ZFS

**2026-10-21** — timers actifs. Runs **timer** horaires OK : `@auto-hourly-2026-10-21_1200` et `_1300` (journal : créé, rétention 2 puis 3 / 24). Snap manuel d'install : `_1140` + `@auto-daily-2026-10-21`. Premier quotidien **timer** : 22 oct. 04:00 ⬜. Rétention 24/7 sur plusieurs jours ⬜.

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

Git ≠ `pve`. Clone k3s-01 : `/home/utilisateur/homelab` (pas `/homelab`). Copier, `700`, `bash -n`, run manuel, **puis** activer les timers.

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

Dépôt Git sur k3s-01 : `/home/utilisateur/homelab/` (`~/homelab`). Copie vers `pve` en SSH (clé de backup). `git pull` dans ce répertoire sur k3s-01 si les fichiers n'y sont pas encore.

```bash
install -d -m 700 /tmp/snapshot-vaultwarden-zvol
scp -i /root/.ssh/id_ed25519_backup_k3s \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/scripts/snapshot-vaultwarden-zvol.sh \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/systemd/snapshot-vaultwarden-zvol-hourly.service \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/systemd/snapshot-vaultwarden-zvol-hourly.timer \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/systemd/snapshot-vaultwarden-zvol-daily.service \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/systemd/snapshot-vaultwarden-zvol-daily.timer \
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

**Activé le 21 oct.** Premier horaire timer : 12:00 (succès), puis 13:00. Quotidien timer : 22 oct. 04:00.

```
zfs list -t snapshot tank/vmdata/vm-101-vaultwarden-data
# …@auto-hourly-2026-10-21_1140   ← run manuel d'install
# …@auto-daily-2026-10-21         ← run manuel d'install
# …@auto-hourly-2026-10-21_1200   ← timer
# …@auto-hourly-2026-10-21_1300   ← timer
```

## Hors v1

- `tank/backups`, `rpool`
- réplication `zfs send` vers un autre pool
- snapshots Kubernetes / CSI

Détail zvol : [Stockage.md](Stockage.md). Coffre : [Vaultwarden.md](Vaultwarden.md#sauvegarde).

---

# USB / Restic

Script sur `pve` : `/usr/local/sbin/backup-usb`, `700`, copie Git du 5 nov. installée le 5 nov. `bash -n` muet. Git : [`infrastructure/pve/scripts/backup-usb`](../infrastructure/pve/scripts/backup-usb). Cette copie fait le `forget` et écrit la date de succès. Premier run avec ces deux étapes : 5 nov. 10:29–10:33, snapshot `<snapshot>`.

- Sources (script Git, 24 oct.) : `/tank/backups`, `/tank/documents`, `/tank/images`, `/tank/musique`, `/tank/projets`, `/tank/videos`. Pas le zvol, pas `Mediatheques`, pas `~/backups/sealed-secrets/` sur k3s-01, pas de `rsync` vers `/tank/backups/pc/`. (document privé).
- Dépôt : `/mnt/usb-inspect/restic-homelab`.
- Disque : UUID `340F-3DAF` (`findfs`). Montage `/mnt/usb-inspect`. Vérifier `findmnt` si le chemin change.
- **Manuel**, terminal interactif. Mot de passe saisi au clavier. Jamais dans Git, cette doc ou les logs. Pas de timer systemd.
- Installé sur `pve`. Premier run élargi **24 oct.** : snapshot `<snapshot>`, manifeste OK, `check` OK, clé démontée.
- Second run **24 oct. 16:08** : snapshot `<snapshot>`, parent `<snapshot>`. 363180 fichiers (197 nouveaux), 469,8 Mio ajoutés (358,6 Mio stockés), manifeste OK, `check` OK (9 snapshots). Avant ce run : verrou orphelin du PID 1382228 (créé 11:57, processus absent), retiré par `restic unlock`. La clé était déjà montée : elle est **restée** montée.
- Troisième run **25 oct. 13:26** : snapshot `<snapshot>`, parent `<snapshot>`. 363413 fichiers (234 nouveaux, 0 modifiés), 154 dossiers nouveaux, 200,3 Mio ajoutés (199,0 Mio stockés), 106,009 Gio lus en 1:21. Manifeste OK (363413 fichiers). `check` OK (10 snapshots, 13 index). Clé démontée. Avant le run : `find` voit le `.vcf`, le JSON SMS et le JSON Obtainium ; `ls` voit `files` et `signal-backup-2026-10-24-18-46-57`.
- Quatrième run **2 nov. 13:53–13:58** : snapshot `<snapshot>`, parent `<snapshot>`. 363422 fichiers (10 nouveaux, 0 modifiés), 1 dossier nouveau, 4,229 Gio ajoutés (3,790 Gio stockés), 110,247 Gio lus en 2:56. Manifeste OK (363422 fichiers). `check` avant : 11 snapshots, aucune erreur. `check` après : 12 snapshots, 15 index, aucune erreur. Clé démontée. Le dernier snapshot écrit ici était `<snapshot>` (25 oct.) : le parent `<snapshot>` n'y figure pas.
- Cinquième run **5 nov. 10:29–10:33** : snapshot `<snapshot>`, parent `<snapshot>`. 363445 fichiers (26 nouveaux, 0 modifiés), 2 dossiers nouveaux, 5 modifiés, 1,098 Gio ajoutés (1,090 Gio stockés), 111,876 Gio lus en 1:53. Manifeste OK (363445 fichiers). `check` avant : 12 snapshots, aucune erreur. `check` après : 13 snapshots, aucune erreur. Puis `forget --keep-within 14d --group-by host --prune` : 6 snapshots gardés (`<snapshot>`, `<snapshot>`, `<snapshot>`, `<snapshot>`, `<snapshot>`, `<snapshot>`). 7 retirés, dont `<snapshot>` et les copies du 19 et du 20 oct. `prune` : 14 blobs, 3,999 Kio. Il reste 317057 blobs, 86,166 Gio, 0 octet inutilisé. Date de succès réécrite (journal à 10:33:18, fichier non relu). Clé démontée.

## Comportement

La liste est celle du script installé sur `pve`. Les étapes 7 et 8 ont tourné le 5 nov., run `<snapshot>`.

1. Root, `flock`, **tous** les répertoires sources présents.
2. Manifeste des fichiers (`find` sur la liste, `-print0`) pour les noms ambigus.
3. Si déjà monté : vérifier que c'est bien cet UUID. Sinon monter. Si le disque est monté ailleurs : erreur.
4. `restic check`, puis **un** snapshot Restic des six chemins (incrémental après le premier run).
5. Comparer le snapshot au manifeste : fichiers manquants ou inattendus = échec.
6. `restic check` à nouveau.
7. `restic forget --keep-within 14d --group-by host --prune`. `--group-by host` : un changement de chemins ne fige pas un ancien groupe pour toujours.
8. Écrire `/var/lib/homelab/backup-usb-last-success` seulement après ce `forget`.
9. `sync`. Démonter **seulement** si le script a monté. Déjà monté au départ → reste monté.
10. Temp (`/tmp/backup-usb.*`) toujours nettoyé. En cas d'échec, le disque reste monté pour diagnostiquer.

### Mise à jour du script (sur `pve`, root)

Dépôt Git sur k3s-01 : `/home/utilisateur/homelab/` (`~/homelab`). `git pull` dans ce répertoire si le script n'y est pas encore.

```bash
scp -i /root/.ssh/id_ed25519_backup_k3s \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/scripts/backup-usb \
  /tmp/backup-usb
install -m 700 /tmp/backup-usb /usr/local/sbin/backup-usb
```

Clé USB branchée, assez de place pour le **premier** ingest des dossiers perso, puis :

```bash
/usr/local/sbin/backup-usb
```

## Tests (mise au point)

- USB déjà monté ; montage + démontage auto.
- `check` avant / après.
- Manifeste vs snapshot.
- Restauration d'**une archive** depuis un snapshot ; SHA-256 identique à l'original. Ce n'est **pas** une restauration du service. Restore technique du coffre (autre procédure, 2026-10-20) : [Vaultwarden.md](Vaultwarden.md#test-du-20-octobre-2026-technique).
- Restore d'**un fichier perso** (24 oct., snapshot `<snapshot>` → `/tmp`, SHA-256 = live). (document privé).
- Restore du `.vcf` téléphone (24 oct., `<snapshot>` → `/tmp`, SHA-256 = live, 52 fiches). (document privé).
- Détection d'un fichier source manquant dans le snapshot.
- Nettoyage des temporaires après erreur simulée.

## Clé Sealed Secrets et USB

`backup-usb` ne va pas chercher la clé sur k3s-01. Transfert **manuel** confirmé vers `/tank/backups/k3s-01/sealed-secrets/` (`600`, pas Git). Ce chemin est dans la source USB.

Hors VM : oui. Hors serveur : via `backup-usb` (chemins listés dans le script). Un `restic ls` du snapshot confirme le **chemin**, jamais le contenu. Relancer `backup-usb` si la copie `pve` est **plus récente** que le dernier snapshot USB.

## Limites

- Ne copie pas le zvol vivant.
- Ne copie pas tout seul la clé Sealed Secrets (elle doit déjà être sous `/tank/backups`).
- Mot de passe requis à chaque run.
- Disque doit être branché.
- Rétention des snapshots Restic : **14 jours**, appliquée le 5 nov. sur le run `<snapshot>`. La durée est relative au snapshot le plus récent. Le `--dry-run` du matin, alors que le plus récent était `<snapshot>` (2 nov.), n'aurait retiré que `<snapshot>`. Le run de 10:31 a déplacé la fenêtre : 7 snapshots sont sortis, 6 restent. Les fichiers encore présents dans ces 6 snapshots n'ont pas été effacés. `prune` n'a retiré que 3,999 Kio. [ADR-009](ADR/ADR-009-Alerte-ntfy.md).
- Après une erreur : regarder le montage avant de relancer. Un `repository is already locked` : `ps -p <PID>`. Processus absent → `restic unlock` sur ce dépôt, puis relancer. Processus encore là → ne pas unlock.

Avant de débrancher : plus d'opération Restic, démonter, vérifier que ce n'est plus monté.

---

# Alerte

Décision du 5 nov. : ntfy. [ADR-009](ADR/ADR-009-Alerte-ntfy.md). Jouée le même jour : sujet en place, `notify-ntfy` sur `pve` et `k3s-01`, messages d'essai reçus, units d'échec branchées, contrôle et scrub activés, rétention appliquée sur `<snapshot>`.

| Quoi | Où | Comment |
|------|----|---------|
| Timer d'archive Vaultwarden | `k3s-01`, 03:00 | `OnFailure` → `échec backup-vaultwarden` |
| Timers de snapshots zvol | `pve`, horaire et 04:00 | `OnFailure` → le nom de l'unit |
| Copie USB plus vieille que 14 jours | `pve`, 08:15 | Fichier de date, pas le dépôt (la clé est démontée) |
| `tank` autre que `ONLINE`, ou scrub en erreur | `pve`, 08:15 | `zpool get` et `zpool status` |
| Espace sous 10 % libres | `pve`, 08:15 | `tank` et `rpool` |
| Scrub de `tank` | `pve`, premier dimanche, 05:00 | `zpool scrub` rend la main tout de suite. L'état mauvais passe par le contrôle de 08:15 |

Un scrub en cours, ou `scan: none requested` avant le premier passage, ne prévient pas. `with 0 errors` ne prévient pas.

| Rôle | Git | Installé |
|------|-----|----------|
| Envoi | [`notify-ntfy`](../infrastructure/pve/scripts/notify-ntfy) | `/usr/local/sbin/notify-ntfy`, `700`, sur `pve` et `k3s-01` (5 nov.) |
| Sujet | `/etc/homelab/ntfy-topic` | `600`, root, sur `pve` et `k3s-01` (5 nov.). Pas dans Git |
| Contrôle | [`check-sauvegardes.sh`](../infrastructure/pve/scripts/check-sauvegardes.sh) | `/usr/local/sbin/check-sauvegardes.sh`, `700`. Lancé à la main le 5 nov. : code `0`, aucun message |
| Unit d'échec | [`notify-failure@.service`](../infrastructure/pve/systemd/notify-failure@.service) | installée le 5 nov. sur `pve` et `k3s-01`. `OnFailure` ajouté aux deux snapshots zvol et à `backup-vaultwarden.service`. `daemon-reload` fait |
| Timer 08:15 | [`check-sauvegardes.timer`](../infrastructure/pve/systemd/check-sauvegardes.timer) | activé le 5 nov. Prochain passage : ven. 6 nov. 08:15. Pas encore passé |
| Scrub | [`scrub-tank.timer`](../infrastructure/pve/systemd/scrub-tank.timer) | activé le 5 nov. Prochain passage : dim. 6 déc. 05:00. `scrub-tank.service` `inactive`. Dernier scrub réel : 11 oct. 00:24, `repaired 0B`, `with 0 errors`, durée 1 s. Le `LAST` du 5 nov. 10:25 est la date écrite pour empêcher un rattrapage, pas un scrub |

`OnFailure` est dans les units Git et, depuis le 5 nov., sur les machines. Sur le disque la ligne est juste après `[Unit]`, avant `Description`. systemd n'en tient pas compte. Essai du 5 nov. 10:14 : `alerte-essai.service` sort en erreur, `notify-failure@alerte-essai` finit `status=0`, le téléphone affiche `échec alerte-essai`. L'unit est retirée. `systemctl status alerte-essai.service` : unit introuvable. `reset-failed` sur `notify-failure@alerte-essai` a répondu `not loaded` : ce service avait réussi, il n'était pas en échec.

## Mise en place

Les blocs 1 à 6 sont joués (5 nov.). La date de succès a d'abord été `2026-11-02T13:55:23+01:00`, puis réécrite par le run `<snapshot>`. Clé démontée.

Une fois ces fichiers sur le clone `k3s-01` (`/home/utilisateur/homelab`). Ne pas coller le sujet dans Git ni dans le journal.

### 1. Téléphone et sujet

Appli ntfy (F-Droid ou Obtainium). Sujet long, aléatoire, pas un mot devinable. S'y abonner.

Sur `pve`, root. La ligne collée est l'URL complète, sans espace.

```bash
install -d -m 755 /etc/homelab
umask 077
cat > /etc/homelab/ntfy-topic
```

Coller `https://ntfy.sh/…`, Entrée, puis Ctrl-D.

```bash
chmod 600 /etc/homelab/ntfy-topic
```

Copie vers `k3s-01`, puis le fichier source chez `utilisateur` est retiré :

```bash
scp -i /root/.ssh/id_ed25519_backup_k3s \
  /etc/homelab/ntfy-topic \
  utilisateur@<ip-k3s-01>:/home/utilisateur/ntfy-topic
```

Sur `k3s-01` :

```bash
sudo install -d -m 755 /etc/homelab
sudo install -m 600 /home/utilisateur/ntfy-topic /etc/homelab/ntfy-topic
rm -f /home/utilisateur/ntfy-topic
```

### 2. Script d'envoi, puis un message

`command -v curl` doit afficher un chemin, sur `pve` et sur `k3s-01`. Sinon s'arrêter.

Sur `pve`, root :

```bash
scp -i /root/.ssh/id_ed25519_backup_k3s \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/scripts/notify-ntfy \
  /tmp/notify-ntfy
install -m 700 /tmp/notify-ntfy /usr/local/sbin/notify-ntfy
bash -n /usr/local/sbin/notify-ntfy
/usr/local/sbin/notify-ntfy "essai canal, pve"
```

Le téléphone affiche `essai canal, pve`. Sinon s'arrêter. Le journal de `curl` ne doit pas contenir le sujet : le script n'écrit que `Envoi ntfy impossible.` ou `ntfy HTTP …`.

Même binaire sur `k3s-01` :

```bash
sudo install -m 700 /home/utilisateur/homelab/infrastructure/pve/scripts/notify-ntfy /usr/local/sbin/notify-ntfy
sudo bash -n /usr/local/sbin/notify-ntfy
sudo /usr/local/sbin/notify-ntfy "essai canal, k3s-01"
```

Second message vu. Sinon s'arrêter : l'archive de 03:00 ne pourrait pas prévenir.

### 3. Units d'échec

Sur `pve` :

```bash
scp -i /root/.ssh/id_ed25519_backup_k3s \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/systemd/notify-failure@.service \
  /tmp/notify-failure@.service
install -m 644 /tmp/notify-failure@.service /etc/systemd/system/notify-failure@.service
```

Ajouter la ligne `OnFailure` aux deux units de snapshot déjà en place, comme dans Git. Ne pas remplacer l'unit si le reste a divergé : une ligne dans `[Unit]`.

```bash
grep -n OnFailure /etc/systemd/system/snapshot-vaultwarden-zvol-hourly.service \
  /etc/systemd/system/snapshot-vaultwarden-zvol-daily.service
systemctl daemon-reload
```

Sur `k3s-01`, la même unit, puis la ligne sur `backup-vaultwarden.service` :

```bash
sudo install -m 644 \
  /home/utilisateur/homelab/infrastructure/k3s-01/systemd/notify-failure@.service \
  /etc/systemd/system/notify-failure@.service
sudo grep -n OnFailure /etc/systemd/system/backup-vaultwarden.service
sudo systemctl daemon-reload
```

### 4. Rétention, à sec, puis la date

Clé branchée. Sur `pve`, root. Mot de passe au clavier, pas dans la ligne de commande.

```bash
read -r -s -p "Mot de passe Restic : " RESTIC_PASSWORD
printf '\n'
export RESTIC_PASSWORD
mkdir -p /mnt/usb-inspect
MOUNTED=0
if ! findmnt -rn -M /mnt/usb-inspect >/dev/null; then
    mount "$(findfs UUID=340F-3DAF)" /mnt/usb-inspect
    MOUNTED=1
fi
restic -r /mnt/usb-inspect/restic-homelab forget \
  --keep-within 14d --group-by host --dry-run
```

Lire ce qui serait retiré. Si le drapeau est refusé : `restic version`, s'arrêter, ne pas inventer une autre politique. Ce `--dry-run` n'applique rien. La suite reste dans le même shell : `MOUNTED` décide du démontage.

Si la liste est acceptable, écrire la date du snapshot le plus récent. Ça évite une fausse alerte tant que le prochain `backup-usb` n'a pas tourné.

```bash
python3 - <<'PY'
import json, subprocess, pathlib
from datetime import datetime
raw = subprocess.check_output(
    ["restic", "-r", "/mnt/usb-inspect/restic-homelab", "snapshots", "--json"],
    text=True,
)
snaps = json.loads(raw)
latest = max(snaps, key=lambda s: s["time"])
when = datetime.fromisoformat(latest["time"].replace("Z", "+00:00"))
stamp = when.isoformat(timespec="seconds")
print(latest["short_id"], stamp)
path = pathlib.Path("/var/lib/homelab/backup-usb-last-success")
path.parent.mkdir(mode=0o755, exist_ok=True)
path.write_text(stamp + "\n")
path.chmod(0o644)
PY
unset RESTIC_PASSWORD
if (( MOUNTED )); then
    umount /mnt/usb-inspect
fi
```

Noter l'identifiant affiché. La rétention n'est appliquée qu'au prochain `backup-usb`, avec la copie Git du script.

### 5. Contrôle et scrub

Sur `pve` :

```bash
scp -i /root/.ssh/id_ed25519_backup_k3s \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/scripts/check-sauvegardes.sh \
  /tmp/check-sauvegardes.sh
install -m 700 /tmp/check-sauvegardes.sh /usr/local/sbin/check-sauvegardes.sh
bash -n /usr/local/sbin/check-sauvegardes.sh
/usr/local/sbin/check-sauvegardes.sh
echo "code $?"
```

Code `0`, et aucun message sur le téléphone. Un message ici veut dire qu'un seuil est déjà franchi : le lire, ne pas activer le timer par-dessus.

```bash
scp -i /root/.ssh/id_ed25519_backup_k3s \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/systemd/check-sauvegardes.service \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/systemd/check-sauvegardes.timer \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/systemd/scrub-tank.service \
  utilisateur@<ip-k3s-01>:/home/utilisateur/homelab/infrastructure/pve/systemd/scrub-tank.timer \
  /tmp/
install -m 644 /tmp/check-sauvegardes.service /tmp/check-sauvegardes.timer \
  /tmp/scrub-tank.service /tmp/scrub-tank.timer \
  /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now check-sauvegardes.timer
systemctl enable --now scrub-tank.timer
systemctl list-timers 'check-sauvegardes.timer' 'scrub-tank.timer'
```

Ne pas lancer `scrub-tank.service` dans ce pas. Le premier scrub est le prochain premier dimanche, ou au démarrage si ce dimanche a été manqué (`Persistent=true`).

Copier aussi `backup-usb` (mode `700`, `bash -n`) avant le prochain run. Ce run-là applique `forget` pour de vrai. Il peut durer : `prune` réécrit les paquets.

### 6. Échec volontaire, puis retrait

Sur `pve`, root. Unit qui n'existe que le temps de l'essai.

```bash
cat > /etc/systemd/system/alerte-essai.service <<'EOF'
[Unit]
Description=Essai d'alerte, à retirer
OnFailure=notify-failure@alerte-essai.service

[Service]
Type=oneshot
ExecStart=/bin/false
EOF
systemctl daemon-reload
systemctl start alerte-essai.service || true
sleep 2
systemctl status notify-failure@alerte-essai.service --no-pager
```

`notify-failure@alerte-essai` est `status=0`. Le téléphone affiche `échec alerte-essai`. Ensuite :

```bash
systemctl reset-failed alerte-essai.service notify-failure@alerte-essai.service
rm -f /etc/systemd/system/alerte-essai.service
systemctl daemon-reload
systemctl status alerte-essai.service
```

La dernière commande doit dire que l'unit n'existe pas. Ne pas laisser `alerte-essai.service` sur la machine.

Les cinq contrôles ne sont cochés qu'une fois ce message vu, le script `backup-usb` copié, et un `forget` réel passé. Le scrub n'a pas encore tourné : le jalon « planifié » se coche quand le timer est `enabled`.

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
