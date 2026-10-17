# Vaultwarden

> Service applicatif sur K3s, namespace `vaultwarden`, géré par Argo CD ([ArgoCD.md](ArgoCD.md)).
>
> Manifestes : [kubernetes/vaultwarden/](../kubernetes/vaultwarden/).
>
> Cours Kubernetes : [Kubernetes.md](Kubernetes.md). Tunnel : [Cloudflare.md](Cloudflare.md). GitOps : [ArgoCD.md](ArgoCD.md). IP : [Proxmox.md](Proxmox.md).

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
3. Sauvegarde arrêtée : `/home/utilisateur/backups/vaultwarden/migration-2026-10-14/` (permissions restreintes). `PRAGMA integrity_check` → `ok`, 29 tables. SHA-256 de `db.sqlite3` : `<empreinte-vérifiée>`. SHA-256 de `rsa_key.pem` : `<empreinte-vérifiée>`. Ces empreintes identifient les fichiers de **cette** intervention ; elles ne remplacent pas un test de restauration.
4. `kubectl -n vaultwarden scale deployment vaultwarden --replicas=0`.
5. Pod temporaire `vaultwarden-data-copy` : ancien PVC en lecture seule (`/source`), nouveau en lecture-écriture (`/destination`) ; `cp -a` + `sync`.
6. SHA-256 `/source` vs `/destination` : aucune différence. `integrity_check` en lecture seule sur le nouveau volume : `ok`, 29 tables. Pod de copie supprimé.
7. Deployment : `claimName: vaultwarden-zfs-pvc`. Push, refresh Argo CD, **sync manuel**. Synced / Healthy.
8. Pod Running, Rocket sur :80, HTTP **200** depuis la VM, coffre OK dans le navigateur.

L'IP Pod observée au test (`10.42.0.56`) n'est **pas** stable. Pour un contrôle durable : Service Kubernetes ou `https://vaultwarden.labo.example`.

## Restauration si k3s-01 est perdu (`tank` intact)

Nouvelle VM → réattacher le zvol **sans le détruire** → filesystem (UUID) → Local PV → PVC → Vaultwarden.

Cette procédure n'a **pas** encore été testée de bout en bout.

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
| Sauvegarde récurrente | ⬜ copies de migration seulement |
| Copie hors `tank` | ⬜ |
| Test de restauration | ⬜ |
| Suppression de l'ancien PVC | ⬜ après backups + procédure de rollback |

---

# À retenir

**Kubernetes** — Un namespace isole les ressources namespacées. Un PVC ne migre pas : nouveau volume + restore. Local PV = nœud `k3s-01`. PV en service : `Retain`. Ancien PV `local-path` : `Delete` — ne pas le supprimer à la légère.

**Réseau** — Service = identité stable ; EndpointSlice = Pods actuels. Traefik lit les Ingress. Deux Ingress / même host = piège. L'IP d'un Pod n'est pas un test durable.

**Secrets** — Secret K8s ≠ coffre pour Git. Sealed Secrets = représentation chiffrée versionnable. Reseal si namespace ou nom change. `ADMIN_TOKEN` = hash Argon2id dans le cluster ; le token en clair reste dans le gestionnaire de mots de passe pour `/admin`. Un Secret en `env` n'est lu qu'au démarrage du Pod.

**GitOps** — [ArgoCD.md](ArgoCD.md). Manuel = exception.

**Sauvegardes** — Volume / snapshot / backup sont trois choses. Miroir `tank` ≠ copie indépendante. [Sauvegardes.md](Sauvegardes.md).
