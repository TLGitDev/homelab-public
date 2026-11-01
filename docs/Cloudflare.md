# Cloudflare

> Accès distant du homelab : Tunnel, Access, MFA.
>
> Décision : [ADR-003](ADR/ADR-003-Cloudflare-Tunnel.md). Principes généraux : [Architecture.md](Architecture.md). IP : [Proxmox.md](Proxmox.md).

---

# Objectif

Permettre un accès distant sécurisé sans ouvrir de ports sur le routeur.

Limiter la surface d'attaque tout en restant joignable depuis Internet.

---

# Architecture

```
Utilisateur
    │
    ▼
Cloudflare DNS
    │
    ▼
Cloudflare Access
    │
    ▼
Cloudflare Tunnel (connexion chiffrée, sortante)
    │
    ▼
LXC cloudflare (CT 100)
    │
    ▼
Service interne
```

Le serveur établit une connexion **sortante** permanente vers Cloudflare. Aucune connexion entrante n'est nécessaire sur le routeur. Aucune redirection de port.

Le tunnel ne rend aucun service accessible par lui-même. Il transporte les requêtes jusqu'au LAN. Les services publiés sont définis par des **routes**.

Le tunnel `homelab` sert **plusieurs** routes. Un CT `cloudflared` par application n'est pas nécessaire.

```
proxmox.labo.example
        ↓
https://<ip-pve>:8006

vaultwarden.labo.example
        ↓
http://<ip-k3s-01>:80   (Traefik, **sans** Access)

argocd.labo.example
        ↓
http://<ip-k3s-01>:80   (Traefik, **avec** Access)
```

Proxmox : origin **HTTPS**. Vaultwarden et Argo CD : origin **HTTP** ; le HTTPS public est celui de Cloudflare. Traefik distingue les services par hostname. Détail : [Vaultwarden.md](Vaultwarden.md), [ArgoCD.md](ArgoCD.md).

Avantages : aucun port ouvert sur Internet, chiffrement, intégration Access.

---

# LXC dédié

`cloudflared` tourne dans un LXC Debian dédié.

- hostname : `cloudflare`
- CT ID : `100`
- IP : `<ip-cloudflare>`

Le conteneur ne contient que ce service.

Pourquoi un LXC à part : séparation des responsabilités, isolation des ressources, maintenance et restauration indépendantes, surface d'attaque réduite. Aucun service applicatif n'est installé sur Proxmox.

Installer le paquet et configurer le tunnel sont deux étapes distinctes (voir [Architecture.md](Architecture.md)).

---

# Cloudflare Access

Access protège les applications **avant** qu'elles ne soient joignables. Le serveur n'est pas contacté tant que l'utilisateur n'est pas authentifié.

```
Utilisateur
    ↓
Cloudflare Access
    ↓
Tunnel
    ↓
Application
```

## Politique actuelle

**Proxmox** (`proxmox.labo.example`) : Access actif.

Autoriser uniquement : `personne@labo.example`

Sinon : refuser (refus par défaut).

Authentification : One-Time PIN (par défaut).

MFA : application TOTP (KeePassXC).

**Vaultwarden** : pas d'Access. L'application authentifie déjà ses clients. Détail : [Vaultwarden.md](Vaultwarden.md#cloudflare-access).

**Argo CD** (`argocd.labo.example`) : Access actif (même logique que Proxmox : outil d'admin). Puis login Argo CD. [ArgoCD.md](ArgoCD.md), [ADR-007](ADR/ADR-007-Argo-CD-exposition.md).

**Jellyfin** : pas de route. Visé après la mise en service LAN : Access, puis le tunnel vers le LXC `http://<ip-jellyfin>:8096`, pas vers Traefik. [Mediatheques.md](Mediatheques.md#jellyfin--décision-28-oct).

## Visé (1er nov., pas joué)

Choix : [Mediatheques.md](Mediatheques.md#navidrome-et-portail--choix-1er-nov). Aucune de ces routes n'existe encore.

**Interfaces *arr** : un nom par interface, tunnel `homelab`, origine le CT 105, Access devant (même courriel, OTP, TOTP que Proxmox). Le portail est une page de liens vers ces noms, elle aussi derrière Access. Il ne remplace pas Access sur chaque interface.

| Nom visé | Origine |
|----------|---------|
| `sonarr.labo.example` | `http://<ip-servarr>:8989` |
| `radarr.labo.example` | `http://<ip-servarr>:7878` |
| `prowlarr.labo.example` | `http://<ip-servarr>:9696` |
| `lidarr.labo.example` | `http://<ip-servarr>:8686` |
| `bazarr.labo.example` | `http://<ip-servarr>:6767` |

qBittorrent n'est pas dans ce pas.

**Navidrome** : comme Vaultwarden. Nom visé `navidrome.labo.example`, **sans** Access. Les applications téléphone (Tempus, Symfonium) ne passent pas une page Access. Le compte Navidrome est la serrure. L'origine dépend de l'hébergement, pas encore tranché.

## Deux authentifications indépendantes (Proxmox)

Cloudflare Access répond à : « Qui peut accéder au service ? »

Proxmox répond ensuite à : « Quel utilisateur Proxmox est connecté ? »

---

# Défense en profondeur

La sécurité de l'accès distant repose sur plusieurs couches indépendantes. Aucune ne protège seule. Chaque couche limite l'impact de la défaillance d'une autre.

```
Couche 1    Nom de domaine Cloudflare
    ↓
Couche 2    Cloudflare Access
    ↓
Couche 3    Tunnel Cloudflare
    ↓
Couche 4    HTTPS
    ↓
Couche 5    Authentification Proxmox
    ↓
Couche 6    LXC non privilégié
    ↓
Couche 7    Proxmox
```

Les secrets (jeton de tunnel, politique Access) ne sont pas versionnés dans ce dépôt.
