# ADR-002 — Choix de ZFS

## Statut

Accepté

## Contexte

Le homelab a besoin d'un stockage :

- fiable (détection des corruptions) ;
- compréhensible (objectif pédagogique) ;
- capable d'évoluer (NVMe système + HDD données).

La première installation de Proxmox a utilisé ext4 + LVM-Thin, configuration par défaut de l'installateur. Un audit a montré que ce n'était pas l'architecture visée.

La réinstallation a été faite le 2026-09-02, avant toute donnée critique.

## Décision

Utiliser ZFS comme stockage principal.

- **Système, VM et LXC** : pool `rpool` sur le SSD NVMe 2 To.
- **Données** : pool `tank`, VDEV miroir sur les deux IronWolf Pro 8 To.

## Raisons

- Checksums et détection des corruptions silencieuses.
- Self-healing sur un VDEV miroir.
- Snapshots natifs.
- Datasets avec propriétés indépendantes.
- Une seule technologie à apprendre au lieu de RAID + LVM + système de fichiers.
- Aligné avec l'objectif pédagogique du projet.

## Alternatives étudiées

| Option | Pourquoi écartée |
|--------|------------------|
| ext4 + LVM-Thin | Défaut de l'installateur. Pas de checksums, pas de self-healing. |
| Btrfs | Moins répandu sur Proxmox, écosystème plus fragile pour ce cas. |
| RAID matériel | La carte mère n'offre pas un RAID serveur ; ZFS doit voir les disques. |

## Conséquences

- Proxmox a été réinstallé sur ZFS. L'ancienne installation ext4/LVM n'existe plus.
- `rpool` et `tank` sont décrits dans [Stockage.md](../Stockage.md).
- `tank` existe ; aucun dataset de service n'y est créé tant qu'un besoin réel n'apparaît pas.
- Un miroir n'est pas une sauvegarde : une copie indépendante reste nécessaire ([Sauvegardes.md](../Sauvegardes.md)).
- Les identifiants Linux (`/dev/sda`, `/dev/sdb`) ne doivent pas servir à identifier les disques : utiliser les numéros de série (voir [Materiel.md](../Materiel.md)).
