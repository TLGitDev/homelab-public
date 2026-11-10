# ZFS — notions

Ce document explique les notions de ZFS utilisées dans le homelab. L'état réel des pools et les procédures sont dans [stockage-zfs.md](../exploitation/stockage-zfs.md). Le choix de ZFS est justifié dans l'[ADR-002](../decisions/ADR-002-ZFS.md).

## 1. De quoi est fait un pool

ZFS empile cinq niveaux. Chacun s'appuie sur celui du dessous.

```
Disque physique
    ↓
VDEV
    ↓
Pool
    ↓
Dataset (ou zvol)
    ↓
Fichiers
```

Les applications ne manipulent jamais directement les disques. Elles écrivent dans des datasets. Le pool est le niveau d'administration principal.

## 2. Le VDEV

Le VDEV (*virtual device*) est l'unité de base du stockage ZFS. C'est surtout **l'unité de protection** des données. Un VDEV peut prendre trois formes :

| Forme | Disques | Protection | Dans le homelab |
| --- | --- | --- | --- |
| Single | 1 | Aucune | `rpool` |
| Miroir (mirror) | 2 ou plus | Survit à la perte de tous les disques sauf un | `tank` |
| RAIDZ1 | 3 ou plus (souvent 4) | Survit à la perte d'un disque | — |

Un pool peut contenir plusieurs VDEV. Il répartit alors les écritures entre eux, mais il ne **duplique pas** les données d'un VDEV à l'autre. Chaque donnée n'est protégée qu'à l'intérieur de son propre VDEV. Conséquence : si un VDEV entier est perdu, tout le pool est perdu.

## 3. Le pool

Un pool est un espace de stockage logique, construit sur un ou plusieurs VDEV. Il additionne leur capacité. Il ne stocke pas directement des fichiers : il contient des datasets.

**Un pool se conçoit avant sa création.** On peut facilement ajouter un VDEV à un pool existant. En revanche, on ne peut pas transformer librement un VDEV après coup (passer de single à miroir, changer un RAIDZ…). Le choix se fait donc avant toute mise en production.

## 4. Le dataset et le zvol

Un **dataset** est un système de fichiers indépendant à l'intérieur d'un pool. Ce n'est pas un simple dossier : il a ses propres propriétés (compression, snapshots, quotas, point de montage, permissions), et il s'administre seul. Il n'a pas de taille fixée à l'avance : il puise dans l'espace libre du pool.

Un **zvol** est un volume en mode bloc, vu comme un disque. Proxmox s'en sert pour les disques des VM. On le formate ensuite avec le système de fichiers de son choix, par exemple ext4.

### Quand créer un dataset

On ne crée un dataset que pour un besoin réel. Un besoin réel, c'est l'un de ces quatre cas :

- une politique de snapshots différente ;
- un quota différent ;
- des propriétés ZFS différentes ;
- une frontière logique dans l'architecture.

Sans l'un de ces besoins, un simple répertoire suffit.

## 5. Le miroir

Un miroir garde deux copies identiques des données. Il apporte deux choses : le service continue si un disque tombe en panne, et ZFS dispose d'une seconde copie pour réparer les erreurs.

Le miroir ne vérifie pas lui-même l'intégrité : c'est ZFS qui le fait, grâce aux checksums. Et un miroir **n'est pas une sauvegarde** : une suppression ou un chiffrement par un rançongiciel touche les deux copies en même temps (voir [sauvegardes.md](../exploitation/sauvegardes.md)).

ZFS n'utilise pas de RAID matériel. Plusieurs VDEV en miroir ressemblent à un RAID10, mais ZFS garde une connaissance complète des disques et des données.

## 6. Les checksums et l'autoréparation

À chaque écriture, ZFS calcule un checksum. À chaque lecture, il le recalcule et compare les deux valeurs.

- Si elles diffèrent, ZFS a détecté une corruption.
- S'il existe une copie saine (miroir ou RAIDZ), ZFS la lit, la renvoie à l'application et répare la copie abîmée. C'est l'autoréparation (*self-healing*).
- Sans copie saine, ZFS détecte la corruption mais ne peut pas la réparer.

## 7. Le scrub

Un scrub relit toutes les données d'un pool et vérifie chaque checksum. Il détecte les corruptions silencieuses, celles qu'aucune lecture n'avait encore révélées, et les répare quand c'est possible. C'est une opération préventive. Sur un homelab, on la lance en général une fois par mois.

## 8. Les snapshots

Un snapshot fige l'état d'un dataset ou d'un zvol à un instant donné. Il est instantané et ne consomme d'espace qu'au fur et à mesure que les données changent. Il permet un retour arrière rapide (*rollback*). Mais il vit dans le même pool que les données : si le pool est perdu, ses snapshots le sont aussi.
