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

Exemple :

```
proxmox.labo.example
        ↓
https://<ip-pve>:8006
```

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

Autoriser uniquement : `personne@labo.example`

Sinon : refuser (refus par défaut).

Authentification : One-Time PIN (par défaut).

MFA : application TOTP (KeePassXC).

## Deux authentifications indépendantes

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
