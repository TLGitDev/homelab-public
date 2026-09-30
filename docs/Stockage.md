# Stockage

> Cours ZFS et état du stockage du homelab.
>
> Choix : [ADR-002](ADR/ADR-002-ZFS.md). Inventaire disques : [Materiel.md](Materiel.md).
> Miroir ≠ sauvegarde : [Sauvegardes.md](Sauvegardes.md). Nœud Proxmox : [Proxmox.md](Proxmox.md).

---

# Architecture de stockage

Le stockage est séparé selon les usages.

## rpool — infrastructure

Support : NVMe 2 To (VDEV single).

Utilisation : Proxmox VE, machines virtuelles, conteneurs LXC, système.

Ce pool est dédié à l'infrastructure.

## tank — données

Support : deux HDD IronWolf Pro 8 To.

Configuration : VDEV miroir (Mirror).

Utilisation : données des services, sauvegardes, documents, médias.

Ce pool est dédié aux données.

Les identifiants Linux (`/dev/sda`, `/dev/sdb`) peuvent changer. Les numéros de série sont les identifiants permanents : [Materiel.md](Materiel.md).

---

# Hiérarchie ZFS

```
Disque physique
    ↓
VDEV
    ↓
Pool
    ↓
Dataset
    ↓
Fichiers
```

Exemple **cible** (pool de données, **pas encore créé**) :

```
sda
sdb
    ↓
Mirror
    ↓
tank
    ↓
tank/vaultwarden   ← prévu plus tard, n'existe pas
    ↓
Base SQLite
```

Exemple actuel (infrastructure) :

```
NVMe
    ↓
rpool
    ↓
subvol-100-disk-0
    ↓
Debian
    ↓
cloudflared
```

`cloudflared` n'est pas un dataset. C'est un ensemble de fichiers dans le dataset du LXC 100 (`rpool/data/subvol-100-disk-0`).

Les applications ne manipulent jamais directement les disques. Elles utilisent les datasets du pool. Le pool est le niveau d'administration principal.

---

# VDEV

Le VDEV (Virtual Device) est l'unité fondamentale de stockage dans ZFS. C'est l'unité de protection des données.

Un VDEV peut être :

- un disque (single) ;
- plusieurs disques en miroir ;
- plusieurs disques en RAIDZ.

```
1 disque  →  Single VDEV     (rpool aujourd'hui)
2 disques →  Mirror VDEV     (tank aujourd'hui)
4 disques →  RAIDZ1 VDEV
```

Un pool est constitué d'un ou plusieurs VDEV. Le pool répartit les écritures entre les VDEV. Les données ne sont **pas** dupliquées entre les VDEV : chaque donnée n'est protégée qu'à l'intérieur de son VDEV.

Si un VDEV entier est perdu, le pool devient inutilisable.

```
Pool
    ↓
Mirror
    ↓
sda
sdb
```

---

# Pool

Un pool est un espace de stockage logique, créé à partir d'un ou plusieurs VDEV. Il ne stocke pas directement les fichiers : il contient des datasets. Il agrège la capacité de tous les VDEV.

---

# Dataset

Un dataset est un système de fichiers indépendant à l'intérieur d'un pool. Ce n'est pas un simple dossier.

Propriétés possibles : compression, snapshots, quotas, points de montage, permissions.

Les datasets utilisent dynamiquement l'espace disponible du pool. Contrairement aux partitions classiques, leur taille n'est pas définie à l'avance.

Chaque dataset peut être administré indépendamment.

---

# Organisation des données

Les datasets ne sont créés que lorsqu'un besoin réel apparaît.

Critères :

- politique de snapshots différente ;
- quotas différents ;
- propriétés ZFS différentes ;
- frontière logique dans l'architecture.

En l'absence de besoin particulier, un simple répertoire est privilégié.

`tank` n'a **aucun** dataset de service. Vaultwarden tourne déjà, mais ses données ne sont **pas** sur le miroir : voir [état actuel](#état-actuel). Le dataset `tank/vaultwarden` (ou équivalent) viendra **dans un second temps**.

---

# Mirror ZFS

Le miroir fournit deux copies identiques des données.

Il assure :

- la continuité de service en cas de panne d'un disque ;
- une seconde copie pour la réparation automatique.

Le miroir n'assure pas lui-même l'intégrité. C'est ZFS qui calcule les checksums, détecte les corruptions, et utilise la seconde copie pour réparer (self-healing).

Ce n'est pas une sauvegarde : [Sauvegardes.md](Sauvegardes.md).

ZFS n'utilise pas un RAID matériel. Un ensemble de VDEV miroir ressemble à un RAID10, mais ZFS conserve une connaissance complète des disques et des données.

---

# Checksums

À chaque écriture, ZFS calcule un checksum. À la lecture, il le recalcule.

Si les deux valeurs diffèrent : corruption détectée.

Si une copie valide existe (miroir ou RAIDZ) : ZFS lit la bonne copie, la renvoie à l'application, et répare automatiquement la copie corrompue.

Sans copie saine, le checksum détecte mais ne répare pas.

---

# Scrub

Vérification complète d'un pool : relire toutes les données, vérifier les checksums, détecter les corruptions silencieuses, réparer lorsque c'est possible.

Opération préventive. Sur un homelab, généralement une fois par mois.

---

# Bonnes pratiques

Les pools sont créés une seule fois. La structure des VDEV doit être réfléchie **avant** la création.

- il est facile d'ajouter un nouveau VDEV à un pool ;
- il n'est pas possible de transformer librement un VDEV existant après sa création (passer de single à miroir, changer un RAIDZ, etc.).

Le choix d'architecture se fait donc avant toute mise en production.

---

# État actuel

```
Infrastructure (rpool, NVMe)

rpool
├── Proxmox, LXC cloudflare
└── VM k3s-01
        └── local-path
                └── données Vaultwarden   ← aujourd'hui

Données (tank, miroir IronWolf)

tank
└── (aucun dataset de service)
```

| Pool | Support | VDEV | Rôle aujourd'hui |
|------|---------|------|------------------|
| `rpool` | NVMe 2 To | single | Système, VM, LXC — **y compris le PVC Vaultwarden** (`local-path` sur k3s-01) |
| `tank` | 2× IronWolf 8 To | mirror | Prévu pour les données de service ; **vide de datasets applicatifs** |

`tank` n'héberge pas Vaultwarden. Le miroir ne protège donc pas encore le coffre. Cible : dataset sur `tank`, plus tard. Service : [Vaultwarden.md](Vaultwarden.md).

`rpool` en détail :

```
rpool
├── ROOT
│   └── pve-1                 → système Proxmox
├── data
│   └── subvol-100-disk-0     → disque du LXC 100 (cloudflare)
└── var-lib-vz                → ISO, templates, sauvegardes, imports
```

Première installation Proxmox : ext4 + LVM-Thin. Réinstallé sur ZFS le 2026-09-02 ([Journal.md](Journal.md), sprint 8). Pool `tank` créé le 2026-09-07 (sprint 9).
