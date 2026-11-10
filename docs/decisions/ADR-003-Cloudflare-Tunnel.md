# ADR-003 — Choix du Cloudflare Tunnel

## Statut

Accepté

## Contexte

Les services du homelab doivent être joignables hors du réseau local (administration Proxmox, services futurs) sans exposer le serveur directement sur Internet.

Contraintes :

- aucun port Proxmox ouvert sur le routeur ;
- authentification forte ;
- un seul composant dédié à l'accès distant.

## Décision

Utiliser **Cloudflare Tunnel** pour le transport, et **Cloudflare Access** (email autorisé + MFA TOTP) pour l'identité.

Le démon `cloudflared` tourne dans un LXC Debian dédié (`cloudflare`, CT 100, `<ip-cloudflare>`). Détail opérationnel : [Cloudflare.md](../Cloudflare.md).

Aucun service n'est installé sur l'hyperviseur lui-même.

## Raisons

- Connexion **sortante** uniquement : le serveur initie le tunnel.
- Aucune redirection de port.
- Intégration Access (politique « refus par défaut »).
- Chiffrement jusqu'à Cloudflare.
- Séparation des responsabilités : un LXC = un rôle.

## Alternatives étudiées

| Option | Pourquoi écartée (pour l'instant) |
|--------|-----------------------------------|
| Redirection de ports | Surface d'attaque directe sur Proxmox. |
| VPN WireGuard / Tailscale | Valable, mais n'enseigne pas le modèle reverse-proxy + identité en bordure. Peut revenir plus tard pour l'administration. |
| Exposition HTTPS directe (Let's Encrypt) | Exige un port 443 ouvert et une gestion de certificats sur le LAN. |

## Conséquences

- L'accès distant dépend de Cloudflare (disponibilité tierce).
- Deux authentifications indépendantes : Access (qui peut entrer) puis Proxmox (quel utilisateur local).
- Les routes du tunnel pointent vers les IP internes réelles (`<ip-pve>:8006` pour Proxmox, pas `.10`).
- Les secrets (jeton de tunnel, politique Access) ne sont pas versionnés dans ce dépôt.
