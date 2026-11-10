# Vaultwarden

> Service applicatif sur K3s, namespace `vaultwarden`, géré par Argo CD ([ArgoCD.md](ArgoCD.md)).
>
> Manifestes : [kubernetes/vaultwarden/](../kubernetes/vaultwarden/).
>
> Cours Kubernetes : [Kubernetes.md](Kubernetes.md). Tunnel : [Cloudflare.md](Cloudflare.md). GitOps : [ArgoCD.md](ArgoCD.md). IP : [Proxmox.md](Proxmox.md). Principes backup : [Sauvegardes.md](Sauvegardes.md).

---

# Objectif

Un Pod Vaultwarden, SQLite, un PVC, Traefik, tunnel Cloudflare `homelab`. Namespace dédié. `ADMIN_TOKEN` : hash Argon2id dans le Secret (SealedSecret), jamais le token ni le hash en clair dans Git. Déploiement : [ArgoCD.md](ArgoCD.md).

Cloudflare Access reste sur **Proxmox**, pas devant Vaultwarden.

URL : `https://vaultwarden.labo.example`. Aucun port entrant sur la box.

---

# Architecture

```
Internet
    │ HTTPS
    ▼
Cloudflare
    │
    ▼
Tunnel "homelab"
    │ HTTP
    ▼
<ip-k3s-01>:80
    │
    ▼
Traefik
    │
    ▼
Ingress  vaultwarden.labo.example
    │
    ▼
Service  vaultwarden-service:80
    │
    ▼
Deployment vaultwarden
    │
    ▼
Pod
    │
    ▼
PVC vaultwarden-zfs-pvc → Local PV vaultwarden-zfs-pv
        → /var/lib/k3s-storage/vaultwarden → zvol tank/vmdata/vm-101-vaultwarden-data
```

Le HTTPS public est terminé par Cloudflare. Le tunnel envoie **HTTP** à Traefik. Vaultwarden authentifie lui-même ses clients.

---

# Namespace

Namespace dédié : `vaultwarden`. Les ressources ne se mélangent pas avec le reste du cluster.

| Ressource | Nom |
|-----------|-----|
| Deployment | `vaultwarden` |
| Service | `vaultwarden-service` |
| ConfigMap | `vaultwarden-config` |
| PVC (en service) | `vaultwarden-zfs-pvc` |
| PV | `vaultwarden-zfs-pv` (statique, `Retain`) |
| PVC historique (rollback) | `vaultwarden-pvc` (`local-path`, plus utilisé par le Deployment) |
| SealedSecret → Secret | `vaultwarden-secret` |
| Ingress | `vaultwarden-ingress` |

L'Application Argo CD (`kubernetes/argocd/applications/vaultwarden.yaml`) vit dans `argocd` et pointe vers `kubernetes/vaultwarden` → namespace `vaultwarden`. Découverte par le root (App of Apps), Sync manuel. Détail : [ArgoCD.md](ArgoCD.md).

---

# Manifestes

```
kubernetes/vaultwarden/
├── configmap.yaml
├── deployment.yaml
├── pv-zfs.yaml
├── pvc-zfs.yaml
├── pvc.yaml              ← historique local-path, encore dans Git
├── sealed-secret.yaml
├── service.yaml
└── ingress.yaml
```

GitOps (Application, Deploy Key) : [ArgoCD.md](ArgoCD.md).

---

# ConfigMap

Fichier : `kubernetes/vaultwarden/configmap.yaml`.

| Clé | Valeur | Rôle |
|-----|--------|------|
| `DOMAIN` | `https://vaultwarden.labo.example` | URL publique |
| `DATABASE_URL` | `sqlite://data/db.sqlite3` | SQLite sous `/data` |
| `SIGNUPS_ALLOWED` | `"false"` | Inscriptions publiques désactivées |

---

# Deployment

Fichier : `kubernetes/vaultwarden/deployment.yaml`. Image `vaultwarden/server:1.37.3`, `replicas: 1`, port 80, `/data` depuis `vaultwarden-zfs-pvc`.

```
Deployment → ReplicaSet → Pod
```

`containerPort: 80` décrit le port ; l'exposition passe par Service puis Ingress.

Depuis le ConfigMap : `DOMAIN`, `DATABASE_URL`, `SIGNUPS_ALLOWED`. `ADMIN_TOKEN` depuis `Secret/vaultwarden-secret` (`secretKeyRef`). Kubernetes injecte cette variable **au démarrage** du conteneur : un nouveau Secret ne suffit pas, il faut `kubectl -n vaultwarden rollout restart deployment/vaultwarden`.

---

# Sealed Secrets

Pas de Secret en clair dans Git. Fichier : `kubernetes/vaultwarden/sealed-secret.yaml`.

```
SealedSecret (Git)
        │
        ▼
Controller Sealed Secrets
        │
        ▼
Secret Kubernetes (cluster)
        │
        ▼
Deployment
```

Un SealedSecret est chiffré **pour un cluster, un namespace et un nom**. Changer uniquement le `namespace` dans le YAML **ne suffit pas** : il faut **resealer**. C'est ce qui a été fait pour `default` → `vaultwarden`.

Le Secret dans etcd reste lisible via l'API. Ne pas `kubectl get secret … -o yaml` sans besoin. Ni le token administrateur, ni le hash PHC, ni le ciphertext du SealedSecret ne sont dans cette doc.

**Avant** : SOPS + age (`secret.yaml`). Remplacé par Sealed Secrets (sprint 17).

## `ADMIN_TOKEN` en Argon2id (2026-10-17)

Vaultwarden avertissait : *You are using a plain text `ADMIN_TOKEN` which is insecure.*

Objectif : garder le **même** token pour `/admin` (coffre de mots de passe), stocker dans Kubernetes uniquement sa représentation Argon2id (format PHC).

Génération : Pod temporaire `vaultwarden/server:1.37.3`, commande `/vaultwarden hash --preset owasp`, saisie **interactive** (pas le token sur la ligne de commande). Contrôles locaux du hash : préfixe `$argon2id$`, six champs PHC, `v=19`, Base64 valide, pas d'espace ni de retour à la ligne, 118 octets. Le hash lui-même n'est pas documenté.

Reseal : `kubeseal` vers le controller `sealed-secrets` (ns `sealed-secrets`), fichier temporaire à permissions restreintes, puis `kubernetes/vaultwarden/sealed-secret.yaml`. Structure vérifiée : nom `vaultwarden-secret`, ns `vaultwarden`, clé `ADMIN_TOKEN`.

### Premier hash invalide

Au démarrage : `The configured Argon2 PHC in ADMIN_TOKEN is invalid: 'invalid Base64 encoding'`. CrashLoop.

Revert Git : `a499429` (*Revert "Secure Vaultwarden admin token with Argon2"*). Sync Argo CD → retour au token en clair, avertissement de nouveau présent.

### Correction

Nouveau hash, vérifié, resealé. Commit `0e5f528` (*Fix Vaultwarden Argon2 admin token hash*). Sync manuel. Le Secret commençait bien par `$argon2id$`, mais le Pod **déjà lancé** affichait encore l'avertissement « plain text ».

Cause : une variable d'environnement n'est pas rechargée quand le Secret change. Résolution :

```
kubectl -n vaultwarden rollout restart deployment/vaultwarden
kubectl -n vaultwarden rollout status deployment/vaultwarden --timeout=120s
```

Nouveau Pod : plus d'erreur Base64, plus d'avertissement « plain text » dans les logs contrôlés. `/admin` OK avec le token habituel. Argo CD Synced / Healthy (`0e5f528`).

Le token en clair reste dans un gestionnaire de mots de passe : c'est lui qu'on tape sur `/admin`. Le hash n'est pas un second mot de passe.

Le Pod temporaire `vaultwarden-hash` doit être supprimé s'il traîne encore.

---

# Stockage

SQLite dans `/data`. **En service depuis le 2026-10-14** : PVC `vaultwarden-zfs-pvc` → Local PV `vaultwarden-zfs-pv` → zvol sur `tank`. [ADR-008](ADR/ADR-008-Vaultwarden-tank.md), [Stockage.md](Stockage.md).

Vaultwarden ne connaît pas ZFS.

```
Proxmox
└── tank (miroir)
    └── tank/vmdata/vm-101-vaultwarden-data   ← 8 Gio, scsi1, iothread=1
            └── VM k3s-01  (/dev/sdb au moment de la migration)
                    └── ext4 (label vaultwarden-data)
                            └── /var/lib/k3s-storage/vaultwarden
                                    └── PV vaultwarden-zfs-pv (Retain)
                                            └── PVC vaultwarden-zfs-pvc
                                                    └── Deployment
```

| Élément | Valeur |
|---------|--------|
| VM Proxmox | 101 (`k3s-01`) |
| Volume Proxmox | `vm-101-vaultwarden-data` |
| zvol | `tank/vmdata/vm-101-vaultwarden-data` |
| Taille | 8 Gio |
| Disque Linux (constaté) | `/dev/sdb` — le nom peut changer ; `fstab` utilise l'UUID |
| Filesystem | ext4, label `vaultwarden-data` |
| UUID | `<uuid-disque-vaultwarden>` |
| Montage | `/var/lib/k3s-storage/vaultwarden` (`defaults,noatime`) |
| PV | `vaultwarden-zfs-pv` |
| PVC | `vaultwarden-zfs-pvc` (ns `vaultwarden`) |
| StorageClass | `vaultwarden-zfs-local` |
| Rétention PV | `Retain` |
| Nœud | `k3s-01` (`nodeAffinity`) |

`fstab` (VM) :

```
UUID=<uuid-disque-vaultwarden> /var/lib/k3s-storage/vaultwarden ext4 defaults,noatime 0 2
```

Vérifié : `findmnt`, `df`. Occupation constatée après migration : ~7,8 Gio, 3,4 Mio utilisés côté filesystem ; `du -sh` ~1,4 Mio de fichiers visibles. L'écart n'a pas été investigué ; aucun dysfonctionnement observé.

Ce Local PV est lié au nœud `k3s-01`. Le miroir `tank` persiste le disque côté Proxmox. Ce n'est **pas** un stockage Kubernetes partagé entre nœuds. Snapshots ZFS ≠ sauvegarde.

## Historique `local-path` (conservé)

Avant : PVC `vaultwarden-pvc` 5 Gi, `local-path`, PV `pvc-<uuid-pv-local-path>`, répertoire `/var/lib/rancher/k3s/storage/pvc-<uuid-pv-local-path>_vaultwarden_vaultwarden-pvc`, ext4 sur le disque système (`/dev/sda` / `rpool`).

Ce PVC **existe encore** et reste dans Git (`pvc.yaml`). Il n'est **plus** monté par le Deployment.

**Attention** : depuis la bascule, ce volume n'est plus synchronisé. Un rollback ne consiste pas à changer seulement le `claimName` : il faut d'abord savoir quelle copie est la plus récente, et recopier / restaurer **Vaultwarden arrêté**.

L'ancien PV `local-path` a une politique **`Delete`**. Ne pas supprimer l'ancien PVC / PV sans avoir compris que Kubernetes peut alors effacer les données restantes. Le PV en service (`vaultwarden-zfs-pv`) est en **`Retain`**.

## Migration `local-path` → `tank` (2026-10-14)

Terminée et validée. GitOps : commit `8ccecbc`.

1. Volume ZFS 8 Gio, attaché `scsi1`, ext4, `fstab` par UUID, montage vérifié.
2. Manifestes `pv-zfs.yaml` / `pvc-zfs.yaml` appliqués ; PV et PVC **Bound**. Ancien PVC conservé.
3. Sauvegarde arrêtée : `/home/utilisateur/backups/vaultwarden/migration-2026-10-14/` (permissions restreintes). `PRAGMA integrity_check` → `ok`, 29 tables. SHA-256 de `db.sqlite3` : `<empreinte-vérifiée>`. SHA-256 de `rsa_key.pem` : `<empreinte-vérifiée>`. Ces empreintes identifient les fichiers de **cette** intervention. Un test de restauration **technique** a eu lieu le 20 octobre 2026 ([ci-dessous](#test-du-20-octobre-2026-technique)). Login + coffre : 21 octobre ([test fonctionnel](#test-fonctionnel--https-local)).
4. `kubectl -n vaultwarden scale deployment vaultwarden --replicas=0`.
5. Pod temporaire `vaultwarden-data-copy` : ancien PVC en lecture seule (`/source`), nouveau en lecture-écriture (`/destination`) ; `cp -a` + `sync`.
6. SHA-256 `/source` vs `/destination` : aucune différence. `integrity_check` en lecture seule sur le nouveau volume : `ok`, 29 tables. Pod de copie supprimé.
7. Deployment : `claimName: vaultwarden-zfs-pvc`. Push, refresh Argo CD, **sync manuel**. Synced / Healthy.
8. Pod Running, Rocket sur :80, HTTP **200** depuis la VM, coffre OK dans le navigateur.

L'IP Pod observée au test (`10.42.0.56`) n'est **pas** stable. Pour un contrôle durable : Service Kubernetes ou `https://vaultwarden.labo.example`.

## Restauration si k3s-01 est perdu (`tank` intact)

Voir [Reprise réelle](#reprise-réelle--non-testée), cas 2. Procédure **écrite**, pas exécutée de bout en bout.

## Contrôles utiles

```
kubectl -n argocd get application vaultwarden
kubectl -n vaultwarden get pods
kubectl -n vaultwarden get pvc
kubectl get pv vaultwarden-zfs-pv
findmnt /var/lib/k3s-storage/vaultwarden
df -h /var/lib/k3s-storage/vaultwarden
kubectl -n vaultwarden logs deployment/vaultwarden --since=10m
```

Clés du Secret **sans** les valeurs :

```
kubectl -n vaultwarden get secret vaultwarden-secret \
  -o go-template='{{range $k, $v := .data}}{{$k}}{{"\n"}}{{end}}'
```

Logs liés au token (fenêtre `--since` seulement) :

```
kubectl -n vaultwarden logs deployment/vaultwarden --since=10m \
  | grep -Ei 'plain text ADMIN_TOKEN|invalid Base64|Argon2|error|Rocket has launched'
```

Une absence de message dans ce `grep` ne remplace pas le test du coffre et de `/admin`. HTTP : Service du namespace, ou `https://vaultwarden.labo.example` — pas l'IP du Pod.

---

# Service et Ingress

Service ClusterIP `vaultwarden-service:80`, `targetPort: http`, selector `app: vaultwarden`.

Ingress Traefik : host `vaultwarden.labo.example`, path `/` `Prefix`.

Deux Ingress avec le **même hostname** (même dans des namespaces différents) cassent le routage Traefik. Toujours `kubectl get ingress -A` avant une bascule.

---

# Cloudflare

Tunnel `homelab` : `vaultwarden.labo.example` → `http://<ip-k3s-01>:80` (Traefik, pas le Pod). [Cloudflare.md](Cloudflare.md).

Access : Proxmox seulement.

---

# Argo CD

Géré par l'Application `vaultwarden` : path `kubernetes/vaultwarden`, destination `vaultwarden`, `targetRevision: HEAD`. Sync **manuel**. État constaté après Argon2 : **Synced** / **Healthy** (révision `0e5f528`). Migration stockage : `8ccecbc`.

Flux, dépôt SSH, patron pour les prochaines applis : [ArgoCD.md](ArgoCD.md).

---

# Migration `default` → `vaultwarden`

## Motif

Séparer les ressources. Nouveau PVC (un PVC ne change pas de namespace). Reseal du SealedSecret. Introduction d'Argo CD sur une appli déjà en place.

## Données

Ancien PVC `default/vaultwarden-pvc`, PV `pvc-<uuid-pv-default>`. Deployment arrêté pour figer les données.

Sauvegarde : `/home/utilisateur/backups/vaultwarden/` (`db.sqlite3`, WAL/SHM, `rsa_key.pem`, `icon_cache/`, `tmp/`). Hashes vérifiés (`db.sqlite3`, `rsa_key.pem`).

Nouveau PVC 5 Gi / RWO / `local-path`. `WaitForFirstConsumer` : un Pod temporaire a monté le volume pour le provisionner, puis copie + re-vérification des hashes.

Nouveau SealedSecret appliqué. Pod Running. Coffre et données vérifiés dans l'UI.

## Traefik 503

Pod et Service : 200. Traefik : **503**. Cause : l'Ingress `default/vaultwarden-ingress` existait encore pour le même host, vers un Service **sans endpoint**.

Correction : `kubectl delete ingress vaultwarden-ingress -n default` → Traefik 200.

Leçon : avant de basculer, lister tous les Ingress du hostname.

## Nettoyage

Après validation (coffre, données, Pod, PVC Bound, Argo CD Synced/Healthy) : suppression dans `default` du Deployment, Service, Secret, SealedSecret, PVC. L'ancien PV a suivi la politique de rétention. Il ne reste que le PV du namespace `vaultwarden`.

---

# Sauvegarde

**2026-10-21** — tar auto du 21 oct. restauré en isolé : SHA vérifié, HTTPS local, login + 2FA, coffre lisible. Nettoyage confirmé (`sudo` pour `/var/tmp/…`). Production `1/1`, archives d'origine conservées.

Aucun mot de passe Restic, aucune clé privée, aucun secret applicatif. Chaîne et USB : [Sauvegardes.md](Sauvegardes.md#chaîne-actuelle). `pve` : [Proxmox.md](Proxmox.md#exploitation).

On privilégie des `.tar` identifiables, pas uniquement des snapshots. Interruption nocturne acceptée (SQLite + WAL cohérents).

## Emplacements

| Rôle | Installé | Git |
|------|----------|-----|
| Script k3s-01 | `/usr/local/sbin/backup-vaultwarden.sh` (`700` root) | [`infrastructure/k3s-01/services/vaultwarden/backup-vaultwarden.sh`](../infrastructure/k3s-01/services/vaultwarden/backup-vaultwarden.sh) |
| Units k3s-01 | `/etc/systemd/system/backup-vaultwarden.{service,timer}` | [`infrastructure/k3s-01/systemd/`](../infrastructure/k3s-01/systemd/) |
| Archives locales | `/home/utilisateur/backups/vaultwarden/daily` | — |
| Script pull | `/usr/local/sbin/pull-vaultwarden-backup.sh` | [`infrastructure/pve/scripts/pull-vaultwarden-backup.sh`](../infrastructure/pve/scripts/pull-vaultwarden-backup.sh) |
| Units pull | `/etc/systemd/system/pull-vaultwarden-backup.{service,timer}` | [`infrastructure/pve/systemd/`](../infrastructure/pve/systemd/) |
| Archives `pve` | `/tank/backups/k3s-01/vaultwarden` | — |
| Clé SSH (`pve` seulement) | `/root/.ssh/id_ed25519_backup_k3s` | **jamais** |
| Données live | `/var/lib/k3s-storage/vaultwarden` | — |
| Kubeconfig du job | `/etc/rancher/k3s/k3s.yaml` | — |

Git ≠ machines. Après un changement : copier, permissions, syntaxe, tester. Premier commit du script local : `3d86d72`.

Dans le tar : `db.sqlite3`, `db.sqlite3-wal`, `db.sqlite3-shm` (si présent), `rsa_key.pem`, `icon_cache/`, `tmp/`. `lost+found` exclu. Nom : `vaultwarden-AAAA-MM-JJ_HHMMSS.tar`. Exemples : `…-2026-10-19_163746.tar` (manuel) ; `…-2026-10-20_030012.tar` et archive du **21 oct.** (timers 03:00). Une ancienne `vaultwarden-2026-10-19.tar` a existé. Conserver **ensemble** sqlite + WAL + SHM.

## k3s-01 — 03:00

`set -Eeuo pipefail`, verrou, lecture du nombre de réplicas, scale à 0, attente des Pods, tar temporaire, archive lisible, présence de `db.sqlite3` et `rsa_key.pem`, `600` `utilisateur:utilisateur`, publication après contrôles, scale retour + attente Available, rétention 7. Trap : relance Vaultwarden si le script l'a déjà arrêté.

Service : `Type=oneshot`, `User=root`, `KUBECONFIG=…/k3s.yaml`, `TimeoutStartSec=10min`. Timer : `OnCalendar=*-*-* 03:00:00`, `Persistent=true`. Activé le 19 octobre : `active (waiting)`, prochain run alors **2026-10-20 03:00 CEST**. `Persistent=true` ≠ supervision.

Heure locale, CEST (UTC+2) au moment de la config.

## pve — 03:15

Clé dédiée, SSH non interactif testé (`IdentitiesOnly`, pas de mot de passe). `flock`. Liste `vaultwarden-*.tar` **les plus récentes d'abord**. SHA-256 source. Déjà présent + même hash → skip. Hash différent → **erreur** (pas d'écrasement). Sinon : `.part`, SHA, `tar -tf`, `600`, rename. Échec de validation → suppression du `.part`. Rétention 7 (mtime destination — à confirmer en réel). Vérifier que « 7 » reste le bon besoin avant de changer le script.

Units : mêmes `oneshot` / `TimeoutStartSec=10min` / `Persistent=true`. Timer 03:15. Activé le 19 octobre, prochain run alors **03:15 CEST**. Les 15 minutes ne prouvent pas que le 03:00 a réussi.

Pull : [`infrastructure/pve/scripts/pull-vaultwarden-backup.sh`](../infrastructure/pve/scripts/pull-vaultwarden-backup.sh). USB de `/tank/backups` : [Sauvegardes.md](Sauvegardes.md#usb--restic).

## Tests du 19 octobre 2026

**Local** : `…/daily/vaultwarden-2026-10-19_163746.tar` ; `db.sqlite3` + `rsa_key.pem` ; tar OK ; `600` `utilisateur:utilisateur` ; Deployment `1/1` ; `bash -n` OK.

**Transfert** : SHA-256 `<empreinte-vérifiée>` identique source / `pve`. Publié sous le nom final.

**Pull (version actuelle)** : idempotent sur l'archive déjà là. Tri corrigé (récentes d'abord). **Pas encore** testé avec une archive absente de la destination. `systemd-analyze verify` : les quatre unités OK.

## Contrôles (timers)

```
# k3s-01
sudo journalctl -u backup-vaultwarden.service --since today --no-pager
sudo systemctl status backup-vaultwarden.timer --no-pager
sudo systemctl list-timers backup-vaultwarden.timer --all
ls -lh /home/utilisateur/backups/vaultwarden/daily/
sudo kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml \
  -n vaultwarden get deployment vaultwarden

# pve
journalctl -u pull-vaultwarden-backup.service --since today --no-pager
systemctl status pull-vaultwarden-backup.timer --no-pager
systemctl list-timers pull-vaultwarden-backup.timer --all
ls -lh /tank/backups/k3s-01/vaultwarden/
sha256sum /tank/backups/k3s-01/vaultwarden/NOM_ARCHIVE.tar
```

Comparer les SHA. Ne pas supprimer d'archives avant d'avoir compté les générations. Attendu : nouvelle archive auto, tar lisible, fichiers critiques, Vaultwarden 1/1, pull sans erreur, pas de `.part` publié, rétention 7.

## Restauration

Les tests du 20 et 21 octobre prouvent qu'un tar **démarre un coffre isolé**. Ils ne remettent **pas** le volume de production.

Un `.tar` sorti d'un snapshot Restic à la mise au point USB n'est pas non plus une restauration du service.

### Reprise réelle — non testée

**Statut : écrite le 21 octobre 2026, jamais jouée sur la prod.** Ne pas improviser dans l'UI Proxmox.

Choisir le cas **avant** d'écrire sur un disque.

| Situation | Faire |
|---|---|
| VM et zvol OK, coffre OK | Ne pas restaurer. Diagnostiquer. |
| VM OK, `tank` OK, données zvol corrompues / coffre illisible | **Cas 1** — tar sur le volume live |
| `k3s-01` / `rpool` perdu, `tank` intact, zvol encore là | **Cas 2** — réattacher le zvol, **ne pas** en créer un autre |
| `tank` perdu | **Cas 3** — USB / Restic, puis **nouveau** zvol + tar |

L'ancien PVC `vaultwarden-pvc` (`local-path`) **n'est pas** un rollback.

#### Interdits

- `zfs destroy` / supprimer le disque dans l'UI / `qm destroy … --purge` sur `vm-101-vaultwarden-data`.
- Extraire un tar vers `/var/lib/k3s-storage/vaultwarden` **tant que** le Deployment a des Pods.
- Monter ce chemin dans un Pod de *test*.
- Recréer un volume `tank-vmdata` du même nom si le zvol existe encore (l'UI « Add Hard Disk » **crée**).
- Restaurer sans SHA-256, ou une archive plus vieille que nécessaire.

Arrêter les timers le temps de la manœuvre (`backup-vaultwarden.timer` sur k3s-01, `pull-vaultwarden-backup.timer` sur `pve`), les réactiver après.

#### Cas 1 — tar sur le volume live

VM `k3s-01` joignable, zvol monté, SQLite ou coffre inutilisable.

1. Dernière archive saine sur `pve` : `/tank/backups/k3s-01/vaultwarden/vaultwarden-*.tar`. SHA-256. Transfert comme au [test](#transfert), nom local distinct (`restore-vaultwarden-prod.tar`).
2. Si le live est encore lisible, copie de précaution **hors** du zvol :

```bash
sudo tar --exclude='./lost+found' \
  -cpf /home/utilisateur/backups/vaultwarden/pre-restore-$(date +%F_%H%M%S).tar \
  -C /var/lib/k3s-storage/vaultwarden .
```

3. Arrêter Vaultwarden, attendre zéro Pod (comme le script de backup) :

```bash
kubectl -n vaultwarden scale deployment/vaultwarden --replicas=0
# boucle jusqu'à : kubectl -n vaultwarden get pods → rien
findmnt /var/lib/k3s-storage/vaultwarden
```

4. Extraire **dans** le montage de prod (sqlite + WAL + SHM ensemble). `sudo` : le répertoire est root.

```bash
sudo tar -xf /home/utilisateur/restore-vaultwarden-prod.tar \
  -C /var/lib/k3s-storage/vaultwarden
sudo sqlite3 /var/lib/k3s-storage/vaultwarden/db.sqlite3 'PRAGMA integrity_check;'
```

Attendu : `ok`. `lost+found` n'est pas dans l'archive ; le laisser.

5. Relancer, **même** image `1.37.3` :

```bash
kubectl -n vaultwarden scale deployment/vaultwarden --replicas=1
kubectl -n vaultwarden rollout status deployment/vaultwarden --timeout=180s
```

6. Contrôle : `https://vaultwarden.labo.example` (HTTPS public, pas le test `localhost`). Login + 2FA + un élément lisible. Prod `1/1`. Réactiver les timers. Supprimer le tar de transfert, **pas** les archives `pve` / daily / pré-restore.

#### Cas 2 — k3s-01 perdu, `tank` intact

Le coffre est dans le zvol, **pas** dans le disque système de la VM.

1. Sur `pve` : `zfs list tank/vmdata/vm-101-vaultwarden-data`. S'il n'y est plus → cas 3. S'il y est : **ne pas** créer de disque.
2. Nouvelle VM : IP `<ip-k3s-01>` si possible, **hostname OS `k3s-01`** (`nodeAffinity` du PV). Disque système neuf sur `rpool`. Attacher le zvol **existant** en `scsi1` / `iothread=1` (disque unused, ou `qm set`). Pas « Add Hard Disk » sur `tank-vmdata`.
3. Boot. UUID attendu : `<uuid-disque-vaultwarden>` (`blkid`). `fstab` + montage `/var/lib/k3s-storage/vaultwarden` comme [Stockage](#stockage). `findmnt` / `ls` : `db.sqlite3`, `rsa_key.pem`.
4. Réinstaller K3s, Traefik, Sealed Secrets, Argo CD ([ArgoCD.md](ArgoCD.md), [Kubernetes.md](Kubernetes.md)). Restaurer la clé Sealed Secrets depuis `/tank/backups/k3s-01/sealed-secrets/` ou l'USB (`~/backups/sealed-secrets/` sur l'ancienne VM meurt avec `rpool`). Sans cette clé : nouveau `ADMIN_TOKEN`, reseal ; le coffre utilisateur est dans le tar/zvol, pas dans ce Secret.
5. GitOps : Application Vaultwarden, **sync manuel**. PV `Retain` → chemin `/var/lib/k3s-storage/vaultwarden`. PVC Bound, Deployment `1/1`.
6. Login sur l'URL publique. Si le zvol est sain, **pas** d'extraction de tar. Tar seulement si les fichiers montés sont mauvais (cas 1 une fois la VM là).

#### Cas 3 — `tank` perdu

`/tank/backups` part avec `tank`. Seul le niveau USB reste ([Sauvegardes.md](Sauvegardes.md#usb--restic)).

1. Recréer `tank` / `tank/vmdata` si besoin. **Nouveau** zvol (l'ancien n'existe plus), 8 Gio, `scsi1`, ext4, UUID **nouveau** → mettre à jour `fstab` (l'UUID `b4913e83-…` est mort avec l'ancien filesystem).
2. Sortir le tar depuis Restic (SHA identique). Puis cas 1 sur ce volume neuf.
3. Cluster : comme cas 2 si k3s-01 est aussi perdu.

#### Après une reprise

- Timers de nouveau actifs.
- Une sauvegarde **après** validation du coffre, pour ne pas n'avoir que l'archive d'avant incident.
- Cette procédure reste ⬜ jusqu'à une exécution réelle (ou un exercice volontaire sur un zvol **de test**, jamais le zvol live).

### Test du 20 octobre 2026 (technique)

Archive : `vaultwarden-2026-10-20_030012.tar` (job 03:00). SHA-256 `<empreinte-vérifiée>` — identique k3s-01, `pve`, et copie de test.

**pve** — extraction temporaire. Présents : `db.sqlite3`, WAL, SHM, `rsa_key.pem`, `icon_cache/`, `tmp/`. `PRAGMA integrity_check` = `ok`. 29 tables, 56 migrations, 1 utilisateur, 119 `ciphers`, 8 appareils, 1 enregistrement 2FA, 0 pièce jointe, 0 dossier.

#### Transfert

Depuis `pve` :

```bash
scp -i /root/.ssh/id_ed25519_backup_k3s \
  /tank/backups/k3s-01/vaultwarden/vaultwarden-2026-10-20_030012.tar \
  utilisateur@<ip-k3s-01>:/home/utilisateur/restore-vaultwarden-test.tar
```

Sur k3s-01 :

```bash
sha256sum /home/utilisateur/restore-vaultwarden-test.tar
# attendu :
# <empreinte-vérifiée>  /home/utilisateur/restore-vaultwarden-test.tar
```

#### Extraction isolée

`sudo` : le répertoire est sous `/var/tmp`. Refuse si le chemin existe déjà. **Ne pas** extraire vers `/var/lib/k3s-storage/vaultwarden`.

```bash
sudo bash -c '
set -euo pipefail
RESTORE_DIR=/var/tmp/vaultwarden-restore-test
if [ -e "$RESTORE_DIR" ]; then
  echo "ERREUR : le répertoire existe déjà."
  exit 1
fi
install -d -m 700 "$RESTORE_DIR"
tar -xf /home/utilisateur/restore-vaultwarden-test.tar -C "$RESTORE_DIR"
find "$RESTORE_DIR" -maxdepth 1 -type f -printf "%f (%s octets)\n" | sort
'
```

Fichiers extraits : `db.sqlite3` 421888, SHM 32768, WAL 41232, `rsa_key.pem` 1675.

#### Pod temporaire

```bash
kubectl create namespace vaultwarden-restore-test
```

Manifeste `/tmp/vaultwarden-restore-test.yaml` — version **sans** `DOMAIN`. Avec `DOMAIN=http://127.0.0.1:18080`, l'UI a refusé HTTP (`Insecure URL not allowed`).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vaultwarden-restore-test
  namespace: vaultwarden-restore-test
  labels:
    app: vaultwarden-restore-test
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  containers:
    - name: vaultwarden
      image: vaultwarden/server:1.37.3
      ports:
        - containerPort: 80
      env:
        - name: DATABASE_URL
          value: "sqlite://data/db.sqlite3"
        - name: SIGNUPS_ALLOWED
          value: "false"
      volumeMounts:
        - name: restored-data
          mountPath: /data
  volumes:
    - name: restored-data
      hostPath:
        path: /var/tmp/vaultwarden-restore-test
        type: Directory
```

```bash
kubectl apply -f /tmp/vaultwarden-restore-test.yaml
kubectl get pod -n vaultwarden-restore-test -o wide
kubectl logs -n vaultwarden-restore-test vaultwarden-restore-test --tail=60
```

Pod `1/1 Running` (IP du moment, pas une constante). Logs : *Starting Vaultwarden* / *Version 1.37.3* / *Rocket has launched from http://0.0.0.0:80*. Aucune erreur de démarrage.

```bash
kubectl port-forward -n vaultwarden-restore-test \
  pod/vaultwarden-restore-test 18080:80
```

Autre terminal :

```bash
curl -sS -o /dev/null -w 'HTTP %{http_code}\n' \
  http://127.0.0.1:18080/
```

Résultat : **HTTP 200**. Firefox : `Insecure URL not allowed. All URLs must use HTTPS.` Pas d'HTTPS temporaire. Connexion au compte / déchiffrement : **non validés**.

#### Nettoyage

```bash
kubectl delete namespace vaultwarden-restore-test
kubectl get namespace vaultwarden-restore-test
# Error from server (NotFound): namespaces "vaultwarden-restore-test" not found

rm -rf -- /var/tmp/vaultwarden-restore-test &&
rm -f -- /home/utilisateur/restore-vaultwarden-test.tar
ls -ld /var/tmp/vaultwarden-restore-test \
  /home/utilisateur/restore-vaultwarden-test.tar
```

Archives d'origine conservées (`/home/utilisateur/backups/vaultwarden/daily/` et `/tank/backups/k3s-01/vaultwarden/`). Production inchangée. Ce Pod **n'existe plus** dans le cluster.

### Test fonctionnel — HTTPS local

**2026-10-21** — réussi. Archive du 21 octobre 2026 (dernière sur `pve`), SHA vérifié. Production non montée. Nom exact du tar et empreinte : non recopiés ici.

Objectif : sur une instance **isolée**, se connecter et déchiffrer le coffre. Pas de Traefik, pas de DNS public, pas de Cloudflare.

`ROCKET_TLS` n'est **pas** un modèle pour la prod (le HTTPS public reste Cloudflare). Ici, c'est uniquement pour obtenir un contexte sécurisé dans Firefox.

#### Contraintes

- Certificat **RSA** (Rocket refuse l'ECC).
- `DOMAIN` = URL exacte du navigateur, **port compris**.
- Certificats **hors** du répertoire restauré (`/ssl` ≠ `/data`).
- 2FA : un enregistrement existe dans la base — avoir le TOTP sous la main.
- Ne **pas** modifier le coffre pendant le test (instance jetable, mais autant ne pas s'habituer à écrire dedans).
- Si Firefox est sur Windows : `kubectl port-forward` sur k3s-01 **et** un tunnel SSH vers ce port.

#### 1. Transfert et extraction

Reprendre [Transfert](#transfert) et [Extraction isolée](#extraction-isolée) avec l'archive choisie (la plus récente sur `pve`, SHA vérifié). Mêmes chemins : `/home/utilisateur/restore-vaultwarden-test.tar` et `/var/tmp/vaultwarden-restore-test`. Ne jamais extraire vers `/var/lib/k3s-storage/vaultwarden`.

#### 2. Certificat jetable (k3s-01)

```bash
sudo bash -c '
set -euo pipefail
SSL_DIR=/var/tmp/vaultwarden-restore-test-ssl
if [ -e "$SSL_DIR" ]; then
  echo "ERREUR : $SSL_DIR existe déjà."
  exit 1
fi
install -d -m 700 "$SSL_DIR"
openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 1 \
  -keyout "$SSL_DIR/key.pem" \
  -out "$SSL_DIR/cert.pem" \
  -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
chmod 600 "$SSL_DIR/key.pem" "$SSL_DIR/cert.pem"
openssl x509 -in "$SSL_DIR/cert.pem" -noout -subject -dates -ext subjectAltName
'
```

#### 3. Namespace et Pod

```bash
kubectl create namespace vaultwarden-restore-test
```

`/tmp/vaultwarden-restore-test.yaml` :

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: vaultwarden-restore-test
  namespace: vaultwarden-restore-test
  labels:
    app: vaultwarden-restore-test
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  containers:
    - name: vaultwarden
      image: vaultwarden/server:1.37.3
      ports:
        - containerPort: 80
      env:
        - name: DOMAIN
          value: "https://localhost:18443"
        - name: DATABASE_URL
          value: "sqlite://data/db.sqlite3"
        - name: SIGNUPS_ALLOWED
          value: "false"
        - name: ROCKET_TLS
          value: '{certs="/ssl/cert.pem",key="/ssl/key.pem"}'
      volumeMounts:
        - name: restored-data
          mountPath: /data
        - name: tls
          mountPath: /ssl
          readOnly: true
  volumes:
    - name: restored-data
      hostPath:
        path: /var/tmp/vaultwarden-restore-test
        type: Directory
    - name: tls
      hostPath:
        path: /var/tmp/vaultwarden-restore-test-ssl
        type: Directory
```

```bash
kubectl apply -f /tmp/vaultwarden-restore-test.yaml
kubectl get pod -n vaultwarden-restore-test -o wide
kubectl logs -n vaultwarden-restore-test vaultwarden-restore-test --tail=60
```

Attendu dans les logs : démarrage 1.37.3, Rocket lancé en HTTPS, **pas** d'erreur `ROCKET_TLS` / certificat. Le port 80 du conteneur sert alors du **HTTPS**.

Observé le 21 oct. : `Rocket has launched from https://0.0.0.0:80`. Avertissements HSTS (`TLS-enabled liftoff without enabling HSTS`, politique HSTS par défaut) : **normaux** pour ce test, pas un échec.

#### 4. Accès depuis le navigateur

Sur k3s-01 :

```bash
kubectl port-forward -n vaultwarden-restore-test \
  pod/vaultwarden-restore-test 18443:80
```

Si Firefox est sur Windows, dans un autre terminal **local** :

```bash
ssh -L 18443:127.0.0.1:18443 utilisateur@<ip-k3s-01>
```

Contrôle (sur la machine où le port 18443 est ouvert) :

```bash
curl -skS -o /dev/null -w 'HTTPS %{http_code}\n' \
  https://localhost:18443/
```

Attendu : **HTTPS 200** (`-k` : certificat auto-signé). Observé le 21 oct.

Firefox : **`https://localhost:18443`** (pas `http://`, pas `127.0.0.1`). Accepter l'exception de certificat.

**21 oct.** : warning certificat → site local HTTPS ; login + 2FA OK ; entrées visibles ; mots de passe lisibles / éditables. Coffre déchiffré.

#### 5. Nettoyage

**21 oct.** : confirmé. Les répertoires sous `/var/tmp` ont été créés en `sudo` : le `rm` aussi.

Après avoir noté le résultat :

```bash
kubectl delete namespace vaultwarden-restore-test
sudo rm -rf -- /var/tmp/vaultwarden-restore-test \
  /var/tmp/vaultwarden-restore-test-ssl
rm -f -- /home/utilisateur/restore-vaultwarden-test.tar /tmp/vaultwarden-restore-test.yaml
```

Vérifier l'absence des chemins et `kubectl -n vaultwarden get deploy vaultwarden` → `1/1`. Archives d'origine conservées. Observé le 21 oct. : chemins absents, Deployment prod `1/1`, archives conservées.

#### Critères de succès

| Contrôle | Attendu |
|---|---|
| SHA de l'archive | ✅ vérifié (21 oct.) |
| Pod de test | ✅ `Running`, HTTPS sur :80 |
| `curl -sk https://localhost:18443/` | ✅ 200 |
| Login + 2FA + coffre lisible | ✅ 2026-10-21 |
| Production | ✅ `1/1` (21 oct., après nettoyage) |
| Nettoyage | ✅ ns et `/var/tmp/…` absents (`sudo` pour `/var/tmp`) |

Si Firefox refuse encore HTTP/HTTPS : vérifier que l'URL est exactement `https://localhost:18443` (alignée sur `DOMAIN`).

## Limites / suite

- Pull dépend du réseau `pve` → k3s-01.
- ✅ Tars auto 03:00 (20 et 21 oct.) + copie sur `pve`
- ⬜ Rétention 7 en réel sur plusieurs jours
- ⬜ Pull d'une archive absente (sans détruire une sauvegarde utile)
- ✅ Connexion utilisateur + coffre déchiffré (HTTPS local, 21 oct.)
- ✅ Nettoyage du test du 21 oct. (prod `1/1`)
- ⬜ Reprise réelle (cas 1–3 [écrits](#reprise-réelle--non-testée), jamais exécutés)
- ⬜ Diagnostic d'échec USB : [Sauvegardes.md](Sauvegardes.md#usb--restic)

---

# État

| Élément | État |
|---------|------|
| Namespace `vaultwarden` | OK |
| Deployment 1/1 Running | OK |
| Service ClusterIP / Ingress Traefik | OK |
| PVC `vaultwarden-zfs-pvc` / PV `vaultwarden-zfs-pv` | OK Bound (`tank`) |
| PVC historique `vaultwarden-pvc` | conservé (figé, rollback) |
| SealedSecret Synced | OK |
| Volume bloc sur `tank` | ✅ 2026-10-14 ([ADR-008](ADR/ADR-008-Vaultwarden-tank.md)) |
| Argo CD Synced / Healthy | OK (`0e5f528`) |
| `https://vaultwarden.labo.example` | OK |
| Access devant Vaultwarden | volontairement absent |
| `ADMIN_TOKEN` en Argon2 PHC | ✅ 2026-10-17 (`0e5f528` ; rollout restart requis) |
| Sauvegarde quotidienne | ✅ tars auto 20 et 21 oct. — [chapitre](#sauvegarde) |
| Copie sur `pve` (`/tank/backups`) | ✅ SHA vérifié (dont 21 oct.) |
| Copie USB / Restic | manuel (`backup-usb` : `/tank/backups` + dossiers perso live, script Git 24 oct.) |
| Restore technique (ns isolé, HTTP 200) | ✅ 2026-10-20 ; prod intacte |
| Connexion / déchiffrement après restore | ✅ 2026-10-21 (HTTPS local, 2FA, coffre lisible) |
| Reprise réelle (zvol / tar sur prod) | ⬜ [procédure écrite](#reprise-réelle--non-testée), non exécutée |
| Suppression de l'ancien PVC | ⬜ plus tard (ménage, pas un rollback) |

---

# À retenir

**Kubernetes** — Un namespace isole les ressources namespacées. Un PVC ne migre pas : nouveau volume + restore. Local PV = nœud `k3s-01`. PV en service : `Retain`. Ancien PV `local-path` : `Delete` — ne pas le supprimer à la légère.

**Réseau** — Service = identité stable ; EndpointSlice = Pods actuels. Traefik lit les Ingress. Deux Ingress / même host = piège. L'IP d'un Pod n'est pas un test durable.

**Secrets** — Secret K8s ≠ coffre pour Git. Sealed Secrets = représentation chiffrée versionnable. Reseal si namespace ou nom change. `ADMIN_TOKEN` = hash Argon2id dans le cluster ; le token en clair reste dans le gestionnaire de mots de passe pour `/admin`. Un Secret en `env` n'est lu qu'au démarrage du Pod.

**GitOps** — [ArgoCD.md](ArgoCD.md). Manuel = exception.

**Sauvegardes** — Volume / snapshot / backup sont trois choses. Archive locale → `tank/backups` → USB. Restore isolée (technique + login) ≠ reprise sur le zvol de prod. [Chapitre Sauvegarde](#sauvegarde).
