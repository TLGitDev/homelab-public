# Stockage

> Cours ZFS et état du stockage du homelab.
>
> Choix : [ADR-002](ADR/ADR-002-ZFS.md). Vaultwarden sur `tank` : [ADR-008](ADR/ADR-008-Vaultwarden-tank.md). Inventaire disques : [Materiel.md](Materiel.md).
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

Exemple **actuel** (`tank`) :

```
tank
├── vmdata          ← zfspool Proxmox `tank-vmdata` (volumes bloc seulement)
│   └── vm-101-vaultwarden-data
├── backups         ← copies (ex. `/tank/backups/k3s-01/vaultwarden`)
└── …
```

Pas de dataset `tank/vmdata/vaultwarden` mélangé aux volumes Proxmox.

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

`tank/vmdata` existe. Volume Vaultwarden : `tank/vmdata/vm-101-vaultwarden-data` (depuis le 2026-10-14). L'ancien PVC `local-path` est conservé figé. Décision : [ADR-008](ADR/ADR-008-Vaultwarden-tank.md).

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
Proxmox
├── rpool   ← infrastructure
│   ├── Proxmox, LXC, disque système de k3s-01
│   └── local-path → ancien PVC Vaultwarden (figé, rollback)
│
└── tank    ← données (miroir IronWolf, ONLINE)
    └── vmdata     ← zfspool Proxmox `tank-vmdata`
        └── vm-101-vaultwarden-data   ← coffre en service
```

| Pool | Support | VDEV | Rôle aujourd'hui |
|------|---------|------|------------------|
| `rpool` | NVMe 2 To | single | Système, VM, LXC. Ancien PVC Vaultwarden encore présent, plus en service |
| `tank` | 2× IronWolf 8 To | mirror | Données. Volume Vaultwarden : `vm-101-vaultwarden-data` |

Le miroir de `tank` protège contre la panne d'un HDD. Ce n'est **pas** une sauvegarde.

## rpool

```
rpool
├── ROOT
│   └── pve-1                      → système Proxmox
├── data
│   ├── subvol-100-disk-0          → LXC 100 (cloudflare)
│   ├── vm-101-disk-0
│   ├── vm-101-disk-1              → disque système de k3s-01 (64 Go)
│   └── vm-101-state-Debian_13_propre
└── var-lib-vz                     → ISO, templates, sauvegardes, imports
```

## tank / `tank-vmdata`

`tank` est un miroir (`mirror-0` : `sda` / `sdb` côté Linux — les identifiants stables restent les numéros de série). État attendu : **ONLINE**.

Dataset dédié aux volumes de VM :

```
zfspool: tank-vmdata
        pool tank/vmdata
        content images
        mountpoint /tank/vmdata
        sparse 1
```

`tank/vmdata` est **réservé** aux volumes bloc gérés par Proxmox. Pas de dataset applicatif mélangé (`tank/vmdata/vaultwarden`).

| Élément | Rôle |
|---------|------|
| `rpool` | Infrastructure et disques **système** des VM/CT |
| `tank` | Données qui doivent survivre à une reconstruction de l'infra |
| `tank/vmdata` (`tank-vmdata`) | Volumes ZFS **bloc** pour les VM |
| `tank/backups` | Copies hors VM (ex. Vaultwarden). **Même pool** que les données : pas un backup USB |

## Chaîne applicative (Vaultwarden, en service)

Pour un service qui a besoin de stockage persistant local (SQLite) :

```
Pod
 ↓
PVC
 ↓
Local PV (statique)
 ↓
filesystem Linux (ext4, UUID dans fstab)
 ↓
disque de la VM (scsi1, Virtio SCSI)
 ↓
zvol `tank/vmdata/vm-101-vaultwarden-data`
```

**Pas** de NFS comme stockage primaire pour SQLite. **Pas** de CSI ZFS pour l'instant ([ADR-008](ADR/ADR-008-Vaultwarden-tank.md)).

```
Volume primaire (service)     →  tank
Snapshot ZFS                  →  rollback rapide (même pool) — timers zvol VW actifs
Backup indépendant            →  USB / offsite (manuel)
```

Snapshots : uniquement le zvol Vaultwarden, 24× horaire + 7× quotidien, crash-consistent. Timers `pve` activés le 21 oct. [Sauvegardes.md](Sauvegardes.md#snapshots-zfs).

Reconstruction visée : `rpool` / k3s-01 perdus, `tank` intact → nouvelle VM, réattacher le zvol existant, filesystem, Local PV, PVC, Vaultwarden. Le volume **ne** se recrée **pas** avec la VM. Procédure écrite, **pas exécutée** : [Vaultwarden.md](Vaultwarden.md#reprise-réelle--non-testée).

Un Local PV est lié au nœud `k3s-01`. Le cluster n'a qu'un nœud ; le stockage physique est hors du disque système de la VM.

Sauvegardes SQLite cohérentes : tar auto 03:00 + pull `pve`. Restore isolée OK. Reprise réelle zvol : écrite, non exécutée. Ne pas détruire l'ancien PVC maintenant. USB hors `tank` : manuel. Détail : [Vaultwarden.md](Vaultwarden.md#sauvegarde).

Service : [Vaultwarden.md](Vaultwarden.md). Décision : [ADR-008](ADR/ADR-008-Vaultwarden-tank.md).

Première installation Proxmox : ext4 + LVM-Thin. Réinstallé sur ZFS le 2026-09-02 ([Journal.md](Journal.md), sprint 8). Pool `tank` créé le 2026-09-07 (sprint 9). `tank/vmdata` déclaré dans Proxmox le 2026-10-06. Volume Vaultwarden le 2026-10-14.

---

# POC (6 octobre 2026)

Objectif : valider ZFS → Proxmox → VM → Linux → Local PV → PVC → Pod, **sans** toucher à Vaultwarden.

| Étape | Constat |
|-------|---------|
| Volume | `tank/vmdata/vm-9999-k8s-test`, `volsize=1G`, `volblocksize=16K` |
| Proxmox | `tank-vmdata:vm-9999-k8s-test`, attaché `scsi1` (Virtio SCSI) |
| Dans la VM | `/dev/sdb`, 1 GiB (nom Linux **du moment** ; peut changer) |
| Filesystem | ext4, montage temporaire `/var/lib/k3s-storage/k8s-test` |
| Kubernetes | PV statique `k8s-test-pv` (`Retain`, `local.path`, `nodeAffinity` hostname `k3s-01`, StorageClass `k8s-test-local`) |
| PVC | `k8s-test-pvc` 500 Mi, RWO → Bound ; capacité affichée : 1 Gi (celle du PV) |
| Pod | écriture `/data/test.txt` ; même contenu dans la VM au point de montage |

Chaîne validée de bout en bout (écriture et lecture).

## Nettoyage

Tout a été supprimé : Pod, PVC, PV, démontage, point de montage, disque détaché, zvol détruit.

Aucune ressource de test ne reste. Les noms `k8s-test-*` et le chemin `/var/lib/k3s-storage/k8s-test` n'existent plus. Le patron a servi à la migration Vaultwarden du 2026-10-14 ([Vaultwarden.md](Vaultwarden.md#migration-local-path--tank-2026-10-14)).
