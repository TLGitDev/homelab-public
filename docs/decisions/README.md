# Décisions d'architecture (ADR)

Chaque ADR (*Architecture Decision Record*) consigne une décision : son contexte, la décision elle-même, ses raisons, les alternatives écartées et ses conséquences. Quand la réalité change, l'ADR n'est pas réécrit : on lui ajoute une section **Révisions**.

| ADR | Décision | Statut |
| --- | --- | --- |
| [ADR-001](ADR-001-Proxmox.md) | Hyperviseur : Proxmox VE | Appliqué |
| [ADR-002](ADR-002-ZFS.md) | Stockage : ZFS (`rpool` sur NVMe, `tank` en miroir) | Appliqué le 2 sept. 2026 |
| [ADR-003](ADR-003-Cloudflare-Tunnel.md) | Accès distant : Cloudflare Tunnel | Révisé le 10 nov. 2026 : seul Vaultwarden reste publié, WireGuard pour l'administration |
| [ADR-004](ADR-004-K3s.md) | Plateforme : K3s à un nœud | Appliqué |
| [ADR-005](ADR-005-Sealed-Secrets.md) | Secrets dans Git : Sealed Secrets | Appliqué |
| [ADR-006](ADR-006-Argo-CD.md) | GitOps : Argo CD, modèle App of Apps | Appliqué, complété le 4 nov. 2026 |
| [ADR-007](ADR-007-Argo-CD-exposition.md) | Exposition et configuration d'Argo CD | Révisé le 10 nov. 2026 : plus de route publique |
| [ADR-008](ADR-008-Vaultwarden-tank.md) | Vaultwarden : zvol sur `tank` et Local PV | Appliqué le 14 oct. 2026 |
| [ADR-009](ADR-009-Alerte-ntfy.md) | Alerte : ntfy | Appliqué le 5 nov. 2026, validé en conditions réelles |
| [ADR-010](ADR-010-Ansible-LXC.md) | LXC d'infrastructure : Ansible | Appliqué les 7, 8 et 9 nov. 2026 |
| [ADR-011](ADR-011-Gitea.md) | Forge Git : Gitea | Appliqué le 3 nov. 2026 |
| [ADR-012](ADR-012-LXC-ou-K3s.md) | Où héberger un service : LXC ou K3s | Accepté le 11 nov. 2026, formalise les choix du 28 oct. au 4 nov. |
| [ADR-014](ADR-014-Noms-HTTPS-LAN.md) | Noms et HTTPS sur le LAN : joker public, Traefik sur un LXC dédié | Appliqué le 12 nov. 2026 |
| ADR-013 *(à écrire)* | Isolement des applications maison exposées sur Internet | À rédiger avant la première application publique |

## Le critère d'hébergement

Jusqu'au 11 nov. 2026, les choix d'hébergement de Jellyfin, qBittorrent, des *arr et de Navidrome étaient faits service par service, chacun justifié dans sa propre doc, avec la mention « critère général encore ouvert ». L'[ADR-012](ADR-012-LXC-ou-K3s.md) formalise ce critère : **un service qui doit lire ou écrire un dataset de fichiers sur `tank` va en LXC ; un service dont les données tiennent dans un volume dédié va dans K3s.**
