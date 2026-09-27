# Vaultwarden

> Premier service applicatif sur K3s. Manifestes : [kubernetes/vaultwarden/](../kubernetes/vaultwarden/).
>
> Cours Kubernetes : [Kubernetes.md](Kubernetes.md). Tunnel : [Cloudflare.md](Cloudflare.md). IP : [Proxmox.md](Proxmox.md).

---

# Objectif

Déployer Vaultwarden (serveur compatible Bitwarden) sur le cluster K3s et le rendre accessible en :

`https://vaultwarden.labo.example`

L'application utilise : SQLite, un PVC pour `/data`, Traefik comme Ingress Controller, le tunnel Cloudflare existant (`homelab`). **Aucun port entrant** sur la box.

---

# Architecture

Deux niveaux de routage : Cloudflare (Internet → LAN), puis Kubernetes (hostname → Service → Pod).

```
                         INTERNET
                            │
                            │ HTTPS
                            ▼
                       Cloudflare
                            │
                     Tunnel "homelab"
                            │
                            ▼
                    CT cloudflared
                            │
                            │ HTTP
                            ▼
                    <ip-k3s-01>:80
                            │
                            ▼
                         Traefik
                            │
                     Ingress Kubernetes
                            │
              Host: vaultwarden.labo.example
                            │
                            ▼
                 vaultwarden-service:80
                            │
                            ▼
                  Vaultwarden Pod :80
                            │
                            ▼
                       /data
                            │
                            ▼
                     SQLite
```

## Routage Cloudflare

Cloudflare reçoit `vaultwarden.labo.example` et l'envoie dans le tunnel `homelab`. Le `cloudflared` du LXC transmet vers `http://<ip-k3s-01>:80` (Traefik sur K3s).

## Routage Kubernetes

Traefik reçoit le hostname `vaultwarden.labo.example`. L'Ingress l'associe à `vaultwarden-service:80`. Le Service sélectionne le Pod via `app: vaultwarden`.

---

# Pourquoi Cloudflare Tunnel

Le tunnel rend le service joignable depuis Internet **sans** ouvrir de ports sur la box. Le serveur établit une connexion **sortante**. Détail : [Cloudflare.md](Cloudflare.md).

Le même tunnel `homelab` sert plusieurs applications. Un CT `cloudflared` par service n'est pas nécessaire.

```
proxmox.labo.example
        ↓
Tunnel homelab
        ↓
Proxmox (HTTPS)

vaultwarden.labo.example
        ↓
Tunnel homelab
        ↓
Traefik (HTTP :80)
        ↓
Vaultwarden
```

## Pourquoi Traefik, pas le Pod

Cloudflare ne connaît que `vaultwarden.labo.example` → `<ip-k3s-01>:80`. Kubernetes prend ensuite le relais (Ingress → Service → Pod).

Le tunnel reste le point d'entrée réseau. Traefik devient le routeur HTTP du cluster. Les prochains services (Grafana, etc.) suivent le même schéma.

---

# TLS

Le HTTPS **public** est géré par Cloudflare (certificat valide, cadenas dans le navigateur).

Entre le tunnel et Traefik : **HTTP** (`http://<ip-k3s-01>:80`). Aucun certificat à configurer dans l'Ingress.

Différent de Proxmox : l'origin Cloudflare y est déjà en HTTPS (`https://<ip-pve>:8006`).

```
Client ──HTTPS──► Cloudflare ──Tunnel / HTTP──► Traefik :80
```

---

# Manifestes

```
kubernetes/vaultwarden/
├── configmap.yaml
├── deployment.yaml
├── pvc.yaml
├── secret.yaml
├── service.yaml
└── ingress.yaml
```

Un fichier = une responsabilité.

---

# ConfigMap

Fichier : `kubernetes/vaultwarden/configmap.yaml`. Configuration **non sensible**.

| Clé | Valeur | Rôle |
|-----|--------|------|
| `DOMAIN` | `https://vaultwarden.labo.example` | URL publique. Doit correspondre à l'adresse réelle des clients. |
| `DATABASE_URL` | `sqlite://data/db.sqlite3` | SQLite sous `/data` (monté depuis le PVC). |
| `SIGNUPS_ALLOWED` | `"false"` | Inscriptions désactivées. |

---

# Deployment

Fichier : `kubernetes/vaultwarden/deployment.yaml`.

Image `vaultwarden/server:1.37.3`, `replicas: 1`. Crée un ReplicaSet, qui maintient le Pod. Le conteneur écoute sur `80/TCP` et monte `/data` depuis `vaultwarden-pvc`.

Variables : `DOMAIN`, `DATABASE_URL`, `SIGNUPS_ALLOWED` depuis `vaultwarden-config` ; `ADMIN_TOKEN` depuis `vaultwarden-secret`.

---

# Stockage

Fichier : `kubernetes/vaultwarden/pvc.yaml`.

Le Pod est éphémère. Les données Vaultwarden sont dans `/data`, monté depuis `vaultwarden-pvc` (5 Gi, `ReadWriteOnce`, StorageClass `local-path`).

```
Pod
 │ mount /data
 ▼
PVC vaultwarden-pvc
 │
 ▼
StorageClass local-path
 │
 ▼
disque du nœud K3s
```

SQLite et pièces jointes partagent le même cycle de vie → un seul PVC. Détail : [Kubernetes.md](Kubernetes.md#cycle-de-vie-des-données).

## Pourquoi SQLite

Suffisant pour cette installation. Évite un PostgreSQL dédié.

```
1 Pod · 1 PVC · 1 base SQLite
```

---

# Secret

Fichier : `kubernetes/vaultwarden/secret.yaml`. Contient `ADMIN_TOKEN` (interface d'administration).

Un Secret Kubernetes n'est pas un coffre-fort (Base64, pas de chiffrement). Une valeur en `stringData` est en clair dans le YAML. Le fichier actuel est encore une **valeur de démonstration**.

À faire : remplacer cette méthode (SOPS, Sealed Secrets, External Secrets…). Politique : [Architecture.md](Architecture.md#secrets).

---

# Service

Fichier : `kubernetes/vaultwarden/service.yaml`. ClusterIP : `vaultwarden-service:80`, `targetPort: http`, selector `app: vaultwarden`.

Adresse stable à l'intérieur du cluster. **Pas** exposé directement sur Internet.

```
Ingress → vaultwarden-service:80 → selector app=vaultwarden → Pod
```

## EndpointSlice

Kubernetes tient à jour les endpoints du Service. Exemple constaté : `vaultwarden-service:80` → `10.42.0.16:80` (IP du Pod, **change** si le Pod est recréé). On parle toujours au Service, jamais à cette IP.

---

# Ingress

Fichier : `kubernetes/vaultwarden/ingress.yaml`.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vaultwarden-ingress
spec:
  ingressClassName: traefik
  rules:
    - host: vaultwarden.labo.example
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vaultwarden-service
                port:
                  number: 80
```

| Champ | Valeur | Rôle |
|-------|--------|------|
| `ingressClassName` | `traefik` | Traefik prend en charge cette règle. |
| `host` | `vaultwarden.labo.example` | Site concerné. |
| `path` / `pathType` | `/` · `Prefix` | `/` et tout ce qui est en dessous (`/admin`, `/api/…`, `/attachments/…`). |
| Backend | `vaultwarden-service:80` | L'Ingress pointe vers le **Service**, pas le Pod. |

Cours générique : [Kubernetes.md](Kubernetes.md#ingress).

---

# Cloudflare (route)

Tunnel existant : `homelab`. Route ajoutée :

| Champ | Valeur |
|-------|--------|
| Hostname | `vaultwarden.labo.example` |
| Service | `http://<ip-k3s-01>:80` |

Cloudflare gère le DNS. Le LXC `cloudflared` est réutilisé.

---

# Vérifications

| Contrôle | Résultat |
|----------|----------|
| `kubectl apply --dry-run=client -f kubernetes/vaultwarden/` | OK |
| `kubectl apply -f kubernetes/vaultwarden/` | appliqué |
| Pod | Running, 1/1, pas de restart anormal |
| PVC `vaultwarden-pvc` | Bound, 5 Gi |
| Service | endpoint = Pod |
| `curl` → `vaultwarden-service` | HTML Vaultwarden (Service → EndpointSlice → Pod) |
| `curl -H "Host: vaultwarden.labo.example" http://<ip-k3s-01>/` | HTML Vaultwarden (Traefik → Ingress → Service) |
| Navigateur `https://vaultwarden.labo.example` | HTTPS valide, cadenas |

Chaîne Internet validée : Cloudflare → tunnel `homelab` → cloudflared → `<ip-k3s-01>:80` → Traefik → Ingress → Service → Pod.

---

# État

| Élément | État |
|---------|------|
| K3s | OK |
| Deployment / Pod | OK |
| ConfigMap | OK |
| PVC / SQLite | Bound / OK |
| Service / EndpointSlice | OK |
| Traefik / Ingress | OK |
| Tunnel / DNS / HTTPS public | OK |

À faire :

- [ ] Gestion sécurisée de `ADMIN_TOKEN`
- [ ] Revoir les règles Git sur les secrets
- [ ] Stratégie de sauvegarde du PVC ([Sauvegardes.md](Sauvegardes.md))

---

# Flux à retenir

Pour les prochains services :

```
Cloudflare Tunnel     accès réseau, sans port entrant
        │
        ▼
Traefik               Ingress Controller / routeur HTTP
        │
        ▼
Ingress               règles Host / path
        │
        ▼
Service               adresse stable
        │
        ▼
EndpointSlice         liste des Pods joignables
        │
        ▼
Pod                   exécute le conteneur
```

| Composant | Responsabilité |
|-----------|----------------|
| Cloudflare Tunnel | Faire entrer le trafic Internet sans port entrant |
| cloudflared | Connexion sortante du LAN vers Cloudflare |
| Traefik | Ingress Controller |
| Ingress | Déclarer les règles de routage |
| Service | Adresse stable |
| EndpointSlice | Endpoints à jour |
| Deployment | Maintenir les Pods |
| Pod | Exécuter le conteneur |
| PVC | Stockage persistant |
| ConfigMap | Configuration non sensible |
| Secret | Données sensibles |
