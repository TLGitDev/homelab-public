# ADR-003 — Accès distant : Cloudflare Tunnel

## Statut

Accepté. **Révisé le 10 nov. 2026** : le tunnel ne publie plus que Vaultwarden, et WireGuard est devenu l'accès distant d'administration (voir « Révisions »).

## Contexte

Les services du homelab doivent être joignables hors du réseau local (administration de Proxmox, services à venir), sans exposer le serveur directement sur Internet.

Contraintes :

- aucun port de Proxmox ouvert sur le routeur ;
- une authentification forte ;
- un seul composant dédié à l'accès distant.

## Décision

Utiliser **Cloudflare Tunnel** pour le transport, et **Cloudflare Access** pour l'identité (une adresse de courriel autorisée, plus un second facteur TOTP).

Le démon `cloudflared` tourne dans un LXC Debian dédié : `cloudflare`, CT 100, `<ip-cloudflare>`. Rien n'est installé sur l'hyperviseur lui-même.

## Raisons

- La connexion est **sortante** : c'est le serveur qui ouvre le tunnel.
- Aucune redirection de port.
- Access applique un refus par défaut.
- Le trafic est chiffré jusqu'à Cloudflare.
- Les responsabilités sont séparées : un LXC, un rôle.

## Alternatives étudiées

| Option | Pourquoi elle n'est pas retenue (à l'époque) |
| --- | --- |
| Redirection de ports | Expose directement Proxmox sur Internet |
| VPN WireGuard ou Tailscale | Valable, mais n'enseigne pas le modèle reverse proxy + identité en bordure. Pouvait revenir plus tard pour l'administration |
| HTTPS exposé directement (Let's Encrypt) | Exige un port 443 ouvert et la gestion des certificats sur le LAN |

## Conséquences

- L'accès distant dépend de la disponibilité de Cloudflare.
- Deux authentifications indépendantes : Access décide qui peut entrer, puis l'application décide quel utilisateur est connecté.
- Les routes du tunnel pointent vers les adresses internes réelles (par exemple `<ip-pve>:8006` pour Proxmox, et non `.10`).
- Le jeton du tunnel et la politique Access ne sont pas versionnés.

## Révisions

**9 et 10 nov. 2026 — WireGuard pour l'administration.** Une passerelle WireGuard (CT 115, `<ip-wireguard>`) est en service depuis le 9 nov. : elle permet au téléphone de joindre tout le LAN. La seule ouverture sur la box est une règle IPv6, UDP 51820, vers ce conteneur. Le 10 nov., **toutes les routes du tunnel ont été désactivées, sauf Vaultwarden** : Proxmox, Argo CD, Gitea, les cinq interfaces *arr et Navidrome se joignent désormais par le LAN ou par WireGuard.

C'est l'alternative que cet ADR avait laissée ouverte (« peut revenir plus tard pour l'administration »). Le résultat combine les deux modèles :
- **Cloudflare Tunnel** pour le seul service qui doit rester public ;
- **WireGuard** pour l'administration.

La surface exposée sur Internet se réduit à un nom de domaine. Cloudflare Access n'est plus utilisé par aucune route, mais reste la règle si un outil d'administration devait être republié.

Exploitation : [cloudflare.md](../exploitation/cloudflare.md). Adresses : [adressage.md](../vue-ensemble/adressage.md).
