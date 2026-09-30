# Vaultwarden

> Service applicatif sur K3s, namespace `vaultwarden`, géré par Argo CD ([ArgoCD.md](ArgoCD.md)).
>
> Manifestes : [kubernetes/vaultwarden/](../kubernetes/vaultwarden/).
>
> Cours Kubernetes : [Kubernetes.md](Kubernetes.md). Tunnel : [Cloudflare.md](Cloudflare.md). GitOps : [ArgoCD.md](ArgoCD.md). IP : [Proxmox.md](Proxmox.md).

---

# Objectif

Un Pod Vaultwarden, SQLite, un PVC, Traefik, tunnel Cloudflare `homelab`. Namespace dédié. `ADMIN_TOKEN` via Sealed Secrets, jamais en clair dans Git. Déploiement : [ArgoCD.md](ArgoCD.md).

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
PVC vaultwarden-pvc → PV local-path (nœud k3s-01)
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
| PVC | `vaultwarden-pvc` |
| SealedSecret → Secret | `vaultwarden-secret` |
| Ingress | `vaultwarden-ingress` |

L'Application Argo CD (`kubernetes/argocd/vaultwarden-application.yaml`) vit dans `argocd` et pointe vers `kubernetes/vaultwarden` → namespace `vaultwarden`. Détail : [ArgoCD.md](ArgoCD.md).

---

# Manifestes

```
kubernetes/vaultwarden/
├── configmap.yaml
├── deployment.yaml
├── pvc.yaml
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

Fichier : `kubernetes/vaultwarden/deployment.yaml`. Image `vaultwarden/server:1.37.3`, `replicas: 1`, port 80, `/data` depuis `vaultwarden-pvc`.

```
Deployment → ReplicaSet → Pod
```

`containerPort: 80` décrit le port ; l'exposition passe par Service puis Ingress.

Depuis le ConfigMap : `DOMAIN`, `DATABASE_URL`, `SIGNUPS_ALLOWED`. `ADMIN_TOKEN` depuis `Secret/vaultwarden-secret`. Si le Secret change, `kubectl rollout restart deployment vaultwarden -n vaultwarden`.

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

Le Secret dans etcd reste en clair côté API. Ne pas `kubectl get secret … -o yaml` sans besoin. La valeur réelle d'`ADMIN_TOKEN` n'est ni dans cette doc ni dans une conversation.

**Avant** : SOPS + age (`secret.yaml`). Remplacé par Sealed Secrets pour que le cluster déchiffre tout seul. Journal : sprint 17.

---

# Stockage

SQLite dans `/data`. PVC `vaultwarden-pvc` : 5 Gi, `ReadWriteOnce`, StorageClass `local-path` (`WaitForFirstConsumer`).

PV actuel (constaté) : `pvc-<uuid-pv-local-path>`, lié au nœud **k3s-01**.

Ces données sont sur le **disque de la VM** (donc `rpool`), **pas** sur le miroir `tank`. Déplacer le volume vers `tank` est prévu **plus tard**. [Stockage.md](Stockage.md#état-actuel).

`local-path` n'est **pas** un stockage distribué. Si le nœud disparaît, le volume n'est pas disponible ailleurs. Les sauvegardes restent essentielles.

Un PVC **ne se déplace pas** d'un namespace à un autre : nouveau PVC + restauration.

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

Géré par l'Application `vaultwarden` : path `kubernetes/vaultwarden`, destination `vaultwarden`, `targetRevision: HEAD`. État constaté : **Synced** / **Healthy** (révision `8322150` au moment de la bascule).

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
| PVC Bound / PV local-path | OK |
| SealedSecret Synced | OK |
| Argo CD Synced / Healthy | OK |
| `https://vaultwarden.labo.example` | OK, données post-migration |
| Access devant Vaultwarden | volontairement absent |
| Sauvegarde **récurrente** du PVC | ⬜ [Sauvegardes.md](Sauvegardes.md) (un backup de migration existe sur k3s-01) |

---

# À retenir

**Kubernetes** — Un namespace isole les ressources namespacées. Un PVC ne migre pas : nouveau volume + restore. `local-path` = disque du nœud. `WaitForFirstConsumer` peut attendre un Pod avant de créer le PV.

**Réseau** — Service = identité stable ; EndpointSlice = Pods actuels. Traefik lit les Ingress. Deux Ingress / même host = piège.

**Secrets** — Secret K8s ≠ coffre pour Git. Sealed Secrets = représentation chiffrée versionnable. Reseal si namespace ou nom change.

**GitOps** — [ArgoCD.md](ArgoCD.md). Manuel = exception.

**Sauvegardes** — Stockage local K3s, SQLite : backup essentiel. Toute migration de données commence par un backup **vérifié**.
