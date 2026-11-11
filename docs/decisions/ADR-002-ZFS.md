# ADR-002 — Stockage : ZFS

## Statut

Accepté. Appliqué le 2 sept. 2026 par la réinstallation de Proxmox sur ZFS. Pool `tank` créé le 7 sept. 2026.

## Contexte

Le homelab a besoin d'un stockage :

- **fiable**, qui détecte les corruptions ;
- **compréhensible**, puisque le projet est pédagogique ;
- **évolutif**, avec un NVMe pour le système et des disques durs pour les données.

La première installation de Proxmox utilisait ext4 + LVM-Thin, la configuration par défaut de l'installateur. Un audit a montré que ce n'était pas l'architecture visée. La réinstallation a eu lieu le 2 sept. 2026, avant d'héberger la moindre donnée critique.

## Décision

Utiliser **ZFS** comme stockage principal, avec deux pools :

| Pool | Support | Rôle |
| --- | --- | --- |
| `rpool` | SSD NVMe 2 To | Système, VM et LXC |
| `tank` | VDEV miroir sur les deux IronWolf Pro 8 To | Données |

## Raisons

- Des checksums qui détectent les corruptions silencieuses.
- L'autoréparation (*self-healing*) sur un VDEV miroir.
- Des snapshots natifs.
- Des datasets aux propriétés indépendantes.
- Une seule technologie à apprendre, au lieu d'empiler RAID, LVM et système de fichiers.
- C'est cohérent avec l'objectif pédagogique du projet.

## Alternatives étudiées

| Option | Pourquoi elle n'est pas retenue |
| --- | --- |
| ext4 + LVM-Thin | Configuration par défaut, mais sans checksums ni autoréparation |
| Btrfs | Moins répandu sur Proxmox, écosystème plus fragile pour ce cas |
| RAID matériel | La carte mère n'offre pas de vrai RAID serveur, et ZFS a besoin de voir les disques directement |

## Conséquences

- Proxmox a été réinstallé sur ZFS. L'ancienne installation ext4 / LVM n'existe plus.
- `rpool` porte l'infrastructure : Proxmox et les disques **système** des VM et des conteneurs. Le disque système de `k3s-01` est `rpool/data/vm-101-disk-1` (64 Go).
- `tank` porte les données persistantes. Le dataset `tank/vmdata` est déclaré dans Proxmox comme stockage `zfspool: tank-vmdata` (`content images`, `sparse 1`), réservé aux volumes bloc gérés par Proxmox.
- Vaultwarden est sur `tank` depuis le 14 oct. 2026 (voir l'[ADR-008](ADR-008-Vaultwarden-tank.md)).
- Un miroir n'est pas une sauvegarde : une copie indépendante reste nécessaire (voir [sauvegardes.md](../exploitation/sauvegardes.md)).
- On n'identifie jamais un disque par son nom Linux (`/dev/sda`, `/dev/sdb`), mais par son numéro de série (voir [materiel.md](../vue-ensemble/materiel.md)).
- `rpool` n'a pas de redondance : la perte du NVMe emporte tout le système (voir [restauration.md](../exploitation/restauration.md), scénario 7).

Exploitation : [stockage-zfs.md](../exploitation/stockage-zfs.md). Notions : [zfs.md](../concepts/zfs.md).
