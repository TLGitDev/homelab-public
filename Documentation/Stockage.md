# Stockage

> Cours ZFS et état du stockage du homelab.
>
> Choix : [ADR-002](ADR/ADR-002-ZFS.md). Inventaire disques : [Materiel.md](Materiel.md).
> Miroir ≠ sauvegarde : [Sauvegardes.md](Sauvegardes.md). Nœud Proxmox : [Proxmox.md](Proxmox.md).

---

# Objectif

Disposer d'un stockage :

- fiable ;
- performant ;
- évolutif ;
- capable de détecter et corriger les corruptions de données.

---

# Séparation physique

```
NVMe 2 To
    ↓
rpool
    ↓
Proxmox, LXC, VM, ISO
```

Deux HDD IronWolf Pro 8 To formeront plus tard un second pool, dédié aux données.

| Support | Usage |
|---------|-------|
| NVMe | système Proxmox, LXC, VM, ISO, Kubernetes (futur) |
| HDD (pool `tank`, à créer) | sauvegardes, médias, documents, données utilisateurs |

Cette séparation permet de meilleures performances pour les applications, une administration plus simple, et une évolution indépendante des deux espaces.

Les identifiants Linux (`/dev/sda`, `/dev/sdb`) peuvent changer. Les numéros de série sont les identifiants permanents des disques.

---

# Architecture classique vs ZFS

Une architecture Linux classique sépare plusieurs composants, chacun indépendant :

```
Disques
    ↓
RAID (matériel ou logiciel)
    ↓
LVM (optionnel)
    ↓
Système de fichiers (ext4, xfs…)
```

ZFS regroupe plusieurs fonctions dans une seule technologie. Le système de fichiers connaît l'organisation physique des données, ce qui lui permet de vérifier leur intégrité.

```
Disques
    ↓
VDEV
    ↓
POOL
    ↓
DATASETS
    ↓
Fichiers
```

ZFS n'est pas uniquement un système de fichiers. Il regroupe :

- la gestion des disques ;
- la redondance (Mirror, RAIDZ…) ;
- le système de fichiers ;
- les snapshots ;
- les checksums ;
- la compression.

Toutes ces fonctionnalités sont conçues pour fonctionner ensemble.

---

# VDEV

Un VDEV (Virtual Device) est un groupe de disques. C'est l'unité de protection des données.

```
1 disque  →  Single VDEV
2 disques →  Mirror VDEV
4 disques →  RAIDZ1 VDEV
```

Un pool peut contenir plusieurs VDEV. Le pool répartit les écritures entre les VDEV. Les données ne sont **pas** dupliquées entre les VDEV : chaque donnée n'est protégée qu'à l'intérieur de son VDEV.

```
Pool
├── VDEV Mirror
│     ├── HDD1
│     └── HDD2
└── VDEV Mirror
      ├── HDD3
      └── HDD4
```

Si un VDEV entier est perdu, le pool devient inutilisable. Le VDEV est donc l'unité de fiabilité de ZFS.

---

# Pools

Le pool est l'espace de stockage présenté à ZFS. Il est constitué d'un ou plusieurs VDEV. Il ne stocke pas directement les fichiers : il contient des datasets. Il agrège la capacité de tous les VDEV.

---

# Datasets

Un dataset est un système de fichiers indépendant à l'intérieur d'un pool. Ce n'est pas un simple dossier. Chaque dataset a ses propres propriétés : compression, quotas, snapshots, permissions, montage.

Exemple d'organisation future sur `tank` :

```
tank
├── media
├── photos
├── sauvegardes
└── vm
```

Chaque dataset peut être administré indépendamment.

`cloudflared` n'est pas un dataset. C'est un ensemble de fichiers à l'intérieur du dataset du conteneur (`rpool/data/subvol-100-disk-0` = système de fichiers du LXC 100).

---

# RAID et ZFS

Le RAID fait fonctionner plusieurs disques comme un seul.

- RAID1 : miroir
- RAID5 : parité
- RAID6 : double parité
- RAID10 : miroir + striping

ZFS n'utilise pas un RAID matériel. Il implémente ses propres mécanismes.

Plusieurs VDEV miroir ressemblent à un RAID10, mais ZFS conserve une connaissance complète des disques et des données. C'est cette intégration qui permet les checksums, les snapshots, la réparation automatique et le scrub.

Un miroir protège contre la panne d'un disque. Ce n'est pas une sauvegarde : [Sauvegardes.md](Sauvegardes.md).

---

# Checksum

Chaque bloc possède un checksum. À la lecture, ZFS relit le bloc, recalcule le checksum, et le compare à celui enregistré. S'ils diffèrent, le bloc est corrompu.

Le checksum détecte une corruption silencieuse. Il ne répare pas à lui seul.

---

# Self-healing

Sur un VDEV miroir :

```
HDD1  Checksum ❌
HDD2  Checksum ✅
```

ZFS lit la copie saine, puis réécrit le bloc corrompu. La réparation est transparente.

---

# Scrub

Le scrub relit l'intégralité du pool : vérifier tous les checksums, détecter les corruptions silencieuses, réparer lorsqu'une copie saine existe.

C'est une maintenance préventive. Sur un homelab, il est généralement planifié une fois par mois.

---

# Organisation logique

```
Matériel
    ↓
Disque physique
    ↓
Pool ZFS
    ↓
Dataset
    ↓
Système de fichiers
    ↓
Applications
```

Exemple actuel :

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

---

# État actuel : `rpool`

Pool ZFS sur le NVMe. Première installation Proxmox : ext4 + LVM-Thin. Réinstallé sur ZFS le 2026-09-02, avant toute donnée critique ([Journal.md](Journal.md), sprint 8).

```
rpool
├── ROOT
│   └── pve-1                 → système Proxmox
├── data
│   └── subvol-100-disk-0     → disque du LXC 100 (cloudflare)
└── var-lib-vz                → ISO, templates, sauvegardes, imports
```

| Dataset | Rôle |
|---------|------|
| `rpool/ROOT/pve-1` | Système Proxmox |
| `rpool/data` | Disques des VM et LXC |
| `rpool/var-lib-vz` | Stockage local Proxmox (ISO, templates, sauvegardes) |

Les VM et LXC restent sur le SSD NVMe.

`rpool` est un VDEV single (un seul disque). Pas de miroir système aujourd'hui.

---

# Futur : `tank`

```
IronWolf 1
        │
IronWolf 2
        │
        ▼
Mirror VDEV
        │
        ▼
Pool ZFS : tank
        │
        ▼
Datasets
```
