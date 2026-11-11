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

## Décisions prises sans ADR

Certaines décisions d'hébergement ont été tranchées service par service, sans ADR, parce que le critère général (VM, LXC ou K3s selon le service) reste ouvert. Elles sont justifiées dans la doc de chaque service :

- Jellyfin en LXC ([jellyfin.md](../exploitation/mediatheques/jellyfin.md)) ;
- qBittorrent derrière un VPN, en LXC ([qbittorrent-vpn.md](../exploitation/mediatheques/qbittorrent-vpn.md)) ;
- les outils *arr dans un LXC commun ([servarr.md](../exploitation/mediatheques/servarr.md)) ;
- Navidrome en LXC, et préféré à Jellyfin pour la musique ([navidrome.md](../exploitation/mediatheques/navidrome.md)).

Formaliser ce critère général dans un ADR serait une suite logique.
