# Vaultwarden

> Premier service applicatif sur K3s. Manifestes : [kubernetes/vaultwarden/](../kubernetes/vaultwarden/).
>
> Cours Kubernetes : [Kubernetes.md](Kubernetes.md). Tunnel : [Cloudflare.md](Cloudflare.md). IP : [Proxmox.md](Proxmox.md).

---

# Objectif

Déployer Vaultwarden sur K3s avec : un seul Pod, SQLite, un PVC, Traefik, le tunnel Cloudflare `homelab`.

Cloudflare Access reste sur **Proxmox**. Il n'est **pas** devant Vaultwarden (l'application a déjà son authentification).

`ADMIN_TOKEN` est protégé dans Git par **SOPS + age**. La valeur réelle n'est ni dans cette doc, ni dans une conversation.

URL publique : `https://vaultwarden.labo.example`. Aucun port entrant sur la box.

---

# Architecture

```
INTERNET
    │ HTTPS
    ▼
Cloudflare
    │
    ▼
Tunnel "homelab"
    │
    ▼
CT cloudflared
    │ HTTP
    ▼
<ip-k3s-01>:80
    │
    ▼
Traefik (K3s)
    │
    ▼
Ingress vaultwarden-ingress
    │
    ▼
Service vaultwarden-service
    │
    ▼
Pod Vaultwarden
    │
    ▼
/data → PVC vaultwarden-pvc
```

Deux routages : Cloudflare (Internet → Traefik), puis Kubernetes (Host → Service → Pod).

## HTTPS

Cloudflare termine le HTTPS public (`https://vaultwarden.labo.example`). Le tunnel envoie ensuite **HTTP** vers `http://<ip-k3s-01>:80`. Traefik lit le `Host` pour choisir l'Ingress. Aucun certificat TLS dans l'Ingress.

Différent de Proxmox : origin déjà en HTTPS (`https://<ip-pve>:8006`).

---

# Cloudflare Tunnel

Le tunnel `homelab` (CT `cloudflared`) est réutilisé. Pas un tunnel ni un CT par application.

| Champ | Valeur |
|-------|--------|
| Hostname | `vaultwarden.labo.example` |
| Service | `http://<ip-k3s-01>:80` |
| Path | aucun (tout le hostname) |

Le tunnel envoie vers **Traefik**, pas vers le Pod. Traefik est le point d'entrée HTTP de K3s : il applique les Ingress selon le hostname.

```
Cloudflare → Traefik → Ingress → Service → Pod
```

Détail du tunnel : [Cloudflare.md](Cloudflare.md).

---

# Manifestes

```
kubernetes/vaultwarden/
├── configmap.yaml
├── deployment.yaml
├── pvc.yaml
├── secret.yaml          # chiffré SOPS dans Git
├── service.yaml
└── ingress.yaml
```

---

# ConfigMap

Fichier : `kubernetes/vaultwarden/configmap.yaml`. Paramètres **non sensibles**.

| Clé | Valeur | Rôle |
|-----|--------|------|
| `DOMAIN` | `https://vaultwarden.labo.example` | URL publique |
| `DATABASE_URL` | `sqlite://data/db.sqlite3` | SQLite sous `/data` (volume du PVC) |
| `SIGNUPS_ALLOWED` | `"false"` | Inscriptions publiques désactivées |

---

# Deployment

Fichier : `kubernetes/vaultwarden/deployment.yaml`. État désiré : image `vaultwarden/server:1.37.3`, `replicas: 1`, port 80, `/data` depuis `vaultwarden-pvc`.

## ReplicaSet

```
Deployment → ReplicaSet → Pod → conteneur Vaultwarden
```

Le Deployment ne crée pas les Pods. Le ReplicaSet maintient le nombre. Réconciliation : comparer état désiré et état réel, corriger. Avec `replicas: 1`, un Pod correspondant au sélecteur est toujours maintenu.

## Conteneur

`containerPort: 80` **décrit** le port. Il n'expose pas vers l'extérieur. L'exposition : Service, puis Ingress.

## Variables d'environnement

Depuis le ConfigMap : `DOMAIN`, `DATABASE_URL`, `SIGNUPS_ALLOWED`.

`ADMIN_TOKEN` vient du Secret, pas du Deployment :

```yaml
valueFrom:
  secretKeyRef:
    name: vaultwarden-secret
    key: ADMIN_TOKEN
```

Une variable d'environnement n'est **pas** relue si le Secret change. Il faut recréer le Pod :

```
kubectl rollout restart deployment vaultwarden
kubectl rollout status deployment vaultwarden
```

---

# Secret Kubernetes vs Git

Fichier versionné : `kubernetes/vaultwarden/secret.yaml`. Dans Git : uniquement des `ENC[...]` (SOPS + age). Jamais le vrai token en clair.

Structure logique (déchiffrée, **jamais** commitée telle quelle) :

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: vaultwarden-secret
stringData:
  ADMIN_TOKEN: <secret>
```

Le token a été généré aléatoirement. Il n'apparaît ni ici, ni dans un manifeste non chiffré.

## Deux niveaux

| Où | Protection |
|----|------------|
| Git / GitHub | Fichier chiffré SOPS. Pas le token en clair. |
| Cluster | Après `sops --decrypt \| kubectl apply`, Kubernetes a un `Secret/vaultwarden-secret` **en clair** dans son datastore. |

SOPS protège le secret **au repos dans Git**. Il ne remplace pas la sécurité du cluster. `kubectl get secret … -o yaml` révèle les données : ne pas le faire sans raison.

---

# SOPS + age

SOPS chiffre des fichiers tout en les laissant versionnables. age fournit le chiffrement.

```
secret.yaml en clair → SOPS + age → secret.yaml chiffré → Git
```

Kubernetes ne lit pas SOPS. Déploiement sans fichier clair permanent :

```
sops --decrypt kubernetes/vaultwarden/secret.yaml | kubectl apply -f -
```

(`-` = stdin.)

## Clés

| Élément | Où | Git ? |
|---------|-----|-------|
| Clé publique | `.sops.yaml` | oui |
| Clé privée | hors dépôt | **jamais** |
| `secret.yaml` | chiffré | oui |

Clé publique : `age1utrl26vp9t06k453kgf2vkplrpz9jzr7rww7n6la705ucgyvtv4qj9f9va`

La même paire sert le PC Windows et `k3s-01` :

| Machine | Clé privée |
|---------|------------|
| Windows | `C:\Users\utilisateur\.config\sops\age\keys.txt` |
| k3s-01 | `/home/utilisateur/.config/sops/age/keys.txt` |

Ne pas mettre `keys.txt` dans `Homelab/`, même avec `.gitignore`. `.gitignore` n'est pas une protection cryptographique.

Sauvegarder la clé privée **hors dépôt**, dans un endroit sûr. Perdue sans autre destinataire SOPS → fichiers irrécupérables.

## `.sops.yaml`

```yaml
creation_rules:
  - path_regex: 'kubernetes[\\/]+vaultwarden[\\/]+secret\.yaml$'
    age: age1utrl26vp9t06k453kgf2vkplrpz9jzr7rww7n6la705ucgyvtv4qj9f9va
```

Le regex accepte `/` et `\` (Windows et Linux). Le fichier est versionné.

## Outils

| Machine | SOPS | age | Variable |
|---------|------|-----|----------|
| PC | 3.13.3 | 1.3.1 | `$env:SOPS_AGE_KEY_FILE = "$HOME\.config\sops\age\keys.txt"` |
| k3s-01 | 3.13.3 | 1.2.1 | `export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"` |

Édition sur le PC : `$env:SOPS_EDITOR = "notepad.exe"` (session PowerShell).

## Modifier le secret

Ne pas déchiffrer « pour de bon » puis recommiter. Éditer via SOPS :

```
sops ./kubernetes/vaultwarden/secret.yaml
```

SOPS déchiffre temporairement, ouvre l'éditeur, rechiffre à la fermeture. Vérifier avec `git diff` que le fichier reste en `ENC[...]`.

---

# Workflow

```
PC → sops (édition) → commit chiffré → GitHub → git pull sur k3s-01
     → sops --decrypt | kubectl apply -f -
     → kubectl rollout restart deployment vaultwarden   # si ADMIN_TOKEN a changé
     → kubectl rollout status deployment vaultwarden
     → kubectl get pods -l app=vaultwarden
```

Exemple de commit (sans afficher le secret) : `git add .sops.yaml kubernetes/vaultwarden/secret.yaml`.

---

# Stockage

SQLite dans `/data/db.sqlite3`. PVC `vaultwarden-pvc` : 5 Gi, `ReadWriteOnce`, StorageClass `local-path` (`rancher.io/local-path`, `WaitForFirstConsumer`).

```
PVC → StorageClass → PV → disque du nœud → montage /data
```

Un seul PVC : SQLite et fichiers de `/data` ont le même cycle de vie. Recréer le **Pod** conserve les données. Supprimer le **PVC** risque de tout perdre.

---

# Service et Ingress

Service `vaultwarden-service` : port 80, `targetPort: http`, selector `app: vaultwarden`. ClusterIP, pas exposé sur Internet. L'IP du Pod change ; le Service et les EndpointSlices restent le point d'entrée interne.

Ingress `vaultwarden-ingress` : `ingressClassName: traefik`, host `vaultwarden.labo.example`, path `/` `Prefix` → `vaultwarden-service:80`.

Traefik **applique** la règle. L'Ingress **décrit** la règle. Le Service **stabilise** l'adresse. L'EndpointSlice **liste** les Pods. Le Pod **exécute** Vaultwarden.

Cours : [Kubernetes.md](Kubernetes.md#ingress).

---

# Cloudflare Access

Proxmox : Access + MFA, puis auth Proxmox. [Cloudflare.md](Cloudflare.md).

Vaultwarden : **pas** d'Access. Une couche Cloudflare devant une appli qui authentifie déjà ses clients serait redondante et gênante pour les clients Bitwarden.

```
Proxmox :      Internet → Access → Tunnel → Proxmox
Vaultwarden :  Internet → HTTPS Cloudflare → Tunnel → Traefik → auth Vaultwarden
```

---

# Vérifications

| Contrôle | Résultat |
|----------|----------|
| Pod | Running, 1/1 |
| PVC `vaultwarden-pvc` | Bound, 5 Gi |
| Service | 80/TCP, endpoint = Pod |
| `curl` → `http://vaultwarden-service` | HTML Vaultwarden |
| `Host: vaultwarden.labo.example` → `<ip-k3s-01>:80` | HTML Vaultwarden |
| `https://vaultwarden.labo.example` | HTTPS valide |
| Recréation du Pod (PVC conservé) | données conservées |

---

# Règles

1. Jamais de clé privée age dans Git (ni dans `Homelab/`, même ignorée).
2. Jamais `ADMIN_TOKEN` en clair dans Git, la doc ou une conversation.
3. Ne pas publier `keys.txt`.
4. Ne pas coller un Secret déchiffré.
5. Éviter `kubectl get secret … -o yaml` sans besoin.
6. `secret.yaml` reste chiffré dans Git.
7. Sauvegarder la clé privée, de façon protégée.
8. Ne pas supprimer le PVC à la légère.
9. Après changement de `ADMIN_TOKEN` : `rollout restart`.

---

# État

| Élément | État |
|---------|------|
| K3s / Traefik / Ingress | OK |
| Deployment / Pod / Service | OK |
| PVC / SQLite / persistance | OK |
| Tunnel / HTTPS public | OK |
| SOPS + age (`ADMIN_TOKEN` dans Git) | OK |
| Cloudflare Access devant Vaultwarden | volontairement absent |
| Sauvegarde du PVC | ⬜ [Sauvegardes.md](Sauvegardes.md) |
